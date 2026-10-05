//
//  StaticShowcaseContentProvider.swift
//  iris
//

import Foundation

/// Fixed sample verses and lyrics rotating on the sign-in screen (public-domain texts).
struct StaticShowcaseContentProvider: ShowcaseContentProvider {
    func items() -> [ShowcaseItem] {
        [
            ShowcaseItem(
                kind: .lyric,
                text: "Sublime gracia del Señor,\nque a un pecador salvó.",
                reference: "Sublime gracia · Estrofa 1"
            ),
            ShowcaseItem(
                kind: .verse,
                text: "Lámpara es a mis pies tu palabra,\ny lumbrera a mi camino.",
                reference: "Salmos 119:105"
            ),
            ShowcaseItem(
                kind: .lyric,
                text: "¡Santo, santo, santo!\nSeñor omnipotente.",
                reference: "Santo, santo, santo · Estrofa 1"
            ),
            ShowcaseItem(
                kind: .verse,
                text: "Venid a mí todos los que estáis trabajados y cargados,\ny yo os haré descansar.",
                reference: "Mateo 11:28"
            )
        ]
    }
}
