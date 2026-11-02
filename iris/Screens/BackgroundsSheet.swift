//
//  BackgroundsSheet.swift
//  iris
//

import SwiftUI

/// Choose the background shown behind the lyrics. Images and videos show the computer's still (a video never
/// plays here) with a film badge.
struct BackgroundsSheet: View {
    let client: RemoteClient
    let state: RemoteState

    @Environment(\.dismiss) private var dismiss

    private let columns = Array(repeating: GridItem(.flexible(), spacing: IrisSpacing.sm), count: 4)

    var body: some View {
        VStack(alignment: .leading, spacing: IrisSpacing.md) {
            SheetHeader("Fondos") { EmptyView() }

            if state.backgrounds.isEmpty {
                Text("No hay fondos en la computadora. Agrégalos en Iris, en Multimedia → Fondos.")
                    .font(IrisFont.callout)
                    .foregroundStyle(IrisColor.textSecondary)
            }

            ScrollView {
                LazyVGrid(columns: columns, spacing: IrisSpacing.sm) {
                    swatch(name: "Sin fondo", colors: [.black], background: nil, isSelected: state.backgroundId == nil) {
                        client.send(.setBackground(id: nil))
                    }
                    ForEach(state.backgrounds) { background in
                        swatch(
                            name: background.name,
                            colors: background.colors.map(Color.init(cssHex:)),
                            background: background,
                            isSelected: state.backgroundId == background.id
                        ) { client.send(.setBackground(id: background.id)) }
                    }
                }
            }
            .scrollIndicators(.hidden)

            HStack {
                Spacer()
                Button { dismiss() } label: { Text("Listo").padding(.horizontal, IrisSpacing.lg) }
                    .buttonStyle(.irisPrimary)
                    .fixedSize()
            }
        }
        .padding(IrisSpacing.lg)
        .frame(minWidth: 640)
    }

    private func swatch(name: String, colors: [Color], background: RemoteBackground?, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: IrisSpacing.xs) {
                RoundedRectangle(cornerRadius: IrisRadius.sm)
                    .fill(LinearGradient(colors: colors.count > 1 ? colors : colors + colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                    .aspectRatio(16.0 / 9.0, contentMode: .fit)
                    .overlay { RemoteThumbnail(client: client, id: background?.thumbnailId) }
                    .clipShape(RoundedRectangle(cornerRadius: IrisRadius.sm))
                    .overlay(alignment: .bottomLeading) {
                        if background?.isVideo == true { VideoBadge() }
                    }
                    .overlay(alignment: .topTrailing) {
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(IrisColor.coral, .white)
                                .padding(IrisSpacing.xs)
                        }
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: IrisRadius.sm)
                            .strokeBorder(isSelected ? IrisColor.coral : IrisColor.stroke, lineWidth: isSelected ? 2 : 1)
                    )
                Text(name).font(IrisFont.caption).lineLimit(1)
            }
        }
        .buttonStyle(.irisPressable)
    }
}
