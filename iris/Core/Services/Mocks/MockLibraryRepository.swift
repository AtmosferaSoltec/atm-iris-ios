//
//  MockLibraryRepository.swift
//  iris
//

import Foundation

struct MockLibraryRepository: LibraryRepository {
    var latency: Duration = .milliseconds(300)

    func lyrics() async throws -> [LyricSheet] {
        try await Task.sleep(for: latency)
        return Self.sampleLyrics
    }

    func media(of kind: MediaAsset.Kind) async throws -> [MediaAsset] {
        try await Task.sleep(for: latency)
        return Self.sampleMedia.filter { $0.kind == kind }
    }

    func localMusic() async -> [MediaAsset] {
        try? await Task.sleep(for: latency)
        return Self.sampleMedia.filter { $0.kind == .music }
    }

    // MARK: Sample data (public-domain hymn texts)

    static let sampleLyrics: [LyricSheet] = [
        LyricSheet(title: "Oh, qué amigo nos es Cristo", author: "Joseph M. Scriven", sections: [
            Slide(label: "Estrofa 1", content: .text("¡Oh, qué amigo nos es Cristo!\nÉl llevó nuestro dolor,\ny nos manda que llevemos\ntodo a Dios en oración.", footnote: nil))
        ]),
        LyricSheet(title: "Roca de la eternidad", author: "Augustus M. Toplady", sections: [
            Slide(label: "Estrofa 1", content: .text("Roca de la eternidad,\nfuiste abierta tú por mí;\nsé mi escondedero fiel,\nsolo encuentro paz en ti.", footnote: nil))
        ]),
        LyricSheet(title: "Cariñoso Salvador", author: "Charles Wesley", sections: [
            Slide(label: "Estrofa 1", content: .text("Cariñoso Salvador,\nhuyo de la tempestad\na tu seno protector,\nfiándome de tu bondad.", footnote: nil))
        ]),
        LyricSheet(title: "Sublime gracia", author: "John Newton", sections: [
            Slide(label: "Estrofa 1", content: .text("Sublime gracia del Señor\nque a un pecador salvó;\nfui ciego mas hoy veo yo,\nperdido y Él me halló.", footnote: nil)),
            Slide(label: "Estrofa 2", content: .text("Su gracia me enseñó a temer,\nmis dudas ahuyentó;\n¡oh cuán precioso fue a mi ser\ncuando Él me transformó!", footnote: nil))
        ]),
        LyricSheet(title: "Santo, santo, santo", author: "Reginald Heber", sections: [
            Slide(label: "Estrofa 1", content: .text("¡Santo, santo, santo! Señor omnipotente,\nsiempre el labio mío loores te dará;\n¡Santo, santo, santo! te adoro reverente,\nDios en tres personas, bendita Trinidad.", footnote: nil))
        ]),
        LyricSheet(title: "Castillo fuerte", author: "Martín Lutero", sections: [
            Slide(content: .text("Castillo fuerte es nuestro Dios,\ndefensa y buen escudo;\ncon su poder nos librará\nen este trance agudo.", footnote: nil))
        ])
    ]

    static let sampleMedia: [MediaAsset] = [
        // Music
        MediaAsset(id: "m1", kind: .music, title: "Piano de fondo", subtitle: "Ambiente para oración", duration: "6:12", artwork: [0x0F2417, 0x2F5233]),
        MediaAsset(id: "m2", kind: .music, title: "Preludio en Re", subtitle: "Órgano", duration: "3:40", artwork: [0x3A1E08, 0x8C3A1E]),
        MediaAsset(id: "m3", kind: .music, title: "Ofrenda · Guitarra acústica", subtitle: "Banda de alabanza", duration: "4:05", artwork: [0x06283D, 0x0E5E6F]),
        MediaAsset(id: "m4", kind: .music, title: "Pads de adoración en Sol", subtitle: "Ambiente", duration: "10:00", artwork: [0x2A1658, 0x4E2A8C]),
        MediaAsset(id: "m5", kind: .music, title: "Sublime gracia (instrumental)", subtitle: "Pista", duration: "4:32", artwork: [0x5B2A3C, 0xC0694E]),
        // Images
        MediaAsset(id: "i1", kind: .image, title: "Logo de la iglesia", subtitle: "PNG · 1920 × 1080", duration: nil, artwork: [0x07070B, 0x2A1658, 0x07070B]),
        MediaAsset(id: "i2", kind: .image, title: "Bienvenida", subtitle: "JPG · 1920 × 1080", duration: nil, artwork: [0x5B2A3C, 0xC0694E, 0x2B1A3A]),
        MediaAsset(id: "i3", kind: .image, title: "Santa Cena", subtitle: "JPG · 1920 × 1080", duration: nil, artwork: [0x3A1E08, 0x8C3A1E, 0x3D1235]),
        MediaAsset(id: "i4", kind: .image, title: "Bautismos", subtitle: "JPG · 1920 × 1080", duration: nil, artwork: [0x06283D, 0x0E5E6F, 0x0A1931]),
        MediaAsset(id: "i5", kind: .image, title: "Jóvenes", subtitle: "JPG · 1920 × 1080", duration: nil, artwork: [0x2A1658, 0xF0508C, 0x131E5C]),
        MediaAsset(id: "i6", kind: .image, title: "Misiones", subtitle: "JPG · 1920 × 1080", duration: nil, artwork: [0x0F2417, 0x2F5233, 0x111A12]),
        // Videos
        MediaAsset(id: "v1", kind: .video, title: "Testimonios de bautismo", subtitle: "MP4 · 1080p", duration: "2:45", artwork: [0x06283D, 0x0E5E6F, 0x0A1931]),
        MediaAsset(id: "v2", kind: .video, title: "Cuenta regresiva", subtitle: "MP4 · 1080p", duration: "5:00", artwork: [0x07070B, 0x4E2A8C, 0x07070B]),
        MediaAsset(id: "v3", kind: .video, title: "Anuncios de octubre", subtitle: "MP4 · 1080p", duration: "1:30", artwork: [0x131E5C, 0x4E5BFF, 0x07070B]),
        MediaAsset(id: "v4", kind: .video, title: "Misión en Oaxaca", subtitle: "MP4 · 4K", duration: "4:12", artwork: [0x3A1E08, 0xFFB547, 0x3D1235]),
        MediaAsset(id: "v5", kind: .video, title: "Video de bienvenida", subtitle: "MP4 · 1080p", duration: "0:45", artwork: [0x5B2A3C, 0xF0508C, 0x2B1A3A])
    ]
}
