//
//  SlideGrid.swift
//  iris
//

import SwiftUI

/// Every slide of the selected item as a plain card, in any order: tap one and it goes to the screen.
struct SlideGrid: View {
    let client: RemoteClient
    let item: RemoteItem
    let selectedSlide: Int?
    let onSelect: (Int) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: IrisSpacing.sm), count: 3)

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                Group {
                    if item.slides.isEmpty, item.kind == .image || item.kind == .video {
                        mediaCard
                    } else {
                        LazyVGrid(columns: columns, spacing: IrisSpacing.sm) {
                            ForEach(item.numberedSlides) { slide in
                                card(slide).id(slide.index)
                            }
                        }
                    }
                }
                .padding(.bottom, IrisSpacing.md)
            }
            .scrollIndicators(.hidden)
            // A passage opens on its verse, not on verse 1; and the live slide never hides below the fold.
            .onAppear { reveal(selectedSlide, with: proxy) }
            .onChange(of: selectedSlide) { _, slide in reveal(slide, with: proxy) }
            .onChange(of: item.id) { _, _ in reveal(selectedSlide, with: proxy) }
        }
    }

    /// An image or a video is one picture (the computer's still): tap it and it goes to the screens.
    private var mediaCard: some View {
        let isLive = selectedSlide == 0
        return Button {
            onSelect(0)
        } label: {
            RoundedRectangle(cornerRadius: IrisRadius.md)
                .fill(.black)
                .aspectRatio(16.0 / 9.0, contentMode: .fit)
                .overlay {
                    Image(systemName: item.kind.systemImage).font(.largeTitle).foregroundStyle(IrisColor.textSecondary)
                }
                .overlay { RemoteThumbnail(client: client, id: item.thumbnailId) }
                .clipShape(RoundedRectangle(cornerRadius: IrisRadius.md))
                .overlay(alignment: .bottomLeading) {
                    if item.kind == .video { VideoBadge() }
                }
                .overlay(alignment: .topTrailing) {
                    if isLive { IrisLiveDot().padding(IrisSpacing.sm) }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: IrisRadius.md)
                        .strokeBorder(isLive ? IrisColor.coral : IrisColor.stroke, lineWidth: isLive ? 3 : 1)
                )
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.irisPressable)
        .accessibilityLabel("Enviar a la pantalla: \(item.title)")
    }

    private func reveal(_ slide: Int?, with proxy: ScrollViewProxy) {
        guard let slide else { return }
        withAnimation(IrisMotion.smooth) { proxy.scrollTo(slide, anchor: .center) }
    }

    private func card(_ slide: NumberedSlide) -> some View {
        let isLive = slide.index == selectedSlide
        return Button {
            onSelect(slide.index)
        } label: {
            VStack(alignment: .leading, spacing: IrisSpacing.xs) {
                HStack {
                    Text(slide.label.map { "\(slide.index + 1) · \($0)" } ?? "\(slide.index + 1)")
                        .font(IrisFont.caption)
                        .foregroundStyle(IrisColor.textSecondary)
                    Spacer(minLength: 0)
                    if isLive { IrisLiveDot() }
                }
                Text(slide.text)
                    .font(IrisFont.callout)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)
                    .lineLimit(6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer(minLength: 0)
            }
            .padding(IrisSpacing.sm)
            .frame(maxWidth: .infinity, minHeight: 124, alignment: .topLeading)
            .background(.black, in: RoundedRectangle(cornerRadius: IrisRadius.sm))
            .overlay(
                RoundedRectangle(cornerRadius: IrisRadius.sm)
                    .strokeBorder(isLive ? IrisColor.coral : IrisColor.stroke, lineWidth: isLive ? 2 : 1)
            )
        }
        .buttonStyle(.irisPressable)
    }
}
