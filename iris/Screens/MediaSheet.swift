//
//  MediaSheet.swift
//  iris
//

import SwiftUI

/// The computer's images and videos: tap one and it goes to the screens, without joining the service.
/// Each shows the computer's still (kept in memory only); a video never plays here.
struct MediaSheet: View {
    let client: RemoteClient
    let state: RemoteState

    @Environment(\.dismiss) private var dismiss
    @State private var search = ""

    private var entries: [RemoteState.LibraryEntry] {
        let all = state.library ?? []
        let query = search.trimmingCharacters(in: .whitespaces)
        return query.isEmpty ? all : all.filter { $0.title.localizedStandardContains(query) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: IrisSpacing.md) {
            SheetHeader("Multimedia") { EmptyView() }
            TextField("Buscar imagen o video", text: $search)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 360)
            if (state.library ?? []).isEmpty {
                Text("No hay imágenes ni videos en la computadora. Agrégalos en Iris, en Multimedia.")
                    .font(IrisFont.callout)
                    .foregroundStyle(IrisColor.textSecondary)
            }
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: IrisSpacing.sm), count: 4), spacing: IrisSpacing.sm) {
                    ForEach(entries) { entry in
                        Button {
                            client.send(.presentMedia(id: entry.id))
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: IrisSpacing.xs) {
                                RoundedRectangle(cornerRadius: IrisRadius.sm)
                                    .fill(IrisColor.surface)
                                    .aspectRatio(16.0 / 9.0, contentMode: .fit)
                                    .overlay {
                                        Image(systemName: entry.kind == .video ? "play.rectangle.fill" : "photo.fill")
                                            .font(.title)
                                            .foregroundStyle(entry.kind == .video ? IrisColor.coral : IrisColor.violet)
                                    }
                                    .overlay { RemoteThumbnail(client: client, id: entry.id) }
                                    .clipShape(RoundedRectangle(cornerRadius: IrisRadius.sm))
                                    .overlay(alignment: .bottomLeading) {
                                        if entry.kind == .video { VideoBadge(seconds: entry.durationSeconds) }
                                    }
                                    .overlay(RoundedRectangle(cornerRadius: IrisRadius.sm).strokeBorder(IrisColor.stroke, lineWidth: 1))
                                Text(entry.title).font(IrisFont.caption).lineLimit(1)
                            }
                        }
                        .buttonStyle(.irisPressable)
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
        .padding(IrisSpacing.lg)
        .frame(minWidth: 720, minHeight: 520)
    }
}
