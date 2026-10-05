//
//  BlockTimerBar.swift
//  iris
//

import SwiftUI

/// Strip above the workspace that times the service's blocks: not started, running or finished.
struct BlockTimerBar: View {
    @Bindable var viewModel: LiveConsoleViewModel
    let onOpenTimes: () -> Void

    var body: some View {
        IrisSurface(padding: IrisSpacing.md, cornerRadius: IrisRadius.xl) {
            content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .confirmationDialog("¿Terminar el servicio?", isPresented: $viewModel.isConfirmingFinish, titleVisibility: .visible) {
            Button("Terminar", role: .destructive) {
                Task { await viewModel.finishService() }
            }
        } message: {
            Text("Se guardarán los tiempos de los bloques.")
        }
        .alert("Hoy hiciste cambios en los bloques", isPresented: $viewModel.isAskingTemplateUpdate) {
            Button("Solo hoy") {
                Task { await viewModel.saveRecord(updatingTemplate: false) }
            }
            Button("Guardar en la plantilla") {
                Task { await viewModel.saveRecord(updatingTemplate: true) }
            }
        } message: {
            Text(viewModel.templateChangesMessage)
        }
        .sheet(item: $viewModel.responsiblePicker) { picker in
            ResponsiblePickerView(viewModel: picker)
        }
        .sheet(item: $viewModel.addBlockSheet) { sheet in
            AddBlockView(viewModel: sheet)
        }
        .sheet(isPresented: $viewModel.isEditingPendingBlocks) {
            PendingBlocksEditorView(viewModel: viewModel)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.blockTimer?.phase {
        case .notStarted?:
            notStartedContent
        case .running?:
            runningContent
        case .finished?:
            finishedContent
        case nil:
            EmptyView()
        }
    }

    // MARK: Not started

    private var notStartedContent: some View {
        HStack(spacing: IrisSpacing.lg) {
            blocksOverview
            startButton
                .frame(width: 200)
        }
    }

    private var blocksOverview: some View {
        VStack(alignment: .leading, spacing: IrisSpacing.sm) {
            IrisSectionHeader("BLOQUES") {
                Text(viewModel.blocksSummaryText)
            }
            BlockTimeline(blocks: viewModel.plannedBlocks)
        }
    }

    private var startButton: some View {
        Button {
            viewModel.startBlocks()
        } label: {
            Label("Comenzar", systemImage: "play.fill")
        }
        .buttonStyle(.irisPrimary)
    }

    // MARK: Running

    private var runningContent: some View {
        VStack(alignment: .leading, spacing: IrisSpacing.sm) {
            HStack(spacing: IrisSpacing.md) {
                // Who is leading above how long it's taking, so both read in full even on
                // the narrowest console (iPad mini).
                VStack(alignment: .leading, spacing: IrisSpacing.xxs) {
                    currentLabel
                    clock
                        .fixedSize()
                }
                .layoutPriority(1)
                Spacer(minLength: IrisSpacing.xs)
                nextButton
                    .frame(width: 220)
                moreMenu
                finishButton
            }
            progressBar
            breadcrumbs
        }
    }

    private var finishButton: some View {
        Button("Terminar") { viewModel.requestFinish() }
            .buttonStyle(.irisPill)
    }

    private var currentLabel: some View {
        HStack(spacing: IrisSpacing.xs) {
            IrisLiveDot()
            Text(viewModel.currentBlock?.name ?? "")
                .font(IrisFont.overline)
                .tracking(IrisTracking.overline)
                .textCase(.uppercase)
                .foregroundStyle(IrisColor.textPrimary)
                .lineLimit(1)
            Text("·")
                .foregroundStyle(IrisColor.textTertiary)
            leaderMenu
        }
    }

    private var leaderMenu: some View {
        Menu {
            if let block = viewModel.currentBlock {
                Picker(selection: Binding(get: { block.personID }, set: { viewModel.setLeader($0, of: block.id) })) {
                    Text("Sin responsable").tag(Person.ID?.none)
                    ForEach(viewModel.people) { person in
                        Text(person.name).tag(Optional(person.id))
                    }
                } label: {
                    Text("Responsable")
                }
                .pickerStyle(.inline)
            }
        } label: {
            HStack(spacing: IrisSpacing.xxs) {
                leaderName
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(.caption2, weight: .bold))
            }
            .font(IrisFont.calloutEmphasized)
            .foregroundStyle(IrisColor.textSecondary)
        }
        .accessibilityLabel(Text("Responsable"))
    }

    @ViewBuilder
    private var leaderName: some View {
        if let name = viewModel.personName(viewModel.currentBlock?.personID) {
            Text(name)
        } else {
            Text("Sin responsable")
        }
    }

    private var clock: some View {
        HStack(alignment: .firstTextBaseline, spacing: IrisSpacing.xs) {
            Text(IrisDurationFormat.clock(viewModel.currentElapsed))
                .font(.system(.title2, design: .rounded, weight: .semibold).monospacedDigit())
                .foregroundStyle(clockColor)
                .contentTransition(.numericText())
            Text("/ \(IrisDurationFormat.clock(viewModel.currentBlock?.plannedSeconds ?? 0))")
                .font(.system(.callout, design: .rounded, weight: .medium).monospacedDigit())
                .foregroundStyle(IrisColor.textTertiary)
            Text(viewModel.currentDeltaText)
                .font(.system(.callout, design: .monospaced, weight: .semibold))
                .foregroundStyle(deltaColor)
                .padding(.horizontal, IrisSpacing.xs)
                .padding(.vertical, IrisSpacing.xxs)
                .background(deltaColor.opacity(0.14), in: Capsule())
        }
        .accessibilityElement(children: .combine)
    }

    private var nextButton: some View {
        Button {
            viewModel.goToNextBlock()
        } label: {
            if viewModel.isOnLastBlock {
                Text("Terminar")
            } else {
                HStack(spacing: IrisSpacing.xs) {
                    Text("Siguiente bloque")
                    Image(systemName: "arrow.right")
                }
            }
        }
        .buttonStyle(.irisPrimary)
    }

    private var moreMenu: some View {
        Menu {
            Button("Agregar bloque…", systemImage: "plus") {
                viewModel.presentAddBlock()
            }
            Button("Editar bloques pendientes…", systemImage: "pencil") {
                viewModel.presentPendingEditor()
            }
            .disabled(viewModel.pendingBlocks.isEmpty)
            Button("Omitir siguiente bloque", systemImage: "forward.end") {
                withAnimation(IrisMotion.smooth) { viewModel.skipNextBlock() }
            }
            .disabled(!viewModel.canSkipNextBlock)
        } label: {
            Image(systemName: "ellipsis")
        }
        .menuStyle(.button)
        .buttonStyle(.irisIcon)
        .accessibilityLabel(Text("Opciones de bloques"))
    }

    private var progressBar: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(IrisColor.surface)
                Capsule()
                    .fill(progressColor)
                    .frame(width: proxy.size.width * viewModel.currentProgress)
            }
        }
        .frame(height: 4)
        .animation(.linear(duration: 1), value: viewModel.currentProgress)
        .accessibilityHidden(true)
    }

    private var breadcrumbs: some View {
        ScrollView(.horizontal) {
            HStack(spacing: IrisSpacing.xs) {
                ForEach(Array(viewModel.breadcrumbs.enumerated()), id: \.element.id) { index, crumb in
                    if index > 0 {
                        Text("·")
                            .foregroundStyle(IrisColor.textTertiary)
                    }
                    BlockCrumbView(crumb: crumb)
                }
            }
            .font(IrisFont.caption)
        }
        .scrollIndicators(.hidden)
    }

    private var clockColor: Color {
        switch viewModel.currentClockState {
        case .normal: IrisColor.textPrimary
        case .warning: IrisColor.warning
        case .over: IrisColor.danger
        }
    }

    private var deltaColor: Color {
        switch viewModel.currentClockState {
        case .normal: IrisColor.textSecondary
        case .warning: IrisColor.warning
        case .over: IrisColor.danger
        }
    }

    private var progressColor: Color {
        switch viewModel.currentClockState {
        case .normal: IrisColor.success
        case .warning: IrisColor.warning
        case .over: IrisColor.danger
        }
    }

    // MARK: Finished

    private var finishedContent: some View {
        HStack(spacing: IrisSpacing.md) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(.title3, weight: .semibold))
                .foregroundStyle(IrisColor.success)

            Text(viewModel.finishedSummary ?? "")
                .font(IrisFont.calloutEmphasized)
                .foregroundStyle(IrisColor.textPrimary)

            Spacer(minLength: IrisSpacing.md)

            finishedTrailing
        }
        .frame(minHeight: IrisSize.iconButton)
    }

    @ViewBuilder
    private var finishedTrailing: some View {
        if let recordError = viewModel.recordError {
            Text(recordError)
                .font(IrisFont.caption)
                .foregroundStyle(IrisColor.danger)
            Button("Reintentar") {
                Task { await viewModel.retrySavingRecord() }
            }
            .buttonStyle(.irisPill)
        } else if viewModel.isRecordSaved {
            Button("Ver en Tiempos") { onOpenTimes() }
                .buttonStyle(.irisLink)
        } else {
            ProgressView()
                .tint(IrisColor.textSecondary)
        }
    }
}

/// "Bienvenida ✓ 9:40", "Prédica ●", "Anuncios" or a struck-through skipped block.
private struct BlockCrumbView: View {
    let crumb: LiveConsoleViewModel.BlockCrumb

    var body: some View {
        switch crumb.state {
        case let .done(isOver):
            HStack(spacing: IrisSpacing.xxs) {
                Text(crumb.name)
                Image(systemName: "checkmark")
                    .font(.system(.caption2, weight: .bold))
                if let time = crumb.time {
                    Text(time)
                        .monospacedDigit()
                }
            }
            .foregroundStyle(isOver ? IrisColor.danger : IrisColor.textSecondary)
        case .current:
            HStack(spacing: IrisSpacing.xxs) {
                Text(crumb.name)
                    .fontWeight(.semibold)
                Circle()
                    .fill(IrisColor.live)
                    .frame(width: 6, height: 6)
            }
            .foregroundStyle(IrisColor.textPrimary)
        case .pending:
            Text(crumb.name)
                .foregroundStyle(IrisColor.textTertiary)
        case .skipped:
            Text(crumb.name)
                .strikethrough()
                .foregroundStyle(IrisColor.textTertiary)
        }
    }
}

// MARK: - Previews

extension LiveConsoleViewModel {
    /// Culto general with its four blocks, the timer in the given state.
    static func blockTimerPreview(_ phase: BlockTimer.Phase) -> LiveConsoleViewModel {
        let store = InMemoryChurchStore()
        let viewModel = makePreview(
            modules: ChurchModules(),
            serviceType: store.serviceTypes.first,
            people: store.people
        )
        guard let culto = store.serviceTypes.first else { return viewModel }
        let start = Date.now.addingTimeInterval(-40 * 60)
        var timer = BlockTimer(template: culto.blocks)
        switch phase {
        case .notStarted:
            break
        case .running:
            timer.start(personID: culto.blocks[0].defaultPersonID, at: start)
            timer.advance(nextPersonID: culto.blocks[1].defaultPersonID, at: start.addingTimeInterval(9 * 60 + 40))
            timer.advance(nextPersonID: culto.blocks[2].defaultPersonID, at: start.addingTimeInterval(28 * 60 + 45))
        case .finished:
            timer.start(personID: culto.blocks[0].defaultPersonID, at: start)
            timer.advance(nextPersonID: culto.blocks[1].defaultPersonID, at: start.addingTimeInterval(9 * 60 + 40))
            timer.advance(nextPersonID: culto.blocks[2].defaultPersonID, at: start.addingTimeInterval(28 * 60 + 45))
            timer.advance(nextPersonID: culto.blocks[3].defaultPersonID, at: start.addingTimeInterval(80 * 60 + 15))
            timer.finish(at: start.addingTimeInterval(86 * 60 + 10))
        }
        viewModel.apply(blockTimer: timer, now: .now)
        return viewModel
    }
}

#Preview("Sin empezar") {
    BlockTimerBar(viewModel: .blockTimerPreview(.notStarted), onOpenTimes: {})
        .padding(IrisSpacing.lg)
        .frame(width: 1_000)
        .background(IrisColor.canvas)
        .preferredColorScheme(.dark)
        .environment(\.locale, Locale(identifier: "es"))
}

#Preview("En curso") {
    BlockTimerBar(viewModel: .blockTimerPreview(.running), onOpenTimes: {})
        .padding(IrisSpacing.lg)
        .frame(width: 1_000)
        .background(IrisColor.canvas)
        .preferredColorScheme(.dark)
        .environment(\.locale, Locale(identifier: "es"))
}

#Preview("Terminado") {
    BlockTimerBar(viewModel: .blockTimerPreview(.finished), onOpenTimes: {})
        .padding(IrisSpacing.lg)
        .frame(width: 1_000)
        .background(IrisColor.canvas)
        .preferredColorScheme(.dark)
        .environment(\.locale, Locale(identifier: "es"))
}
