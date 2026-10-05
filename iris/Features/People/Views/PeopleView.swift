//
//  PeopleView.swift
//  iris
//

import SwiftUI

/// People who lead the blocks: add at the top, swipe or long-press a row to rename or delete.
struct PeopleView: View {
    @State private var viewModel: PeopleViewModel
    @FocusState private var focus: Field?

    private enum Field: Hashable { case newPerson }

    init(viewModel: PeopleViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
                    .tint(IrisColor.textSecondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    IrisSurface {
                        VStack(alignment: .leading, spacing: IrisSpacing.lg) {
                            header
                            addRow
                            if let errorMessage = viewModel.errorMessage {
                                IrisBanner(style: .error, message: errorMessage)
                            }
                            peopleList
                        }
                    }
                    .frame(maxWidth: IrisSize.settingsColumnWidth)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, IrisSpacing.xl)
                    .padding(.top, IrisSpacing.md)
                    .padding(.bottom, IrisSpacing.xxl)
                }
                .scrollIndicators(.hidden)
                .swipeActionsContainer()
            }
        }
        .task { await viewModel.load() }
        .alert("Renombrar", isPresented: $viewModel.isRenaming, presenting: viewModel.renameTarget) { person in
            TextField("Nombre y apellido", text: $viewModel.renameDraft)
                .textInputAutocapitalization(.words)
            Button("Cancelar", role: .cancel) {}
            Button("Guardar") {
                Task { await viewModel.confirmRename(of: person) }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: IrisSpacing.xs) {
            Text("Personas")
                .font(IrisFont.headline)
                .tracking(IrisTracking.tight)
                .foregroundStyle(IrisColor.textPrimary)
            Text("Quienes dirigen los bloques de tus servicios.")
                .font(IrisFont.callout)
                .foregroundStyle(IrisColor.textSecondary)
        }
    }

    private var addRow: some View {
        HStack(alignment: .irisFieldCenter, spacing: IrisSpacing.sm) {
            IrisTextField(
                "Nueva persona",
                icon: "person.badge.plus",
                text: $viewModel.newName,
                prompt: "Nombre y apellido",
                kind: .name,
                error: viewModel.newNameError,
                focus: $focus,
                field: .newPerson
            )
            .submitLabel(.done)
            .onSubmit { add() }

            Button("Agregar") { add() }
                .buttonStyle(.irisPill)
                .disabled(viewModel.isAdding)
        }
    }

    @ViewBuilder
    private var peopleList: some View {
        if viewModel.people.isEmpty {
            ContentUnavailableView {
                Label("Aún no hay personas", systemImage: "person.2")
            } description: {
                Text("Agrega a quienes dirigen la bienvenida, las alabanzas o la prédica.")
            }
            .foregroundStyle(IrisColor.textSecondary)
        } else {
            LazyVStack(spacing: 0) {
                ForEach(Array(viewModel.people.enumerated()), id: \.element.id) { index, person in
                    if index > 0 {
                        Divider()
                            .overlay(IrisColor.stroke)
                    }
                    row(for: person, at: index)
                }
            }
        }
    }

    private func row(for person: Person, at index: Int) -> some View {
        PersonRow(
            person: person,
            tint: IrisGradient.spectrum[index % IrisGradient.spectrum.count],
            blockCount: viewModel.blockCountText(for: person)
        )
            .swipeActions(edge: .trailing) {
                Button(role: .destructive) {
                    viewModel.requestDelete(person)
                } label: {
                    Label("Eliminar", systemImage: "trash")
                }
            }
            .contextMenu {
                Button("Renombrar", systemImage: "pencil") {
                    viewModel.beginRename(person)
                }
                Divider()
                Button("Eliminar", systemImage: "trash", role: .destructive) {
                    viewModel.requestDelete(person)
                }
            }
            .confirmationDialog(
                Text("¿Eliminar a \(person.name)?"),
                isPresented: Binding(
                    get: { viewModel.pendingDeletion?.id == person.id },
                    set: { if !$0 { viewModel.isConfirmingDeletion = false } }
                ),
                titleVisibility: .visible
            ) {
                Button("Eliminar", role: .destructive) {
                    Task { await viewModel.confirmDelete(of: person) }
                }
            } message: {
                Text("Sus tiempos guardados se conservan.")
            }
    }

    private func add() {
        Task {
            await viewModel.add()
            focus = .newPerson
        }
    }
}

/// Avatar with initials, name and how many blocks the person has led.
private struct PersonRow: View {
    let person: Person
    let tint: Color
    let blockCount: String

    var body: some View {
        HStack(spacing: IrisSpacing.sm) {
            Text(person.initials)
                .font(.system(.caption, weight: .bold))
                .foregroundStyle(IrisColor.textInverse)
                .frame(width: 40, height: 40)
                .background(tint, in: Circle())

            Text(person.name)
                .font(IrisFont.bodyEmphasized)
                .foregroundStyle(IrisColor.textPrimary)
                .lineLimit(1)

            Spacer(minLength: IrisSpacing.md)

            Text(blockCount)
                .font(IrisFont.caption)
                .monospacedDigit()
                .foregroundStyle(IrisColor.textTertiary)
        }
        .padding(.vertical, IrisSpacing.sm)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

extension PeopleViewModel {
    /// Already-loaded view model for previews.
    static var preview: PeopleViewModel { makePreview(store: InMemoryChurchStore()) }

    /// No people yet.
    static var emptyPreview: PeopleViewModel { makePreview(store: InMemoryChurchStore(seed: .empty)) }

    private static func makePreview(store: InMemoryChurchStore) -> PeopleViewModel {
        let viewModel = PeopleViewModel(
            people: MockPeopleRepository(store: store, latency: .zero),
            timeRecords: MockTimeRecordRepository(store: store, latency: .zero)
        )
        viewModel.apply(people: store.people, records: store.records)
        return viewModel
    }
}

#Preview("Landscape", traits: .landscapeLeft) {
    PeopleView(viewModel: .preview)
        .background { IrisBackground(isAnimated: false) }
        .preferredColorScheme(.dark)
        .environment(\.locale, Locale(identifier: "es"))
}

#Preview("Vacío", traits: .landscapeLeft) {
    PeopleView(viewModel: .emptyPreview)
        .background { IrisBackground(isAnimated: false) }
        .preferredColorScheme(.dark)
        .environment(\.locale, Locale(identifier: "es"))
}
