//
//  TimesView.swift
//  iris
//

import SwiftUI

/// Tiempos: saved records (list + detail) and summaries with filters.
struct TimesView: View {
    @State private var viewModel: TimesViewModel

    init(viewModel: TimesViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
                    .tint(IrisColor.textSecondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(alignment: .leading, spacing: IrisSpacing.lg) {
                    header
                    if let errorMessage = viewModel.errorMessage {
                        IrisBanner(style: .error, message: errorMessage)
                    }
                    content
                }
                .padding(.horizontal, IrisSpacing.lg)
                .padding(.top, IrisSpacing.xs)
                .padding(.bottom, IrisSpacing.md)
                .frame(maxWidth: IrisSize.contentWidth)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task { await viewModel.load() }
    }

    private var header: some View {
        HStack(spacing: IrisSpacing.lg) {
            Text("Tiempos")
                .font(IrisFont.headline)
                .tracking(IrisTracking.tight)
                .foregroundStyle(IrisColor.textPrimary)
            Spacer(minLength: IrisSpacing.md)
            IrisSegmentedControl(options: TimesViewModel.Tab.allCases, selection: $viewModel.tab, title: \.title)
                .frame(maxWidth: 360)
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.records.isEmpty {
            ContentUnavailableView {
                Label("Aún no hay tiempos", systemImage: "timer")
            } description: {
                Text("Se guardan al terminar un servicio con bloques.")
            }
            .foregroundStyle(IrisColor.textSecondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            switch viewModel.tab {
            case .records:
                recordsSplit
            case .summaries:
                TimeSummaryView(viewModel: viewModel)
            }
        }
    }

    // MARK: Records

    private var recordsSplit: some View {
        HStack(alignment: .top, spacing: IrisSpacing.md) {
            IrisSurface(padding: IrisSpacing.md, cornerRadius: IrisRadius.xl) {
                recordList
                    .frame(maxHeight: .infinity, alignment: .top)
            }
            .frame(width: 380)

            IrisSurface(padding: IrisSpacing.lg, cornerRadius: IrisRadius.xl) {
                Group {
                    if let record = viewModel.selectedRecord {
                        TimeRecordDetailView(viewModel: viewModel, record: record)
                    } else {
                        ContentUnavailableView("Selecciona un registro", systemImage: "timer")
                            .foregroundStyle(IrisColor.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
    }

    private var recordList: some View {
        VStack(alignment: .leading, spacing: IrisSpacing.md) {
            Menu {
                Button("Todos los servicios") { viewModel.setRecordFilter(nil) }
                Divider()
                ForEach(viewModel.recordFilterOptions) { type in
                    Button(type.name) { viewModel.setRecordFilter(type.id) }
                }
            } label: {
                FilterLabel(title: viewModel.recordFilterTitle)
            }
            .menuStyle(.button)
            .buttonStyle(.irisPill)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: IrisSpacing.md) {
                    ForEach(viewModel.recordSections) { section in
                        VStack(alignment: .leading, spacing: IrisSpacing.xxs) {
                            IrisSectionHeader(LocalizedStringKey(section.title))
                                .padding(.horizontal, IrisSpacing.xs)
                            ForEach(section.records) { record in
                                recordButton(record)
                            }
                        }
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
    }

    private func recordButton(_ record: ServiceRecord) -> some View {
        Button {
            withAnimation(IrisMotion.snappy) { viewModel.selectRecord(record.id) }
        } label: {
            TimeRecordRow(
                name: viewModel.serviceName(record.serviceTypeID),
                color: viewModel.serviceColor(record.serviceTypeID),
                date: viewModel.shortDate(record.date),
                duration: IrisDurationFormat.clock(record.actualSeconds),
                overtime: record.overtimeSeconds,
                isSelected: record.id == viewModel.selectedRecordID
            )
        }
        .buttonStyle(.irisPressable)
    }
}

/// Current value of a filter menu with a chevron.
struct FilterLabel: View {
    let title: String

    var body: some View {
        HStack(spacing: IrisSpacing.xxs + 2) {
            Text(title)
                .lineLimit(1)
            Image(systemName: "chevron.down")
                .font(.system(.caption2, weight: .bold))
        }
    }
}

/// Color dot, service, date, total and overtime chip.
private struct TimeRecordRow: View {
    let name: String
    let color: UInt32?
    let date: String
    let duration: String
    let overtime: TimeInterval
    let isSelected: Bool

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: IrisRadius.md, style: .continuous)
    }

    var body: some View {
        HStack(spacing: IrisSpacing.sm) {
            Circle()
                .fill(color.map { Color(hex: $0) } ?? IrisColor.textTertiary)
                .frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(IrisFont.calloutEmphasized)
                    .foregroundStyle(IrisColor.textPrimary)
                    .lineLimit(1)
                Text(date)
                    .font(IrisFont.caption)
                    .foregroundStyle(IrisColor.textTertiary)
            }
            Spacer(minLength: IrisSpacing.xs)
            Text(duration)
                .font(.system(.callout, design: .monospaced, weight: .semibold))
                .foregroundStyle(IrisColor.textPrimary)
            overtimeChip
        }
        .padding(.horizontal, IrisSpacing.sm)
        .padding(.vertical, IrisSpacing.sm - 2)
        .background {
            if isSelected {
                shape.fill(IrisColor.surfaceRaised)
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(IrisGradient.accent)
                            .frame(width: 3)
                            .padding(.vertical, IrisSpacing.sm)
                    }
            }
        }
        .contentShape(shape)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private var overtimeChip: some View {
        if overtime > 0 {
            IrisChip("\(IrisDurationFormat.overtime(overtime))", tint: IrisColor.danger)
        } else {
            IrisChip("A tiempo", tint: IrisColor.success)
        }
    }
}

extension TimesViewModel {
    /// Already-loaded view model for previews.
    static var preview: TimesViewModel { makePreview(store: InMemoryChurchStore()) }

    /// No records yet.
    static var emptyPreview: TimesViewModel { makePreview(store: InMemoryChurchStore(seed: .empty)) }

    static func makePreview(store: InMemoryChurchStore) -> TimesViewModel {
        let viewModel = TimesViewModel(
            timeRecords: MockTimeRecordRepository(store: store, latency: .zero),
            serviceTypes: MockServiceTypeRepository(store: store, latency: .zero),
            people: MockPeopleRepository(store: store, latency: .zero)
        )
        viewModel.apply(records: store.records, serviceTypes: store.serviceTypes, people: store.people)
        return viewModel
    }
}

#Preview("Registros", traits: .landscapeLeft) {
    TimesView(viewModel: .preview)
        .background { IrisBackground(isAnimated: false) }
        .preferredColorScheme(.dark)
        .environment(\.locale, Locale(identifier: "es"))
}

#Preview("Resúmenes", traits: .landscapeLeft) {
    let viewModel = TimesViewModel.preview
    viewModel.tab = .summaries
    return TimesView(viewModel: viewModel)
        .background { IrisBackground(isAnimated: false) }
        .preferredColorScheme(.dark)
        .environment(\.locale, Locale(identifier: "es"))
}

#Preview("Vacío", traits: .landscapeLeft) {
    TimesView(viewModel: .emptyPreview)
        .background { IrisBackground(isAnimated: false) }
        .preferredColorScheme(.dark)
        .environment(\.locale, Locale(identifier: "es"))
}
