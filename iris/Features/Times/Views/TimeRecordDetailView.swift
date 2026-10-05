//
//  TimeRecordDetailView.swift
//  iris
//

import SwiftUI

/// One saved service: totals and each block real vs. planned, with corrections.
struct TimeRecordDetailView: View {
    @Bindable var viewModel: TimesViewModel
    let record: ServiceRecord

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: IrisSpacing.xl) {
                header
                metrics
                VStack(alignment: .leading, spacing: IrisSpacing.sm) {
                    IrisSectionHeader("BLOQUES")
                    ForEach(record.blocks) { block in
                        TimeBlockRow(viewModel: viewModel, record: record, block: block, scale: viewModel.barScale(for: record))
                    }
                }
                if viewModel.canManage {
                    deleteButton
                }
            }
        }
        .scrollIndicators(.hidden)
        .sheet(item: $viewModel.adjustment) { adjustment in
            DurationAdjustmentView(viewModel: adjustment)
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: IrisSpacing.sm) {
            Circle()
                .fill(viewModel.serviceColor(record.serviceTypeID).map { Color(hex: $0) } ?? IrisColor.textTertiary)
                .frame(width: 12, height: 12)
                .padding(.top, IrisSpacing.sm)
            VStack(alignment: .leading, spacing: IrisSpacing.xxs) {
                Text(viewModel.serviceName(record.serviceTypeID))
                    .font(IrisFont.title)
                    .tracking(IrisTracking.tight)
                    .foregroundStyle(IrisColor.textPrimary)
                Text(viewModel.longDate(record.date))
                    .font(IrisFont.callout)
                    .foregroundStyle(IrisColor.textSecondary)
            }
        }
    }

    private var metrics: some View {
        HStack(spacing: IrisSpacing.xl) {
            metric("Duración", value: IrisDurationFormat.clock(record.actualSeconds), tint: IrisColor.textPrimary)
            metric("Previsto", value: IrisDurationFormat.clock(record.plannedSeconds), tint: IrisColor.textSecondary)
            if record.overtimeSeconds > 0 {
                metric("Exceso", value: IrisDurationFormat.overtime(record.overtimeSeconds), tint: IrisColor.danger)
            } else {
                metric("Exceso", value: String(localized: "A tiempo"), tint: IrisColor.success)
            }
        }
    }

    private func metric(_ title: LocalizedStringKey, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(IrisFont.caption)
                .foregroundStyle(IrisColor.textTertiary)
            Text(value)
                .font(.system(.title3, design: .rounded, weight: .semibold).monospacedDigit())
                .foregroundStyle(tint)
        }
    }

    private var deleteButton: some View {
        Button {
            viewModel.requestDeleteSelected()
        } label: {
            Label("Eliminar registro", systemImage: "trash")
                .font(IrisFont.calloutEmphasized)
                .foregroundStyle(IrisColor.danger)
        }
        .buttonStyle(.irisPressable)
        .confirmationDialog("¿Eliminar este registro?", isPresented: $viewModel.isConfirmingDeletion, titleVisibility: .visible) {
            Button("Eliminar", role: .destructive) {
                Task { await viewModel.deleteSelected() }
            }
        } message: {
            Text("Esta acción no se puede deshacer.")
        }
    }
}

/// Name and leader, bar real vs. planned, real time and overtime, with a menu to correct it.
private struct TimeBlockRow: View {
    let viewModel: TimesViewModel
    let record: ServiceRecord
    let block: BlockRecord
    let scale: TimeInterval

    private var isSkipped: Bool { block.status == .skipped }

    var body: some View {
        HStack(spacing: IrisSpacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: IrisSpacing.xs) {
                    Text(block.name)
                        .font(IrisFont.calloutEmphasized)
                        .foregroundStyle(isSkipped ? IrisColor.textTertiary : IrisColor.textPrimary)
                        .lineLimit(1)
                    if block.status == .adjusted {
                        IrisChip("Ajustado", tint: IrisColor.textSecondary)
                    }
                }
                Text(viewModel.leaderName(of: block))
                    .font(IrisFont.caption)
                    .foregroundStyle(IrisColor.textTertiary)
                    .lineLimit(1)
            }
            .frame(width: 200, alignment: .leading)

            if isSkipped {
                Spacer()
                Text("Omitido")
                    .font(IrisFont.caption)
                    .foregroundStyle(IrisColor.textTertiary)
            } else {
                IrisTimeBar(planned: block.plannedSeconds, actual: block.actualSeconds, scale: scale)
                times
                if viewModel.canManage {
                    menu
                }
            }
        }
        .padding(.vertical, IrisSpacing.xs)
    }

    private var times: some View {
        VStack(alignment: .trailing, spacing: 1) {
            Text(IrisDurationFormat.clock(block.actualSeconds))
                .font(.system(.callout, design: .monospaced, weight: .semibold))
                .foregroundStyle(IrisColor.textPrimary)
            Text(TimesViewModel.overtimeText(block.overtimeSeconds))
                .font(.system(.caption, design: .monospaced, weight: .semibold))
                .foregroundStyle(block.isOver ? IrisColor.danger : IrisColor.success)
        }
        .frame(width: 80, alignment: .trailing)
    }

    private var menu: some View {
        Menu {
            Button("Ajustar duración…", systemImage: "timer") {
                viewModel.beginAdjustment(of: block, in: record)
            }
            Menu("Cambiar responsable", systemImage: "person") {
                Picker(selection: Binding(
                    get: { block.personID },
                    set: { personID in Task { await viewModel.changeLeader(of: block.id, in: record.id, to: personID) } }
                )) {
                    Text("Sin responsable").tag(Person.ID?.none)
                    ForEach(viewModel.filterPeople) { person in
                        Text(person.name).tag(Optional(person.id))
                    }
                } label: {
                    Text("Responsable")
                }
                .pickerStyle(.inline)
            }
        } label: {
            Image(systemName: "ellipsis")
        }
        .menuStyle(.button)
        .buttonStyle(.irisIcon)
        .accessibilityLabel(Text("Opciones del bloque"))
    }
}

/// Minutes and seconds wheels; saving marks the block "Ajustado".
private struct DurationAdjustmentView: View {
    @Bindable var viewModel: DurationAdjustmentViewModel

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: IrisSpacing.lg) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Ajustar duración")
                        .font(IrisFont.title)
                        .foregroundStyle(IrisColor.textPrimary)
                    Text("\(viewModel.blockName) · previsto \(IrisDurationFormat.clock(viewModel.plannedSeconds))")
                        .font(IrisFont.callout)
                        .foregroundStyle(IrisColor.textSecondary)
                }
                Spacer()
                Button("Cancelar") { dismiss() }
                    .buttonStyle(.irisPill)
            }

            HStack(spacing: IrisSpacing.md) {
                Picker("Minutos", selection: $viewModel.minutes) {
                    ForEach(0..<301, id: \.self) { minute in
                        Text("\(minute) min").tag(minute)
                    }
                }
                Picker("Segundos", selection: $viewModel.seconds) {
                    ForEach(0..<60, id: \.self) { second in
                        Text("\(second) s").tag(second)
                    }
                }
            }
            .pickerStyle(.wheel)
            .colorScheme(.dark)

            Button("Guardar") { viewModel.save() }
                .buttonStyle(.irisPrimary)
        }
        .padding(IrisSpacing.xl)
        .presentationSizing(.form)
        .presentationBackground(IrisColor.canvasElevated)
    }
}
