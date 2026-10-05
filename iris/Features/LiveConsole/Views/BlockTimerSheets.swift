//
//  BlockTimerSheets.swift
//  iris
//

import SwiftUI

// MARK: - Responsible picker

/// "¿Quién dirige {bloque}?" before a block starts. The suggested person comes first and preselected.
struct ResponsiblePickerView: View {
    @Bindable var viewModel: ResponsiblePickerViewModel

    @Environment(\.dismiss) private var dismiss
    @FocusState private var focus: Field?

    private enum Field: Hashable { case newPerson }

    var body: some View {
        VStack(alignment: .leading, spacing: IrisSpacing.lg) {
            HStack(alignment: .top) {
                Text("¿Quién dirige \(viewModel.blockName)?")
                    .font(IrisFont.title)
                    .foregroundStyle(IrisColor.textPrimary)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.irisIcon)
                .accessibilityLabel(Text("Cerrar"))
            }

            ScrollView {
                LazyVStack(spacing: IrisSpacing.xs) {
                    ForEach(Array(viewModel.people.enumerated()), id: \.element.id) { index, person in
                        PersonChoiceRow(
                            person: person,
                            tint: IrisGradient.spectrum[index % IrisGradient.spectrum.count],
                            isSuggested: viewModel.isSuggested(person),
                            isSelected: viewModel.selectedPersonID == person.id
                        ) {
                            withAnimation(IrisMotion.snappy) { viewModel.select(person.id) }
                        }
                    }
                }
                .padding(.vertical, IrisSpacing.xxs)
            }
            .scrollIndicators(.hidden)

            HStack(alignment: .irisFieldCenter, spacing: IrisSpacing.sm) {
                IrisTextField(
                    "Agregar persona",
                    icon: "person.badge.plus",
                    text: $viewModel.newName,
                    prompt: "Nombre y apellido",
                    kind: .name,
                    focus: $focus,
                    field: .newPerson
                )
                .submitLabel(.done)
                .onSubmit { addPerson() }

                Button("Agregar") { addPerson() }
                    .buttonStyle(.irisPill)
                    .disabled(viewModel.isAdding)
            }

            HStack(spacing: IrisSpacing.md) {
                Button("Sin responsable") { viewModel.confirmWithoutLeader() }
                    .buttonStyle(.irisLink)
                Spacer()
                Button {
                    viewModel.confirm()
                } label: {
                    Text("Comenzar \(viewModel.blockName)")
                        .lineLimit(1)
                }
                .buttonStyle(.irisPrimary)
                .frame(width: 300)
            }
        }
        .padding(IrisSpacing.xl)
        .presentationSizing(.form)
        .presentationBackground(IrisColor.canvasElevated)
    }

    private func addPerson() {
        Task { await viewModel.addPerson() }
    }
}

private struct PersonChoiceRow: View {
    let person: Person
    let tint: Color
    let isSuggested: Bool
    let isSelected: Bool
    let action: () -> Void

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: IrisRadius.md, style: .continuous)
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: IrisSpacing.sm) {
                Text(person.initials)
                    .font(.system(.caption, weight: .bold))
                    .foregroundStyle(IrisColor.textInverse)
                    .frame(width: 36, height: 36)
                    .background(tint, in: Circle())
                Text(person.name)
                    .font(IrisFont.bodyEmphasized)
                    .foregroundStyle(IrisColor.textPrimary)
                if isSuggested {
                    IrisChip("Sugerido", tint: IrisColor.coral)
                }
                Spacer(minLength: IrisSpacing.sm)
                IrisCheckmark(isOn: isSelected)
            }
            .padding(.horizontal, IrisSpacing.md)
            .padding(.vertical, IrisSpacing.sm - 2)
            .background(isSelected ? IrisColor.surfaceRaised : IrisColor.surface, in: shape)
            .overlay(shape.strokeBorder(IrisColor.stroke))
            .contentShape(shape)
        }
        .buttonStyle(.irisPressable)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Add block

/// A block added during the service, right after the current one.
struct AddBlockView: View {
    @Bindable var viewModel: AddBlockViewModel

    @Environment(\.dismiss) private var dismiss
    @FocusState private var focus: Field?

    private enum Field: Hashable { case name }

    var body: some View {
        VStack(alignment: .leading, spacing: IrisSpacing.lg) {
            HStack {
                Text("Agregar bloque")
                    .font(IrisFont.title)
                    .foregroundStyle(IrisColor.textPrimary)
                Spacer()
                Button("Cancelar") { dismiss() }
                    .buttonStyle(.irisPill)
            }

            IrisTextField(
                "Nombre",
                icon: "timer",
                text: $viewModel.name,
                prompt: "Ej. Santa Cena",
                kind: .text,
                focus: $focus,
                field: .name
            )

            HStack {
                Text("Minutos previstos")
                    .font(IrisFont.callout)
                    .foregroundStyle(IrisColor.textSecondary)
                Spacer()
                Stepper(value: $viewModel.minutes, in: 1...240) {
                    Text("\(viewModel.minutes) min")
                        .font(.system(.callout, design: .monospaced, weight: .medium))
                        .foregroundStyle(IrisColor.textPrimary)
                }
                .fixedSize()
            }

            HStack {
                Text("Responsable")
                    .font(IrisFont.callout)
                    .foregroundStyle(IrisColor.textSecondary)
                Spacer()
                Picker("Responsable", selection: $viewModel.personID) {
                    Text("Sin responsable").tag(Person.ID?.none)
                    ForEach(viewModel.people) { person in
                        Text(person.name).tag(Optional(person.id))
                    }
                }
                .pickerStyle(.menu)
                .tint(IrisColor.textPrimary)
            }

            Spacer(minLength: 0)

            Button("Agregar") { viewModel.add() }
                .buttonStyle(.irisPrimary)
                .disabled(!viewModel.canAdd)
        }
        .padding(IrisSpacing.xl)
        .presentationSizing(.form)
        .presentationBackground(IrisColor.canvasElevated)
        .onAppear { focus = .name }
    }
}

// MARK: - Pending blocks

/// Reorder, rename, retime, reassign, skip or restore the blocks not reached yet. Today only.
struct PendingBlocksEditorView: View {
    @Bindable var viewModel: LiveConsoleViewModel

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: IrisSpacing.lg) {
            HStack {
                Text("Bloques pendientes")
                    .font(IrisFont.title)
                    .foregroundStyle(IrisColor.textPrimary)
                Spacer()
                Button("Listo") { dismiss() }
                    .buttonStyle(.irisPill)
            }

            if viewModel.pendingBlocks.isEmpty {
                ContentUnavailableView("No quedan bloques pendientes", systemImage: "checkmark.circle")
                    .foregroundStyle(IrisColor.textSecondary)
            } else {
                ScrollView {
                    LazyVStack(spacing: IrisSpacing.xs) {
                        ForEach(viewModel.pendingBlocks) { block in
                            PendingBlockRow(viewModel: viewModel, block: block)
                        }
                        .reorderable()
                    }
                    .reorderContainer(for: BlockTimer.Block.self) { difference in
                        var target: BlockTimer.Block.ID?
                        if case let .before(id) = difference.destination.position { target = id }
                        withAnimation(IrisMotion.smooth) {
                            viewModel.movePendingBlocks(Array(difference.sources), before: target)
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }
        }
        .padding(IrisSpacing.xl)
        .presentationSizing(.form)
        .presentationBackground(IrisColor.canvasElevated)
    }
}

private struct PendingBlockRow: View {
    let viewModel: LiveConsoleViewModel
    let block: BlockTimer.Block

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: IrisRadius.md, style: .continuous)
    }

    var body: some View {
        HStack(spacing: IrisSpacing.sm) {
            Image(systemName: "line.3.horizontal")
                .font(.system(.callout, weight: .semibold))
                .foregroundStyle(IrisColor.textTertiary)
                .accessibilityHidden(true)

            TextField(
                "Nombre del bloque",
                text: Binding(get: { block.name }, set: { viewModel.renamePendingBlock(block.id, to: $0) }),
                prompt: Text("Nombre del bloque").foregroundStyle(IrisColor.textTertiary)
            )
            .font(IrisFont.body)
            .strikethrough(block.isSkipped)
            .foregroundStyle(block.isSkipped ? IrisColor.textTertiary : IrisColor.textPrimary)
            .tint(IrisColor.coral)
            .disabled(block.isSkipped)

            Stepper(
                value: Binding(get: { block.plannedMinutes }, set: { viewModel.setPendingMinutes($0, of: block.id) }),
                in: 1...240
            ) {
                Text("\(block.plannedMinutes) min")
                    .font(.system(.callout, design: .monospaced, weight: .medium))
                    .foregroundStyle(IrisColor.textSecondary)
            }
            .fixedSize()
            .disabled(block.isSkipped)
            .accessibilityLabel(Text("Minutos previstos"))

            leaderMenu

            Button {
                withAnimation(IrisMotion.smooth) { viewModel.toggleSkip(block.id) }
            } label: {
                if block.isSkipped {
                    Text("Restaurar")
                } else {
                    Text("Omitir")
                }
            }
            .buttonStyle(.irisPill)
        }
        .padding(.horizontal, IrisSpacing.md)
        .padding(.vertical, IrisSpacing.xs)
        .background(IrisColor.surface, in: shape)
        .overlay(shape.strokeBorder(IrisColor.stroke))
    }

    private var leaderMenu: some View {
        Menu {
            Picker(selection: Binding(get: { block.personID }, set: { viewModel.setPendingLeader($0, of: block.id) })) {
                Text("Sin responsable").tag(Person.ID?.none)
                ForEach(viewModel.people) { person in
                    Text(person.name).tag(Optional(person.id))
                }
            } label: {
                Text("Responsable")
            }
            .pickerStyle(.inline)
        } label: {
            Image(systemName: block.personID == nil ? "person" : "person.fill")
                .font(.system(.callout, weight: .semibold))
                .foregroundStyle(IrisColor.textSecondary)
                .frame(width: 32, height: 32)
                .background(IrisColor.surfaceRaised, in: Circle())
        }
        .disabled(block.isSkipped)
        .accessibilityLabel(Text(viewModel.personName(block.personID) ?? String(localized: "Sin responsable")))
    }
}
