//
//  ServiceTypesView.swift
//  iris
//

import SwiftUI

/// Grid of the church's service types. A card opens the editor; "Nuevo servicio" creates one.
struct ServiceTypesView: View {
    @State private var viewModel: ServiceTypesViewModel

    private let columns = [GridItem(.adaptive(minimum: 320), spacing: IrisSpacing.md, alignment: .top)]

    init(viewModel: ServiceTypesViewModel) {
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
                    VStack(alignment: .leading, spacing: IrisSpacing.xl) {
                        header
                        if viewModel.serviceTypes.isEmpty {
                            emptyState
                        } else {
                            grid
                        }
                    }
                    .padding(.horizontal, IrisSpacing.xxl)
                    .padding(.top, IrisSpacing.md)
                    .padding(.bottom, IrisSpacing.xxl)
                    .frame(maxWidth: IrisSize.contentWidth)
                    .frame(maxWidth: .infinity)
                }
                .scrollIndicators(.hidden)
            }
        }
        .task { await viewModel.load() }
        .sheet(item: $viewModel.editor) { editor in
            ServiceTypeEditorView(viewModel: editor)
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: IrisSpacing.lg) {
            VStack(alignment: .leading, spacing: IrisSpacing.xs) {
                Text("Servicios")
                    .font(IrisFont.headline)
                    .tracking(IrisTracking.tight)
                    .foregroundStyle(IrisColor.textPrimary)
                Text("Crea los servicios de tu iglesia y, si quieres, sus bloques de tiempo.")
                    .font(IrisFont.callout)
                    .foregroundStyle(IrisColor.textSecondary)
            }

            Spacer(minLength: 0)

            Button {
                viewModel.createServiceType()
            } label: {
                Label("Nuevo servicio", systemImage: "plus")
            }
            .buttonStyle(.irisPrimary)
            .frame(width: 240)
        }
    }

    private var grid: some View {
        LazyVGrid(columns: columns, spacing: IrisSpacing.md) {
            ForEach(viewModel.serviceTypes) { type in
                ServiceTypeCard(
                    type: type,
                    scheduleText: viewModel.scheduleText(for: type),
                    blocksSummary: viewModel.showsBlocks(of: type) ? viewModel.blocksSummary(for: type) : nil
                ) {
                    viewModel.edit(type)
                }
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Aún no hay servicios", systemImage: "calendar")
        } actions: {
            Button("Crear el primero") {
                viewModel.createServiceType()
            }
            .buttonStyle(.irisPrimary)
            .frame(width: 260)
        }
        .foregroundStyle(IrisColor.textSecondary)
        .padding(.top, IrisSpacing.xxl)
    }
}

/// Color band, name, schedule and either the block plan or "Solo proyección".
private struct ServiceTypeCard: View {
    let type: ServiceType
    let scheduleText: String
    /// `nil` when the service does not track time.
    let blocksSummary: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            IrisSurface(padding: IrisSpacing.lg, cornerRadius: IrisRadius.xl) {
                VStack(alignment: .leading, spacing: IrisSpacing.md) {
                    Capsule()
                        .fill(Color(hex: type.color))
                        .frame(height: 4)

                    VStack(alignment: .leading, spacing: IrisSpacing.xxs) {
                        Text(type.name)
                            .font(IrisFont.title)
                            .tracking(IrisTracking.tight)
                            .foregroundStyle(IrisColor.textPrimary)
                            .lineLimit(1)
                        Label(scheduleText, systemImage: "calendar")
                            .font(IrisFont.callout)
                            .foregroundStyle(IrisColor.textSecondary)
                    }

                    if let blocksSummary {
                        BlockTimeline(blocks: type.blocks)
                        IrisChip("\(blocksSummary)", systemImage: "timer", tint: IrisColor.success)
                    } else {
                        IrisChip("Solo proyección", tint: IrisColor.textTertiary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(.irisPressable)
        .accessibilityHint(Text("Editar servicio"))
    }
}

extension ServiceTypesViewModel {
    /// Already-loaded view model for previews.
    static var preview: ServiceTypesViewModel { makePreview(store: InMemoryChurchStore()) }

    /// No service types yet.
    static var emptyPreview: ServiceTypesViewModel { makePreview(store: InMemoryChurchStore(seed: .empty)) }

    private static func makePreview(store: InMemoryChurchStore) -> ServiceTypesViewModel {
        let viewModel = ServiceTypesViewModel(
            serviceTypes: MockServiceTypeRepository(store: store, latency: .zero),
            people: MockPeopleRepository(store: store, latency: .zero),
            moduleSettings: MockModuleSettingsRepository(store: store, latency: .zero)
        )
        viewModel.apply(serviceTypes: store.serviceTypes, modules: store.modules)
        return viewModel
    }
}

#Preview("Landscape", traits: .landscapeLeft) {
    ServiceTypesView(viewModel: .preview)
        .background { IrisBackground(isAnimated: false) }
        .preferredColorScheme(.dark)
        .environment(\.locale, Locale(identifier: "es"))
}

#Preview("Vacío", traits: .landscapeLeft) {
    ServiceTypesView(viewModel: .emptyPreview)
        .background { IrisBackground(isAnimated: false) }
        .preferredColorScheme(.dark)
        .environment(\.locale, Locale(identifier: "es"))
}
