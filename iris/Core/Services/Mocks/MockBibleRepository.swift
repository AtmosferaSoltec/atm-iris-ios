//
//  MockBibleRepository.swift
//  iris
//

import Foundation

/// Full book/chapter index with real Reina-Valera 1909 text for a few
/// well-known chapters and placeholder text elsewhere.
struct MockBibleRepository: BibleRepository {
    let translationName = "Reina-Valera 1909"

    func books() async throws -> [BibleBook] {
        Self.allBooks
    }

    func verseCount(bookID: BibleBook.ID, chapter: Int) async throws -> Int {
        if let known = Self.knownChapters[Self.key(bookID, chapter)] {
            return known.count
        }
        // Deterministic stand-in until real data exists.
        let seed = bookID.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return 18 + (seed + chapter * 7) % 20
    }

    func verses(bookID: BibleBook.ID, chapter: Int) async throws -> [BibleVerse] {
        let count = try await verseCount(bookID: bookID, chapter: chapter)
        let known = Self.knownChapters[Self.key(bookID, chapter)] ?? [:]
        let name = Self.allBooks.first { $0.id == bookID }?.name ?? bookID
        return (1...count).map { number in
            BibleVerse(
                number: number,
                text: known[number] ?? "Texto de ejemplo de \(name) \(chapter):\(number)."
            )
        }
    }

    // MARK: Data

    private static func key(_ bookID: String, _ chapter: Int) -> String { "\(bookID).\(chapter)" }

    /// Real text keyed by "book.chapter" → verse number. A chapter's dictionary
    /// also defines its verse count via `count` when complete.
    private static let knownChapters: [String: [Int: String]] = [
        "sal.23": [
            1: "Jehová es mi pastor; nada me faltará.",
            2: "En lugares de delicados pastos me hará yacer: junto a aguas de reposo me pastoreará.",
            3: "Confortará mi alma; guiárame por sendas de justicia por amor de su nombre.",
            4: "Aunque ande en valle de sombra de muerte, no temeré mal alguno; porque tú estarás conmigo: tu vara y tu cayado me infundirán aliento.",
            5: "Aderezarás mesa delante de mí, en presencia de mis angustiadores: ungiste mi cabeza con aceite: mi copa está rebosando.",
            6: "Ciertamente el bien y la misericordia me seguirán todos los días de mi vida: y en la casa de Jehová moraré por largos días."
        ],
        "jn.1": Dictionary(uniqueKeysWithValues: (1...51).map { ($0, johnOne[$0] ?? "Texto de ejemplo de Juan 1:\($0).") }),
        "jn.3": Dictionary(uniqueKeysWithValues: (1...36).map { ($0, johnThree[$0] ?? "Texto de ejemplo de Juan 3:\($0).") }),
        "gn.1": Dictionary(uniqueKeysWithValues: (1...31).map { ($0, genesisOne[$0] ?? "Texto de ejemplo de Génesis 1:\($0).") })
    ]

    private static let johnOne: [Int: String] = [
        1: "En el principio era el Verbo, y el Verbo era con Dios, y el Verbo era Dios.",
        2: "Este era en el principio con Dios.",
        3: "Todas las cosas por él fueron hechas; y sin él nada de lo que es hecho, fue hecho.",
        4: "En él estaba la vida, y la vida era la luz de los hombres.",
        5: "Y la luz en las tinieblas resplandece; mas las tinieblas no la comprendieron."
    ]

    private static let johnThree: [Int: String] = [
        16: "Porque de tal manera amó Dios al mundo, que ha dado a su Hijo unigénito, para que todo aquel que en él cree, no se pierda, mas tenga vida eterna.",
        17: "Porque no envió Dios a su Hijo al mundo, para que condene al mundo, mas para que el mundo sea salvo por él."
    ]

    private static let genesisOne: [Int: String] = [
        1: "En el principio crió Dios los cielos y la tierra.",
        2: "Y la tierra estaba desordenada y vacía, y las tinieblas estaban sobre la haz del abismo, y el Espíritu de Dios se movía sobre la haz de las aguas.",
        3: "Y dijo Dios: Sea la luz: y fue la luz."
    ]

    static let allBooks: [BibleBook] = {
        let old: [(String, String, Int)] = [
            ("gn", "Génesis", 50), ("ex", "Éxodo", 40), ("lv", "Levítico", 27), ("nm", "Números", 36),
            ("dt", "Deuteronomio", 34), ("jos", "Josué", 24), ("jue", "Jueces", 21), ("rt", "Rut", 4),
            ("1s", "1 Samuel", 31), ("2s", "2 Samuel", 24), ("1r", "1 Reyes", 22), ("2r", "2 Reyes", 25),
            ("1cr", "1 Crónicas", 29), ("2cr", "2 Crónicas", 36), ("esd", "Esdras", 10), ("neh", "Nehemías", 13),
            ("est", "Ester", 10), ("job", "Job", 42), ("sal", "Salmos", 150), ("pr", "Proverbios", 31),
            ("ec", "Eclesiastés", 12), ("cnt", "Cantares", 8), ("is", "Isaías", 66), ("jer", "Jeremías", 52),
            ("lm", "Lamentaciones", 5), ("ez", "Ezequiel", 48), ("dn", "Daniel", 12), ("os", "Oseas", 14),
            ("jl", "Joel", 3), ("am", "Amós", 9), ("abd", "Abdías", 1), ("jon", "Jonás", 4),
            ("mi", "Miqueas", 7), ("nah", "Nahúm", 3), ("hab", "Habacuc", 3), ("sof", "Sofonías", 3),
            ("hag", "Hageo", 2), ("zac", "Zacarías", 14), ("mal", "Malaquías", 4)
        ]
        let new: [(String, String, Int)] = [
            ("mt", "Mateo", 28), ("mr", "Marcos", 16), ("lc", "Lucas", 24), ("jn", "Juan", 21),
            ("hch", "Hechos", 28), ("ro", "Romanos", 16), ("1co", "1 Corintios", 16), ("2co", "2 Corintios", 13),
            ("ga", "Gálatas", 6), ("ef", "Efesios", 6), ("flp", "Filipenses", 4), ("col", "Colosenses", 4),
            ("1ts", "1 Tesalonicenses", 5), ("2ts", "2 Tesalonicenses", 3), ("1ti", "1 Timoteo", 6), ("2ti", "2 Timoteo", 4),
            ("tit", "Tito", 3), ("flm", "Filemón", 1), ("he", "Hebreos", 13), ("stg", "Santiago", 5),
            ("1p", "1 Pedro", 5), ("2p", "2 Pedro", 3), ("1jn", "1 Juan", 5), ("2jn", "2 Juan", 1),
            ("3jn", "3 Juan", 1), ("jud", "Judas", 1), ("ap", "Apocalipsis", 22)
        ]
        return old.map { BibleBook(id: $0.0, name: $0.1, testament: .old, chapterCount: $0.2) }
            + new.map { BibleBook(id: $0.0, name: $0.1, testament: .new, chapterCount: $0.2) }
    }()
}
