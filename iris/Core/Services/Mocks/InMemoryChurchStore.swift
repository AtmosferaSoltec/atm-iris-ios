//
//  InMemoryChurchStore.swift
//  iris
//

import Foundation
import Observation

/// Single in-memory source of truth for the mock church data during an app run.
@Observable
final class InMemoryChurchStore {
    /// Initial contents of a store.
    struct Seed {
        var modules: ChurchModules
        var serviceTypes: [ServiceType]
        var people: [Person]
        /// Newest first.
        var records: [ServiceRecord]

        static var sample: Seed {
            Seed(
                modules: ChurchModules(),
                serviceTypes: MockChurchData.serviceTypes,
                people: MockChurchData.people,
                records: MockChurchData.records
            )
        }

        static var empty: Seed {
            Seed(modules: ChurchModules(), serviceTypes: [], people: [], records: [])
        }
    }

    var modules: ChurchModules
    var serviceTypes: [ServiceType]
    var people: [Person]
    /// Newest first.
    var records: [ServiceRecord]

    init(seed: Seed = .sample) {
        modules = seed.modules
        serviceTypes = seed.serviceTypes
        people = seed.people
        records = seed.records
    }
}
