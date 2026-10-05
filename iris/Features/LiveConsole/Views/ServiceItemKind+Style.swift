//
//  ServiceItemKind+Style.swift
//  iris
//

import SwiftUI

/// Visual identity for each kind of service item.
extension ServiceItem.Kind {
    var displayName: LocalizedStringKey {
        switch self {
        case .song: "Letra"
        case .scripture: "Pasaje"
        case .announcement: "Anuncio"
        case .music: "Música"
        case .image: "Imagen"
        case .video: "Video"
        }
    }

    var systemImage: String {
        switch self {
        case .song: "text.quote"
        case .scripture: "book.closed.fill"
        case .announcement: "megaphone.fill"
        case .music: "music.note"
        case .image: "photo.fill"
        case .video: "play.rectangle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .song: IrisColor.ember
        case .scripture: IrisColor.violet
        case .announcement: IrisColor.indigo
        case .music: IrisColor.success
        case .image: IrisColor.coral
        case .video: IrisColor.rose
        }
    }
}
