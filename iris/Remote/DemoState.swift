//
//  DemoState.swift
//  iris
//

import Foundation

/// Sample content for previews and screenshots (launch argument `-demo`). Never shown to a real user.
enum DemoState {
    private static func slides(_ labelled: [(String, String)]) -> [RemoteSlide] {
        labelled.map { RemoteSlide(label: $0.0, text: $0.1) }
    }

    static let state = RemoteState(
        churchName: "Iglesia Esperanza",
        items: [
            RemoteItem(
                id: "1", kind: .song, title: "Cuando Él venga", subtitle: "Coro Esperanza",
                slides: slides([
                    ("Estrofa 1", "Cuando Él venga en gloria\nlos cielos se abrirán,\ny toda lengua dirá:\nSanto, santo es el Señor."),
                    ("Coro", "Aleluya, aleluya,\nhoy cantamos para Ti,\nen tu presencia hay vida,\naleluya, aleluya."),
                    ("Estrofa 2", "Cada rodilla se doblará\nante tu majestad,\ny el mundo entero sabrá\nque Tú reinas para siempre."),
                    ("Puente", "Santo, santo, santo,\ndigno es el Cordero.")
                ]),
                isPlayable: true, backgroundId: nil
            ),
            RemoteItem(
                id: "2", kind: .song, title: "Tu luz nos guía", subtitle: "Coro Esperanza",
                slides: slides([
                    ("Estrofa 1", "Tu luz nos guía en la mañana,\ncamina junto a mí."),
                    ("Coro", "Eres fuego que renueva,\neres paz en la tormenta."),
                    ("Final", "Camina junto a mí.")
                ]),
                isPlayable: true, backgroundId: nil
            ),
            RemoteItem(
                id: "3", kind: .bible, title: "Salmos 96:1-4", subtitle: "Reina Valera 1960",
                slides: slides([
                    ("Versículo 1", "Cantad a Jehová cántico nuevo; cantad a Jehová, toda la tierra."),
                    ("Versículo 2", "Cantad a Jehová, bendecid su nombre; anunciad de día en día su salvación.")
                ]),
                isPlayable: false, backgroundId: nil
            ),
            RemoteItem(
                id: "4", kind: .image, title: "Anuncios de la semana", subtitle: nil,
                slides: slides([("Imagen", "Anuncios de la semana")]),
                isPlayable: false, backgroundId: nil
            )
        ],
        openId: "2",
        live: .init(id: "2", slide: 0),
        isCleared: false,
        playback: .init(
            id: "2", kind: .track, title: "Tu luz nos guía", isPlaying: false,
            position: 64, duration: 228, isLooping: false, hasError: false
        ),
        volume: 0.7,
        backgroundId: "1",
        backgrounds: [
            RemoteBackground(id: "1", name: "Atardecer", colors: ["#3A1E08", "#B5462E", "#F0508C"]),
            RemoteBackground(id: "2", name: "Aurora", colors: ["#131E5C", "#9B5CFF", "#F0508C"]),
            RemoteBackground(id: "3", name: "Noche", colors: ["#07070B", "#131E5C"]),
            RemoteBackground(id: "4", name: "Océano", colors: ["#0B2A4A", "#2E7DAF", "#6FD3C4"])
        ],
        sounds: [
            RemoteSound(id: "1", title: "Aplausos"),
            RemoteSound(id: "2", title: "Campana"),
            RemoteSound(id: "3", title: "Fiesta")
        ],
        countdown: nil,
        service: .init(
            name: "Culto de domingo",
            phase: .running,
            blocks: [
                .init(name: "Bienvenida", plannedSeconds: 300, status: .done, leader: "Pastor Daniel"),
                .init(name: "Alabanza", plannedSeconds: 1_200, status: .current, leader: "Coro Esperanza"),
                .init(name: "Palabra", plannedSeconds: 2_400, status: .pending, leader: nil),
                .init(name: "Ofrenda", plannedSeconds: 480, status: .pending, leader: nil)
            ],
            elapsedSeconds: 760,
            canAdvance: true
        )
    )
}

extension TimeInterval {
    /// "12:40".
    var clock: String {
        let total = max(0, Int(self))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
