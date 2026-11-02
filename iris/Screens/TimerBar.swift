//
//  TimerBar.swift
//  iris
//

import SwiftUI

/// The service clock across the top, like the computer's: current block, time, and the button for the next one.
/// The computer picks and starts the service; the iPad only moves it along.
struct TimerBar: View {
    let client: RemoteClient
    let service: RemoteState.Service
    let state: RemoteState
    /// Opens "¿Quién dirige…?" for a block.
    let onLeader: (Int) -> Void
    /// Opens "Agregar bloque": an extra block for this service only.
    let onAddBlock: () -> Void

    @State private var isConfirmingFinish = false

    private var currentIndex: Int? { service.blocks.firstIndex { $0.status == .current } }

    /// The block that "Siguiente" starts: the first pending one after the current (or the first, before starting).
    private var next: RemoteState.Service.Block? {
        service.blocks.enumerated().first { $0.offset > (currentIndex ?? -1) && $0.element.status == .pending }?.element
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let elapsed = client.elapsed(of: service, at: context.date)
            VStack(spacing: IrisSpacing.sm) {
                HStack(alignment: .center, spacing: IrisSpacing.lg) {
                    clock(elapsed: elapsed)
                    breadcrumbs
                    Spacer(minLength: 0)
                    if service.phase != .finished {
                        Button(action: onAddBlock) {
                            Label("Bloque", systemImage: "plus").padding(.horizontal, IrisSpacing.xs)
                        }
                        .buttonStyle(.irisGlass)
                        .fixedSize()
                        .accessibilityLabel("Agregar bloque")
                    }
                    advanceButton
                }
                progress(elapsed: elapsed)
            }
        }
        .padding(IrisSpacing.md)
        .background(IrisColor.canvasElevated.opacity(0.72), in: RoundedRectangle(cornerRadius: IrisRadius.lg))
        .overlay(RoundedRectangle(cornerRadius: IrisRadius.lg).strokeBorder(IrisColor.stroke, lineWidth: 1))
    }

    @ViewBuilder
    private func clock(elapsed: Double) -> some View {
        if let index = currentIndex, service.phase == .running {
            let block = service.blocks[index]
            VStack(alignment: .leading, spacing: IrisSpacing.xxs) {
                HStack(spacing: IrisSpacing.xs) {
                    IrisLiveDot()
                    Text(block.name.uppercased())
                        .font(IrisFont.overline)
                        .tracking(IrisTracking.caps)
                    Button { onLeader(index) } label: {
                        HStack(spacing: 4) {
                            Text(block.leader.map { "· \($0)" } ?? "· ¿Quién dirige?")
                            Image(systemName: "chevron.down").font(.caption2)
                        }
                        .font(IrisFont.callout)
                        .foregroundStyle(block.leader == nil ? IrisColor.coral : IrisColor.textSecondary)
                    }
                    .buttonStyle(.irisPressable)
                }
                HStack(alignment: .firstTextBaseline, spacing: IrisSpacing.xs) {
                    Text(elapsed.clock)
                        .font(.system(size: 32, weight: .semibold, design: .monospaced))
                    Text("/ \(block.plannedSeconds.clock)")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(IrisColor.textSecondary)
                    let left = block.plannedSeconds - elapsed
                    Text(left >= 0 ? "-\(left.clock)" : "+\((-left).clock)")
                        .font(.system(.caption, design: .monospaced))
                        .padding(.horizontal, IrisSpacing.xs)
                        .padding(.vertical, 2)
                        .background(IrisColor.surfaceRaised, in: Capsule())
                        .foregroundStyle(left >= 0 ? IrisColor.textPrimary : IrisColor.danger)
                }
            }
        } else {
            VStack(alignment: .leading, spacing: IrisSpacing.xxs) {
                ServiceChooser(client: client, state: state, title: service.name)
                Text(service.phase == .finished ? "Servicio terminado" : "Listo para empezar")
                    .font(IrisFont.callout)
                    .foregroundStyle(IrisColor.textSecondary)
            }
        }
    }

    @ViewBuilder
    private var advanceButton: some View {
        if service.phase == .finished {
            EmptyView()
        } else if service.canAdvance, let next {
            Button {
                client.send(.nextBlock)
            } label: {
                Text(service.phase == .notStarted ? "Comenzar: \(next.name) →" : "Siguiente: \(next.name) →")
                    .padding(.horizontal, IrisSpacing.sm)
            }
            .buttonStyle(.irisPrimary)
            .fixedSize()
        } else {
            // The last block: finishing saves the times, like "Finalizar servicio" on the computer.
            Button { isConfirmingFinish = true } label: {
                Text("Terminar servicio").padding(.horizontal, IrisSpacing.md)
            }
                .buttonStyle(.irisGlass)
                .fixedSize()
                .confirmationDialog("¿Terminar el servicio?", isPresented: $isConfirmingFinish) {
                    Button("Terminar", role: .destructive) { client.send(.finishService) }
                } message: {
                    Text("Se guardan los tiempos de los bloques en Tiempos.")
                }
        }
    }

    @ViewBuilder
    private func progress(elapsed: Double) -> some View {
        if let index = currentIndex, service.phase == .running {
            let planned = max(service.blocks[index].plannedSeconds, 1)
            Capsule()
                .fill(IrisColor.surfaceRaised)
                .frame(height: 4)
                .overlay(alignment: .leading) {
                    GeometryReader { proxy in
                        Capsule()
                            .fill(elapsed > planned ? IrisColor.danger : IrisColor.success)
                            .frame(width: proxy.size.width * min(elapsed / planned, 1))
                    }
                }
        }
    }

    /// Finished blocks with a check, the current one highlighted, pending ones dimmed.
    private var breadcrumbs: some View {
        ScrollView(.horizontal) {
            HStack(spacing: IrisSpacing.sm) {
                ForEach(service.blocks.filter { $0.status != .skipped }) { block in
                    let isDone = block.status == .done
                    let isCurrent = block.status == .current
                    HStack(spacing: 4) {
                        if isDone { Image(systemName: "checkmark").foregroundStyle(IrisColor.success) }
                        Text(block.name)
                    }
                    .font(IrisFont.caption)
                    .foregroundStyle(isCurrent ? IrisColor.textPrimary : IrisColor.textSecondary)
                    .opacity(isDone || isCurrent ? 1 : 0.6)
                }
            }
        }
        .scrollIndicators(.hidden)
    }
}

/// The service's name as a menu: before it starts, any of the church's services can be chosen here.
/// Creating or editing them is done on the computer.
struct ServiceChooser: View {
    let client: RemoteClient
    let state: RemoteState
    let title: String

    var body: some View {
        let types = state.serviceTypes ?? []
        if state.canChooseService == true, !types.isEmpty {
            Menu {
                ForEach(types) { type in
                    Button {
                        client.send(.chooseService(id: type.id))
                    } label: {
                        if type.id == state.selectedServiceTypeId { Label(type.name, systemImage: "checkmark") } else { Text(type.name) }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(title.uppercased()).font(IrisFont.overline).tracking(IrisTracking.caps)
                    Image(systemName: "chevron.down").font(.caption2)
                }
                .foregroundStyle(IrisColor.textPrimary)
            }
        } else {
            Text(title.uppercased()).font(IrisFont.overline).tracking(IrisTracking.caps)
        }
    }
}

/// No service chosen yet: the bar only offers to choose one.
struct NoServiceBar: View {
    let client: RemoteClient
    let state: RemoteState

    var body: some View {
        HStack {
            ServiceChooser(client: client, state: state, title: "Seleccionar servicio")
            Spacer()
            if (state.serviceTypes ?? []).isEmpty {
                Text("Crea los servicios en la computadora.")
                    .font(IrisFont.caption)
                    .foregroundStyle(IrisColor.textSecondary)
            }
        }
        .padding(IrisSpacing.md)
        .background(IrisColor.canvasElevated.opacity(0.72), in: RoundedRectangle(cornerRadius: IrisRadius.lg))
        .overlay(RoundedRectangle(cornerRadius: IrisRadius.lg).strokeBorder(IrisColor.stroke, lineWidth: 1))
    }
}

#Preview {
    ZStack {
        IrisBackground(isAnimated: false).ignoresSafeArea()
        TimerBar(client: RemoteClient(), service: DemoState.state.service!, state: DemoState.state, onLeader: { _ in }, onAddBlock: {}).padding()
    }
    .preferredColorScheme(.dark)
}
