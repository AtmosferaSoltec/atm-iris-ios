//
//  SyncIndicatorView.swift
//  iris
//

import SwiftUI

/// Discreet sync state next to the TV status. Tapping it opens the detail and "Actualizar ahora".
struct SyncIndicatorView: View {
    let sync: any SyncService

    @State private var isShowingDetail = false

    var body: some View {
        TimelineView(.everyMinute) { context in
            let model = SyncIndicatorModel(status: sync.status, pendingCount: sync.pendingCount, now: context.date)
            Button {
                isShowingDetail = true
            } label: {
                label(model)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $isShowingDetail) {
                SyncDetailView(sync: sync, model: model)
            }
            .accessibilityLabel(Text(model.title))
        }
    }

    private func label(_ model: SyncIndicatorModel) -> some View {
        HStack(spacing: IrisSpacing.xs) {
            icon(model.tone)
            Text(model.title)
                .font(IrisFont.label)
                .foregroundStyle(model.tone == .neutral ? IrisColor.textSecondary : tint(model.tone))
                .lineLimit(1)
        }
        .padding(.horizontal, IrisSpacing.md - 2)
        .frame(height: 46)
        .glassEffect(.regular, in: .capsule)
    }

    @ViewBuilder
    private func icon(_ tone: SyncIndicatorModel.Tone) -> some View {
        if tone == .busy {
            ProgressView()
                .controlSize(.small)
                .tint(IrisColor.textSecondary)
        } else {
            Image(systemName: symbol(tone))
                .font(.system(.callout, weight: .semibold))
                .foregroundStyle(tint(tone))
        }
    }

    private func symbol(_ tone: SyncIndicatorModel.Tone) -> String {
        switch tone {
        case .neutral, .busy: "checkmark.icloud"
        case .warning: "icloud.slash"
        case .error: "exclamationmark.icloud"
        }
    }

    private func tint(_ tone: SyncIndicatorModel.Tone) -> Color {
        switch tone {
        case .neutral, .busy: IrisColor.success
        case .warning: IrisColor.warning
        case .error: IrisColor.danger
        }
    }
}

/// Popover with the sync detail, warnings and the manual refresh.
struct SyncDetailView: View {
    let sync: any SyncService
    let model: SyncIndicatorModel

    var body: some View {
        VStack(alignment: .leading, spacing: IrisSpacing.md) {
            VStack(alignment: .leading, spacing: IrisSpacing.xxs) {
                Text(model.title)
                    .font(IrisFont.bodyEmphasized)
                    .foregroundStyle(IrisColor.textPrimary)
                Text(model.detail)
                    .font(IrisFont.callout)
                    .foregroundStyle(IrisColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let notice = sync.notice {
                IrisBanner(style: .error, message: notice)
            }
            if let warning = sync.storageWarning {
                IrisBanner(style: .info, message: warning)
            }

            Button {
                Task { await sync.syncNow(reason: .manual) }
            } label: {
                Label("Actualizar ahora", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.irisGlass)
            .disabled(sync.status == .syncing)
        }
        .padding(IrisSpacing.lg)
        .frame(width: 340, alignment: .leading)
        .presentationBackground(IrisColor.canvasElevated)
        .onDisappear { sync.dismissNotice() }
    }
}

#Preview("Indicador") {
    VStack(spacing: IrisSpacing.md) {
        SyncIndicatorView(sync: MockSyncService(status: .idle(lastSync: .now.addingTimeInterval(-120))))
        SyncIndicatorView(sync: MockSyncService(status: .syncing))
        SyncIndicatorView(sync: MockSyncService(status: .offline(pending: 3), pendingCount: 3))
        SyncIndicatorView(sync: MockSyncService(status: .failed(message: "Algo salió mal. Inténtalo de nuevo.")))
    }
    .padding()
    .background(IrisColor.canvas)
    .preferredColorScheme(.dark)
}
