//
//  ServiceTypeEditorView.swift
//  iris
//

import SwiftUI

/// Sheet to create or edit a service type: name, color, schedule and optional timed blocks.
struct ServiceTypeEditorView: View {
    @Bindable var viewModel: ServiceTypeEditorViewModel

    @Environment(\.dismiss) private var dismiss
    @FocusState private var focus: Field?

    private enum Field: Hashable { case name }

    /// Spoken names of `ServiceType.palette`, in the same order.
    private static let colorNames: [LocalizedStringKey] = ["Ámbar", "Coral", "Rosa", "Violeta", "Índigo", "Verde"]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(IrisSpacing.xl)

            ScrollView {
                VStack(alignment: .leading, spacing: IrisSpacing.xl) {
                    if let errorMessage = viewModel.errorMessage {
                        IrisBanner(style: .error, message: errorMessage)
                    }
                    Group {
                        nameSection
                        colorSection
                        scheduleSection
                        if viewModel.showsTimeControl {
                            timeControlSection
                        }
                    }
                    .disabled(viewModel.isReadOnly)
                    if !viewModel.isNew, !viewModel.isReadOnly {
                        deleteSection
                    }
                }
                .padding([.horizontal, .bottom], IrisSpacing.xl)
            }
            .scrollIndicators(.hidden)
        }
        .presentationSizing(.page)
        .presentationBackground(IrisColor.canvasElevated)
        .interactiveDismissDisabled()
        .task { await viewModel.load() }
        .alert("Agregar persona", isPresented: $viewModel.isAddingPerson) {
            TextField("Nombre y apellido", text: $viewModel.newPersonName)
                .textInputAutocapitalization(.words)
            Button("Cancelar", role: .cancel) {}
            Button("Agregar") {
                Task { await viewModel.confirmAddPerson() }
            }
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: IrisSpacing.md) {
            Group {
                if viewModel.isNew {
                    Text("Nuevo servicio")
                } else if viewModel.isReadOnly {
                    Text(viewModel.name)
                } else {
                    Text("Editar servicio")
                }
            }
            .font(IrisFont.title)
            .foregroundStyle(IrisColor.textPrimary)

            Spacer()

            if viewModel.isReadOnly {
                Button("Cerrar") { dismiss() }
                    .buttonStyle(.irisPill)
            } else {
                Button("Cancelar") { dismiss() }
                    .buttonStyle(.irisPill)

                Button("Guardar") {
                    Task { await viewModel.save() }
                }
                .buttonStyle(.irisPrimary(isLoading: viewModel.isSaving))
                .frame(width: 180)
                .disabled(!viewModel.canSave)
            }
        }
    }

    // MARK: Sections

    private var nameSection: some View {
        IrisTextField(
            "Nombre",
            icon: "calendar",
            text: $viewModel.name,
            prompt: "Ej. Culto general",
            kind: .text,
            error: viewModel.nameError,
            focus: $focus,
            field: .name
        )
    }

    private var colorSection: some View {
        VStack(alignment: .leading, spacing: IrisSpacing.sm) {
            IrisSectionHeader("COLOR")
            HStack(spacing: IrisSpacing.sm) {
                ForEach(Array(ServiceType.palette.enumerated()), id: \.element) { index, hex in
                    ColorSwatch(hex: hex, isSelected: viewModel.color == hex) {
                        withAnimation(IrisMotion.snappy) { viewModel.color = hex }
                    }
                    .accessibilityLabel(Text(Self.colorNames[index]))
                }
            }
        }
    }

    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: IrisSpacing.md) {
            IrisSectionHeader("HORARIO")

            Toggle(isOn: $viewModel.hasSchedule.animation(IrisMotion.smooth)) {
                Text("Tiene horario fijo")
                    .font(IrisFont.calloutEmphasized)
                    .foregroundStyle(IrisColor.textPrimary)
            }
            .tint(IrisColor.coral)

            if viewModel.hasSchedule {
                HStack(spacing: IrisSpacing.xs) {
                    ForEach(1...7, id: \.self) { weekday in
                        WeekdayPill(weekday: weekday, isSelected: viewModel.weekday == weekday) {
                            withAnimation(IrisMotion.snappy) { viewModel.weekday = weekday }
                        }
                    }
                }

                DatePicker(selection: $viewModel.scheduleTime, displayedComponents: .hourAndMinute) {
                    Text("Hora")
                        .font(IrisFont.callout)
                        .foregroundStyle(IrisColor.textSecondary)
                }
                .tint(IrisColor.coral)
                .colorScheme(.dark)
                .fixedSize()
            }
        }
    }

    private var timeControlSection: some View {
        VStack(alignment: .leading, spacing: IrisSpacing.md) {
            IrisSectionHeader("CONTROL DE TIEMPO")

            Toggle(isOn: Binding(
                get: { viewModel.tracksTime },
                set: { isOn in withAnimation(IrisMotion.smooth) { viewModel.setTracksTime(isOn) } }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Controlar el tiempo de este servicio")
                        .font(IrisFont.calloutEmphasized)
                        .foregroundStyle(IrisColor.textPrimary)
                    Text("Divide el servicio en bloques con un tiempo previsto y un responsable.")
                        .font(IrisFont.callout)
                        .foregroundStyle(IrisColor.textSecondary)
                }
            }
            .tint(IrisColor.coral)
            .confirmationDialog("¿Quitar los bloques?", isPresented: $viewModel.isConfirmingBlockRemoval, titleVisibility: .visible) {
                Button("Quitar bloques", role: .destructive) {
                    withAnimation(IrisMotion.smooth) { viewModel.confirmBlockRemoval() }
                }
            } message: {
                Text("El servicio quedará solo para proyectar.")
            }

            if viewModel.tracksTime {
                blockEditor
            }
        }
    }

    private var blockEditor: some View {
        VStack(alignment: .leading, spacing: IrisSpacing.md) {
            LazyVStack(spacing: IrisSpacing.xs) {
                ForEach(viewModel.blocks) { block in
                    BlockEditorRow(viewModel: viewModel, block: block)
                }
                .reorderable()
            }
            .reorderContainer(for: BlockTemplate.self) { difference in
                var target: BlockTemplate.ID?
                if case let .before(id) = difference.destination.position { target = id }
                withAnimation(IrisMotion.smooth) {
                    viewModel.moveBlocks(Array(difference.sources), before: target)
                }
            }

            if let blocksError = viewModel.blocksError {
                Label(blocksError, systemImage: "exclamationmark.circle.fill")
                    .font(IrisFont.caption)
                    .foregroundStyle(IrisColor.danger)
            }

            Button {
                withAnimation(IrisMotion.smooth) { viewModel.addBlock() }
            } label: {
                Label("Agregar bloque", systemImage: "plus")
            }
            .buttonStyle(.irisPill)

            if !viewModel.blocks.isEmpty {
                VStack(alignment: .leading, spacing: IrisSpacing.xs) {
                    BlockTimeline(blocks: viewModel.blocks)
                    Text("Total previsto: \(IrisDurationFormat.summary(viewModel.plannedSeconds))")
                        .font(IrisFont.callout)
                        .foregroundStyle(IrisColor.textSecondary)
                }
                .padding(.top, IrisSpacing.xs)
            }
        }
    }

    private var deleteSection: some View {
        Button {
            viewModel.requestDelete()
        } label: {
            Label("Eliminar servicio", systemImage: "trash")
                .font(IrisFont.calloutEmphasized)
                .foregroundStyle(IrisColor.danger)
        }
        .buttonStyle(.irisPressable)
        .padding(.top, IrisSpacing.md)
        .confirmationDialog(
            Text("¿Eliminar \(viewModel.name)?"),
            isPresented: $viewModel.isConfirmingDeletion,
            titleVisibility: .visible
        ) {
            Button("Eliminar", role: .destructive) {
                Task { await viewModel.delete() }
            }
        } message: {
            Text("Sus tiempos guardados se conservan.")
        }
    }
}

// MARK: - Pieces

/// One color choice; the selected one gets a white ring.
private struct ColorSwatch: View {
    let hex: UInt32
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(Color(hex: hex))
                .frame(width: 36, height: 36)
                .padding(3)
                .overlay {
                    Circle().strokeBorder(isSelected ? IrisColor.textPrimary : .clear, lineWidth: 2)
                }
        }
        .buttonStyle(.irisPressable)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// "Dom", "Lun"… The selected day is a warm-white capsule.
private struct WeekdayPill: View {
    let weekday: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(IrisScheduleFormat.shortWeekday(weekday))
                .font(IrisFont.calloutEmphasized)
                .foregroundStyle(isSelected ? IrisColor.textInverse : IrisColor.textSecondary)
                .padding(.horizontal, IrisSpacing.md - 2)
                .frame(height: 38)
                .background(isSelected ? AnyShapeStyle(IrisColor.textPrimary) : AnyShapeStyle(IrisColor.surface), in: Capsule())
                .overlay(Capsule().strokeBorder(isSelected ? .clear : IrisColor.stroke))
                .contentShape(Capsule())
        }
        .buttonStyle(.irisPressable)
        .accessibilityLabel(Text(IrisScheduleFormat.weekday(weekday)))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Drag handle, name, minutes, leader and delete.
private struct BlockEditorRow: View {
    let viewModel: ServiceTypeEditorViewModel
    let block: BlockTemplate

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: IrisRadius.md, style: .continuous)
    }

    private var isNameMissing: Bool { viewModel.isBlockNameMissing(block.id) }

    var body: some View {
        HStack(spacing: IrisSpacing.sm) {
            Image(systemName: "line.3.horizontal")
                .font(.system(.callout, weight: .semibold))
                .foregroundStyle(IrisColor.textTertiary)
                .accessibilityHidden(true)

            TextField(
                "Nombre del bloque",
                text: Binding(get: { viewModel.blockName(block.id) }, set: { viewModel.renameBlock(block.id, to: $0) }),
                prompt: Text("Nombre del bloque").foregroundStyle(IrisColor.textTertiary)
            )
            .font(IrisFont.body)
            .foregroundStyle(IrisColor.textPrimary)
            .tint(IrisColor.coral)

            Stepper(
                value: Binding(get: { block.plannedMinutes }, set: { viewModel.setMinutes($0, of: block.id) }),
                in: ServiceTypeEditorViewModel.minuteRange
            ) {
                Text("\(block.plannedMinutes) min")
                    .font(.system(.callout, design: .monospaced, weight: .medium))
                    .foregroundStyle(IrisColor.textSecondary)
            }
            .fixedSize()
            .accessibilityLabel(Text("Minutos previstos"))

            leaderMenu

            Button {
                withAnimation(IrisMotion.smooth) { viewModel.removeBlock(block.id) }
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.irisIcon)
            .accessibilityLabel(Text("Eliminar bloque"))
        }
        .padding(.leading, IrisSpacing.md)
        .padding(.trailing, IrisSpacing.xs)
        .padding(.vertical, IrisSpacing.xs)
        .background(IrisColor.surface, in: shape)
        .overlay {
            shape.strokeBorder(isNameMissing ? IrisColor.danger.opacity(0.8) : IrisColor.stroke, lineWidth: isNameMissing ? 1.5 : 1)
        }
    }

    private var leaderMenu: some View {
        Menu {
            Picker(selection: Binding(get: { block.defaultPersonID }, set: { viewModel.setPerson($0, for: block.id) })) {
                Text("Sin responsable").tag(Person.ID?.none)
                ForEach(viewModel.people) { person in
                    Text(person.name).tag(Optional(person.id))
                }
            } label: {
                Text("Responsable")
            }
            .pickerStyle(.inline)

            Divider()

            Button("Agregar persona…", systemImage: "person.badge.plus") {
                viewModel.beginAddPerson(for: block.id)
            }
        } label: {
            HStack(spacing: IrisSpacing.xxs + 2) {
                Image(systemName: "person.fill")
                    .font(.system(.caption, weight: .semibold))
                leaderName
                    .lineLimit(1)
            }
            .font(IrisFont.label)
            .foregroundStyle(IrisColor.textSecondary)
            .padding(.horizontal, IrisSpacing.sm)
            .frame(maxWidth: 200)
            .frame(height: 32)
            .background(IrisColor.surfaceRaised, in: Capsule())
        }
        .fixedSize()
        .accessibilityLabel(Text("Responsable"))
    }

    @ViewBuilder
    private var leaderName: some View {
        if let name = viewModel.personName(block.defaultPersonID) {
            Text(name)
        } else {
            Text("Sin responsable")
        }
    }
}

extension ServiceTypeEditorViewModel {
    /// "Nuevo servicio", empty.
    static var newPreview: ServiceTypeEditorViewModel {
        makePreview(editing: nil)
    }

    /// Culto general with its four blocks.
    static var blocksPreview: ServiceTypeEditorViewModel {
        makePreview(editing: MockChurchData.serviceTypes.first)
    }

    private static func makePreview(editing type: ServiceType?) -> ServiceTypeEditorViewModel {
        let store = InMemoryChurchStore()
        let viewModel = ServiceTypeEditorViewModel(
            editing: type,
            otherTypes: store.serviceTypes,
            showsTimeControl: true,
            serviceTypes: MockServiceTypeRepository(store: store, latency: .zero),
            people: MockPeopleRepository(store: store, latency: .zero),
            onFinish: { _ in }
        )
        viewModel.apply(people: store.people)
        return viewModel
    }
}

#Preview("Nuevo servicio") {
    ServiceTypeEditorView(viewModel: .newPreview)
        .frame(width: 900, height: 820)
        .background(IrisColor.canvasElevated)
        .preferredColorScheme(.dark)
        .environment(\.locale, Locale(identifier: "es"))
}

#Preview("Con bloques") {
    ServiceTypeEditorView(viewModel: .blocksPreview)
        .frame(width: 900, height: 1_000)
        .background(IrisColor.canvasElevated)
        .preferredColorScheme(.dark)
        .environment(\.locale, Locale(identifier: "es"))
}
