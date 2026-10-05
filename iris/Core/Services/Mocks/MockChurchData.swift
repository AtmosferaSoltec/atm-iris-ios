//
//  MockChurchData.swift
//  iris
//

import Foundation

/// Sample church data: seeds `InMemoryChurchStore` and feeds previews.
enum MockChurchData {
    static let people: [Person] = [
        Person(name: "Daniel Ruiz"), Person(name: "Ana Torres"), Person(name: "Carlos Pérez"),
        Person(name: "Lucía Gómez"), Person(name: "Marta Rivas"), Person(name: "José Herrera"),
        Person(name: "Sofía Méndez"), Person(name: "Pablo Castro")
    ]

    private static func person(_ name: String) -> Person.ID? {
        people.first { $0.name == name }?.id
    }

    static let serviceTypes: [ServiceType] = [
        ServiceType(
            name: "Culto general",
            color: 0xFFB547,
            schedule: .init(weekday: 1, hour: 10, minute: 0),
            blocks: [
                BlockTemplate(name: "Bienvenida", plannedMinutes: 10, defaultPersonID: person("Carlos Pérez")),
                BlockTemplate(name: "Alabanzas", plannedMinutes: 15, defaultPersonID: person("Ana Torres")),
                BlockTemplate(name: "Prédica", plannedMinutes: 40, defaultPersonID: person("Daniel Ruiz")),
                BlockTemplate(name: "Anuncios", plannedMinutes: 5, defaultPersonID: person("Lucía Gómez"))
            ]
        ),
        ServiceType(name: "Jóvenes", color: 0xF0508C, schedule: .init(weekday: 7, hour: 19, minute: 0)),
        ServiceType(name: "ABC", color: 0x9B5CFF, schedule: .init(weekday: 1, hour: 9, minute: 0))
    ]

    /// Last ten Sundays of the Culto general, with a skipped and an adjusted block.
    static let records: [ServiceRecord] = {
        guard let culto = serviceTypes.first else { return [] }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)

        /// Who led a block and how long it took; `nil` person with `.skipped` for an omitted block.
        struct Sample {
            let person: String?
            let minutes: Int
            let seconds: Int
            var status: BlockRecord.Status = .completed
        }

        func lead(_ person: String, _ minutes: Int, _ seconds: Int, _ status: BlockRecord.Status = .completed) -> Sample {
            Sample(person: person, minutes: minutes, seconds: seconds, status: status)
        }

        let skipped = Sample(person: nil, minutes: 0, seconds: 0, status: .skipped)

        func record(weeksAgo: Int, _ samples: [Sample]) -> ServiceRecord {
            let date = calendar.date(byAdding: .day, value: -7 * weeksAgo, to: today) ?? today
            let blocks = zip(culto.blocks, samples).map { template, sample in
                BlockRecord(
                    name: template.name,
                    plannedSeconds: template.plannedSeconds,
                    actualSeconds: TimeInterval(sample.minutes * 60 + sample.seconds),
                    personID: sample.person.flatMap { person($0) },
                    personName: sample.person,
                    status: sample.status
                )
            }
            return ServiceRecord(date: date, serviceTypeID: culto.id, blocks: blocks)
        }

        return [
            record(weeksAgo: 1, [lead("Carlos Pérez", 9, 40), lead("Ana Torres", 19, 5), lead("Daniel Ruiz", 51, 30), lead("Lucía Gómez", 5, 55)]),
            record(weeksAgo: 2, [lead("Marta Rivas", 11, 12), lead("Ana Torres", 14, 30), lead("Daniel Ruiz", 44, 10), lead("Lucía Gómez", 4, 40)]),
            record(weeksAgo: 3, [lead("Carlos Pérez", 8, 50), lead("José Herrera", 16, 20), lead("Pablo Castro", 38, 45), lead("Lucía Gómez", 6, 15)]),
            record(weeksAgo: 4, [lead("Carlos Pérez", 10, 5), lead("Ana Torres", 16, 40), lead("Daniel Ruiz", 47, 20), lead("Lucía Gómez", 5, 10)]),
            record(weeksAgo: 5, [lead("Marta Rivas", 9, 30), lead("José Herrera", 15, 0), lead("Daniel Ruiz", 42, 15), skipped]),
            record(weeksAgo: 6, [lead("Carlos Pérez", 11, 45), lead("Ana Torres", 18, 20), lead("Pablo Castro", 39, 50, .adjusted), lead("Sofía Méndez", 4, 50)]),
            record(weeksAgo: 7, [lead("José Herrera", 9, 55), lead("Ana Torres", 14, 10), lead("Daniel Ruiz", 53, 5), lead("Lucía Gómez", 7, 20)]),
            record(weeksAgo: 8, [lead("Carlos Pérez", 8, 40), lead("José Herrera", 17, 30), lead("Daniel Ruiz", 40, 0), lead("Marta Rivas", 5, 0)]),
            record(weeksAgo: 9, [lead("Marta Rivas", 12, 10), lead("Ana Torres", 15, 45), lead("Pablo Castro", 44, 30), lead("Lucía Gómez", 6, 5)]),
            record(weeksAgo: 10, [lead("Carlos Pérez", 9, 50), lead("Ana Torres", 20, 15), lead("Daniel Ruiz", 49, 40), lead("Lucía Gómez", 5, 30)])
        ]
    }()
}
