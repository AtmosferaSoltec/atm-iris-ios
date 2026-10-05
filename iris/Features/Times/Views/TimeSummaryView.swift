//
//  TimeSummaryView.swift
//  iris
//

import SwiftUI

/// Filters, KPIs, and tables by person and by block. Neutral wording: it is meant to talk with people, not rank them.
struct TimeSummaryView: View {
    @Bindable var viewModel: TimesViewModel

    var body: some View {
        let statistics = viewModel.statistics

        ScrollView {
            VStack(alignment: .leading, spacing: IrisSpacing.xl) {
                filters
                if statistics.serviceCount == 0 {
                    ContentUnavailableView("No hay tiempos con estos filtros", systemImage: "line.3.horizontal.decrease.circle")
                        .foregroundStyle(IrisColor.textSecondary)
                        .padding(.top, IrisSpacing.xxl)
                } else {
                    kpis
                    PersonTable(viewModel: viewModel, stats: statistics.byPerson)
                    BlockTable(stats: statistics.byBlock)
                }
            }
            .padding(.bottom, IrisSpacing.lg)
        }
        .scrollIndicators(.hidden)
        .sheet(isPresented: $viewModel.isPickingMonth) {
            MonthPickerView(viewModel: viewModel)
        }
        .sheet(item: $viewModel.personDetail) { detail in
            PersonTimesView(viewModel: viewModel, personID: detail.id)
        }
    }

    // MARK: Filters

    private var filters: some View {
        HStack(spacing: IrisSpacing.xs) {
            Menu {
                ForEach(TimesViewModel.periods, id: \.self) { period in
                    Button(viewModel.periodTitle(period)) { viewModel.setPeriod(period) }
                }
                Divider()
                Button("Elegir mes…", systemImage: "calendar") { viewModel.beginPickingMonth() }
            } label: {
                FilterLabel(title: viewModel.periodTitle(viewModel.summaryFilter.period))
            }

            Menu {
                Button("Todos") { viewModel.setServiceFilter(nil) }
                Divider()
                ForEach(viewModel.serviceTypes) { type in
                    Button(type.name) { viewModel.setServiceFilter(type.id) }
                }
            } label: {
                FilterLabel(title: viewModel.serviceFilterTitle)
            }

            Menu {
                Button("Todos") { viewModel.setBlockFilter(nil) }
                Divider()
                ForEach(viewModel.blockNames, id: \.self) { name in
                    Button(name) { viewModel.setBlockFilter(name) }
                }
            } label: {
                FilterLabel(title: viewModel.blockFilterTitle)
            }

            Menu {
                Button("Todas") { viewModel.setPersonFilter(nil) }
                Divider()
                ForEach(viewModel.filterPeople) { person in
                    Button(person.name) { viewModel.setPersonFilter(person.id) }
                }
            } label: {
                FilterLabel(title: viewModel.personFilterTitle)
            }
        }
        .menuStyle(.button)
        .buttonStyle(.irisPill)
    }

    // MARK: KPIs

    private var kpis: some View {
        HStack(spacing: IrisSpacing.md) {
            KPICard(title: "Servicios", value: viewModel.serviceCountText, tint: IrisColor.textPrimary)
            KPICard(title: "Duración promedio", value: viewModel.averageDurationText, tint: IrisColor.textPrimary)
            KPICard(
                title: "Exceso promedio por servicio",
                value: viewModel.averageOvertimeText,
                tint: viewModel.statistics.averageOvertimePerService > 0 ? IrisColor.danger : IrisColor.success
            )
            KPICard(title: "Bloques pasados", value: viewModel.overBlocksText, tint: IrisColor.textPrimary)
        }
    }
}

private struct KPICard: View {
    let title: LocalizedStringKey
    let value: String
    let tint: Color

    var body: some View {
        IrisSurface(padding: IrisSpacing.md, cornerRadius: IrisRadius.xl) {
            VStack(alignment: .leading, spacing: IrisSpacing.xxs) {
                Text(title)
                    .font(IrisFont.caption)
                    .foregroundStyle(IrisColor.textTertiary)
                    .lineLimit(1)
                Text(value)
                    .font(.system(.title3, design: .rounded, weight: .semibold).monospacedDigit())
                    .foregroundStyle(tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - By person

private struct PersonTable: View {
    let viewModel: TimesViewModel
    let stats: [TimeStatistics.PersonStat]

    private static let numberColumn: CGFloat = 112

    var body: some View {
        VStack(alignment: .leading, spacing: IrisSpacing.sm) {
            IrisSectionHeader("POR PERSONA")
            IrisSurface(padding: IrisSpacing.md, cornerRadius: IrisRadius.xl) {
                VStack(spacing: 0) {
                    headerRow
                    ForEach(Array(stats.enumerated()), id: \.element.id) { index, stat in
                        Divider()
                            .overlay(IrisColor.stroke)
                        Button {
                            viewModel.showPersonDetail(stat.personID)
                        } label: {
                            row(stat, tint: IrisGradient.spectrum[index % IrisGradient.spectrum.count])
                        }
                        .buttonStyle(.irisPressable)
                    }
                }
            }
        }
    }

    private var headerRow: some View {
        HStack(spacing: IrisSpacing.sm) {
            Text("Persona").frame(maxWidth: .infinity, alignment: .leading)
            Text("Participaciones").frame(width: Self.numberColumn, alignment: .trailing)
            Text("Veces que se pasó").frame(width: Self.numberColumn, alignment: .trailing)
            Text("Exceso promedio").frame(width: Self.numberColumn, alignment: .trailing)
            Text("Exceso máximo").frame(width: Self.numberColumn, alignment: .trailing)
            Text("Exceso total").frame(width: Self.numberColumn, alignment: .trailing)
        }
        .font(IrisFont.caption)
        .foregroundStyle(IrisColor.textTertiary)
        .lineLimit(1)
        .padding(.bottom, IrisSpacing.xs)
    }

    private func row(_ stat: TimeStatistics.PersonStat, tint: Color) -> some View {
        HStack(spacing: IrisSpacing.sm) {
            HStack(spacing: IrisSpacing.sm) {
                Text(viewModel.initials(stat.personID))
                    .font(.system(.caption2, weight: .bold))
                    .foregroundStyle(IrisColor.textInverse)
                    .frame(width: 32, height: 32)
                    .background(tint, in: Circle())
                Text(viewModel.personName(stat.personID))
                    .font(IrisFont.calloutEmphasized)
                    .foregroundStyle(IrisColor.textPrimary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            number("\(stat.participations)")
            number("\(stat.timesOver)")
            number(IrisDurationFormat.overtime(stat.avgOvertimeWhenOver.rounded()))
            number(IrisDurationFormat.overtime(stat.maxOvertime))
            number(IrisDurationFormat.overtime(stat.totalOvertime))
        }
        .padding(.vertical, IrisSpacing.xs)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text("Ver sus bloques"))
    }

    private func number(_ text: String) -> some View {
        Text(text.isEmpty ? "—" : text)
            .font(.system(.callout, design: .monospaced, weight: .medium))
            .foregroundStyle(IrisColor.textSecondary)
            .frame(width: Self.numberColumn, alignment: .trailing)
    }
}

// MARK: - By block

private struct BlockTable: View {
    let stats: [TimeStatistics.BlockStat]

    var body: some View {
        VStack(alignment: .leading, spacing: IrisSpacing.sm) {
            IrisSectionHeader("POR BLOQUE")
            IrisSurface(padding: IrisSpacing.md, cornerRadius: IrisRadius.xl) {
                VStack(spacing: 0) {
                    ForEach(Array(stats.enumerated()), id: \.element.id) { index, stat in
                        if index > 0 {
                            Divider()
                                .overlay(IrisColor.stroke)
                        }
                        row(stat)
                    }
                }
            }
        }
    }

    private func row(_ stat: TimeStatistics.BlockStat) -> some View {
        HStack(spacing: IrisSpacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text(stat.name)
                    .font(IrisFont.calloutEmphasized)
                    .foregroundStyle(IrisColor.textPrimary)
                Text("Se pasó \(stat.timesOver) de \(stat.total) veces")
                    .font(IrisFont.caption)
                    .foregroundStyle(IrisColor.textTertiary)
            }
            .frame(width: 200, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text("Exceso promedio")
                    .font(IrisFont.caption)
                    .foregroundStyle(IrisColor.textTertiary)
                Text(stat.timesOver > 0 ? IrisDurationFormat.overtime(stat.avgOvertimeWhenOver.rounded()) : "—")
                    .font(.system(.callout, design: .monospaced, weight: .medium))
                    .foregroundStyle(stat.timesOver > 0 ? IrisColor.danger : IrisColor.textSecondary)
            }
            .frame(width: 120, alignment: .leading)

            IrisTimeBar(planned: stat.avgPlanned, actual: stat.avgActual, scale: max(1, stat.avgPlanned, stat.avgActual) * 1.1)

            Text("\(IrisDurationFormat.clock(stat.avgActual)) / \(IrisDurationFormat.clock(stat.avgPlanned))")
                .font(.system(.callout, design: .monospaced, weight: .medium))
                .foregroundStyle(IrisColor.textSecondary)
                .frame(width: 130, alignment: .trailing)
        }
        .padding(.vertical, IrisSpacing.sm)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Sheets

/// "Elegir mes…": month and year wheels.
private struct MonthPickerView: View {
    @Bindable var viewModel: TimesViewModel

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: IrisSpacing.lg) {
            HStack {
                Text("Elegir mes")
                    .font(IrisFont.title)
                    .foregroundStyle(IrisColor.textPrimary)
                Spacer()
                Button("Cancelar") { dismiss() }
                    .buttonStyle(.irisPill)
            }

            HStack(spacing: IrisSpacing.md) {
                Picker("Mes", selection: $viewModel.pickedMonth) {
                    ForEach(1...12, id: \.self) { month in
                        Text(viewModel.monthName(month)).tag(month)
                    }
                }
                Picker("Año", selection: $viewModel.pickedYear) {
                    ForEach(viewModel.pickableYears, id: \.self) { year in
                        Text(verbatim: "\(year)").tag(year)
                    }
                }
            }
            .pickerStyle(.wheel)
            .colorScheme(.dark)

            Button("Ver este mes") { viewModel.confirmPickedMonth() }
                .buttonStyle(.irisPrimary)
        }
        .padding(IrisSpacing.xl)
        .presentationSizing(.form)
        .presentationBackground(IrisColor.canvasElevated)
    }
}

/// One person's blocks under the current filters, to talk with them about it.
private struct PersonTimesView: View {
    let viewModel: TimesViewModel
    let personID: Person.ID

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let stats = viewModel.personStatistics(personID)

        VStack(alignment: .leading, spacing: IrisSpacing.lg) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: IrisSpacing.xxs) {
                    Text(viewModel.personName(personID))
                        .font(IrisFont.title)
                        .foregroundStyle(IrisColor.textPrimary)
                    Text("\(viewModel.personSummary(personID)) · \(viewModel.periodTitle(viewModel.summaryFilter.period))")
                        .font(IrisFont.callout)
                        .foregroundStyle(IrisColor.textSecondary)
                }
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
                LazyVStack(spacing: 0) {
                    ForEach(stats.entries) { entry in
                        entryRow(entry)
                        Divider()
                            .overlay(IrisColor.stroke)
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
        .padding(IrisSpacing.xl)
        .presentationSizing(.page)
        .presentationBackground(IrisColor.canvasElevated)
    }

    private func entryRow(_ entry: TimeStatistics.Entry) -> some View {
        HStack(spacing: IrisSpacing.md) {
            Text(viewModel.shortDate(entry.date))
                .font(IrisFont.callout)
                .foregroundStyle(IrisColor.textSecondary)
                .frame(width: 130, alignment: .leading)
            Text(viewModel.serviceName(entry.serviceTypeID))
                .font(IrisFont.callout)
                .foregroundStyle(IrisColor.textSecondary)
                .frame(width: 160, alignment: .leading)
            Text(entry.block.name)
                .font(IrisFont.calloutEmphasized)
                .foregroundStyle(IrisColor.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("\(IrisDurationFormat.clock(entry.block.actualSeconds)) / \(IrisDurationFormat.clock(entry.block.plannedSeconds))")
                .font(.system(.callout, design: .monospaced, weight: .medium))
                .foregroundStyle(IrisColor.textSecondary)
            Text(TimesViewModel.overtimeText(entry.block.overtimeSeconds))
                .font(.system(.callout, design: .monospaced, weight: .semibold))
                .foregroundStyle(entry.block.isOver ? IrisColor.danger : IrisColor.success)
                .frame(width: 80, alignment: .trailing)
        }
        .padding(.vertical, IrisSpacing.sm)
        .accessibilityElement(children: .combine)
    }
}
