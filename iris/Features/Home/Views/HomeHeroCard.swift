//
//  HomeHeroCard.swift
//  iris
//

import SwiftUI

/// The main call to action of Home: pick a service type and start it,
/// or configure the first one when there are none.
struct HomeHeroCard: View {
    let viewModel: HomeViewModel

    private static let tvPreviewBackground = ProjectionBackground(
        id: "aurora", name: "Aurora", colors: [0x2A1658, 0x4E2A8C, 0x131E5C], isAnimated: false
    )

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: IrisRadius.xxl, style: .continuous)

        HStack(alignment: .center, spacing: IrisSpacing.xxl) {
            leadingColumn
            Spacer(minLength: 0)
            detailColumn
                .frame(width: 380)
        }
        .padding(IrisSpacing.xxl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { backdrop.clipShape(shape) }
        .overlay {
            shape.strokeBorder(
                LinearGradient(colors: [.white.opacity(0.2), .white.opacity(0.04)], startPoint: .top, endPoint: .bottom),
                lineWidth: 1
            )
        }
        .shadow(color: .black.opacity(0.5), radius: 50, y: 30)
        .animation(IrisMotion.smooth, value: viewModel.selectedServiceTypeID)
    }

    // MARK: Backdrop

    /// The base color defines the size; glows and the oversized mark are overlays so they get clipped.
    private var backdrop: some View {
        IrisColor.canvasElevated
            .overlay {
                RadialGradient(
                    colors: [Color(hex: viewModel.selectedServiceType?.color ?? 0x2A1658).opacity(0.35), .clear],
                    center: .bottomLeading, startRadius: 0, endRadius: 520
                )
            }
            .overlay {
                RadialGradient(colors: [IrisColor.glowViolet, .clear], center: .topTrailing, startRadius: 0, endRadius: 560)
            }
            .overlay(alignment: .trailing) {
                IrisMark(size: 520)
                    .opacity(0.2)
                    .blur(radius: 2)
                    .offset(x: 220, y: 120)
            }
    }

    // MARK: Leading column

    @ViewBuilder
    private var leadingColumn: some View {
        if viewModel.needsServiceSetup {
            setupColumn
        } else {
            startColumn
        }
    }

    /// Serif title shared by the service name and the setup invitation.
    private var titleFont: Font {
        .system(size: 52, weight: .medium, design: .serif)
    }

    private var setupColumn: some View {
        VStack(alignment: .leading, spacing: IrisSpacing.lg) {
            VStack(alignment: .leading, spacing: IrisSpacing.sm) {
                Text("Crea tu primer servicio")
                    .font(titleFont)
                    .tracking(IrisTracking.tight)
                    .foregroundStyle(IrisColor.textPrimary)

                Text("Configura tus tipos de servicio y, si quieres, sus bloques de tiempo.")
                    .font(IrisFont.callout)
                    .foregroundStyle(IrisColor.textSecondary)
            }

            Button {
                viewModel.openServices()
            } label: {
                Text("Configurar servicios")
            }
            .buttonStyle(.irisPrimary)
            .frame(width: 280)
        }
    }

    private var startColumn: some View {
        VStack(alignment: .leading, spacing: IrisSpacing.lg) {
            HStack(spacing: IrisSpacing.xs) {
                if viewModel.isSelectedToday {
                    IrisLiveDot()
                }
                Group {
                    if viewModel.isSelectedToday {
                        Text("SERVICIO DE HOY")
                    } else {
                        Text("PRÓXIMO SERVICIO")
                    }
                }
                .font(IrisFont.overline)
                    .tracking(IrisTracking.overline)
                    .foregroundStyle(IrisColor.textSecondary)
            }

            VStack(alignment: .leading, spacing: IrisSpacing.sm) {
                Text(viewModel.selectedServiceType?.name ?? "")
                    .font(titleFont)
                    .tracking(IrisTracking.tight)
                    .foregroundStyle(IrisColor.textPrimary)
                    .contentTransition(.opacity)

                HStack(spacing: IrisSpacing.md) {
                    if let schedule = viewModel.selectedScheduleText {
                        Label(schedule, systemImage: "calendar")
                    }
                    if viewModel.selectedBlocks.isEmpty {
                        Label("Solo proyección", systemImage: "tv")
                    } else {
                        Label(
                            "\(viewModel.selectedBlocks.count) bloques · \(IrisDurationFormat.summary(viewModel.selectedServiceType?.plannedSeconds ?? 0))",
                            systemImage: "timer"
                        )
                    }
                }
                .font(IrisFont.callout)
                .foregroundStyle(IrisColor.textSecondary)
            }

            serviceTypePicker

            Button {
                viewModel.startSelectedService()
            } label: {
                Label("Iniciar servicio", systemImage: "play.fill")
            }
            .buttonStyle(.irisPrimary)
            .frame(width: 280)
            .disabled(viewModel.selectedServiceType == nil)
        }
    }

    /// Scrolls sideways when a church has more types than fit.
    private var serviceTypePicker: some View {
        ScrollView(.horizontal) {
            serviceTypePills
        }
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
    }

    private var serviceTypePills: some View {
        HStack(spacing: IrisSpacing.xs) {
            ForEach(viewModel.serviceTypes) { type in
                let isSelected = type.id == viewModel.selectedServiceTypeID
                Button {
                    viewModel.selectServiceType(type.id)
                } label: {
                    HStack(spacing: IrisSpacing.xs) {
                        Circle()
                            .fill(Color(hex: type.color))
                            .frame(width: 8, height: 8)
                        Text(type.name)
                            .font(IrisFont.calloutEmphasized)
                    }
                    .foregroundStyle(isSelected ? IrisColor.textInverse : IrisColor.textSecondary)
                    .padding(.horizontal, IrisSpacing.md - 2)
                    .frame(height: 38)
                    .background(isSelected ? AnyShapeStyle(IrisColor.textPrimary) : AnyShapeStyle(IrisColor.surface), in: Capsule())
                    .overlay(Capsule().strokeBorder(isSelected ? .clear : IrisColor.stroke))
                    .contentShape(Capsule())
                }
                .buttonStyle(.irisPressable)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
    }

    // MARK: Detail column

    @ViewBuilder
    private var detailColumn: some View {
        if viewModel.selectedBlocks.isEmpty {
            VStack(alignment: .leading, spacing: IrisSpacing.sm) {
                ProjectionCanvas(
                    frame: ProjectionFrame(
                        background: Self.tvPreviewBackground,
                        content: .logo(viewModel.session.churchName)
                    ),
                    cornerRadius: IrisRadius.lg
                )
                .overlay {
                    RoundedRectangle(cornerRadius: IrisRadius.lg, style: .continuous)
                        .strokeBorder(IrisColor.strokeStrong)
                }
                .frame(maxWidth: .infinity)

                if viewModel.selectedServiceType != nil {
                    Text("Este servicio no controla tiempos: solo proyección.")
                        .font(IrisFont.caption)
                        .foregroundStyle(IrisColor.textTertiary)
                }
            }
            .transition(.opacity)
        } else {
            BlockPlanView(blocks: viewModel.selectedBlocks) { viewModel.personName($0) }
                .transition(.opacity)
        }
    }
}

/// Proportional timeline of a service's blocks plus their list.
struct BlockPlanView: View {
    let blocks: [BlockTemplate]
    let personName: (Person.ID?) -> String?

    var body: some View {
        VStack(alignment: .leading, spacing: IrisSpacing.md) {
            IrisSectionHeader("BLOQUES") {
                Text(IrisDurationFormat.summary(blocks.reduce(0) { $0 + $1.plannedSeconds }))
            }

            BlockTimeline(blocks: blocks)

            VStack(spacing: IrisSpacing.xs) {
                ForEach(Array(blocks.enumerated()), id: \.element.id) { index, block in
                    HStack(spacing: IrisSpacing.sm) {
                        Circle()
                            .fill(color(at: index))
                            .frame(width: 8, height: 8)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(block.name)
                                .font(IrisFont.calloutEmphasized)
                                .foregroundStyle(IrisColor.textPrimary)
                            if let name = personName(block.defaultPersonID) {
                                Text(name)
                                    .font(IrisFont.caption)
                                    .foregroundStyle(IrisColor.textTertiary)
                            }
                        }
                        Spacer(minLength: 0)
                        Text("\(block.plannedMinutes) min")
                            .font(.system(.callout, design: .monospaced, weight: .medium))
                            .foregroundStyle(IrisColor.textSecondary)
                    }
                    .padding(.vertical, IrisSpacing.xxs)
                }
            }
        }
    }

    private func color(at index: Int) -> Color {
        BlockTimeline.color(at: index)
    }
}

/// Capsules proportional to each block's planned minutes, in spectrum colors.
struct BlockTimeline: View {
    let blocks: [BlockTemplate]

    static func color(at index: Int) -> Color {
        IrisGradient.spectrum[index % IrisGradient.spectrum.count]
    }

    var body: some View {
        GeometryReader { proxy in
            let total = max(1, blocks.reduce(0) { $0 + $1.plannedMinutes })
            let spacing: CGFloat = 3
            let available = proxy.size.width - spacing * CGFloat(max(0, blocks.count - 1))
            HStack(spacing: spacing) {
                ForEach(Array(blocks.enumerated()), id: \.element.id) { index, block in
                    Capsule()
                        .fill(Self.color(at: index))
                        .frame(width: max(0, available * CGFloat(block.plannedMinutes) / CGFloat(total)))
                }
            }
        }
        .frame(height: 8)
        .accessibilityHidden(true)
    }
}
