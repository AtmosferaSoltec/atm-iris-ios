//
//  LiveChurchRepositories.swift
//  iris
//
//  Church settings over the local copy (contract §6, §8, §9, §14).
//

import Foundation

struct LiveModuleSettingsRepository: ModuleSettingsRepository {
    let data: LiveChurchData

    func changes() -> AsyncStream<Void> { data.changes(of: [.church]) }

    func modules() async throws -> ChurchModules {
        await church().map { ChurchModules($0.modules) } ?? ChurchModules()
    }

    func availableModules() async -> ChurchModules {
        await church()?.availableModules.map(ChurchModules.init) ?? ChurchModules()
    }

    func save(_ modules: ChurchModules) async throws {
        if let church = await church() {
            let updated = ChurchDTO(
                id: church.id, name: church.name, timezone: church.timezone, modules: modules.dto,
                availableModules: church.availableModules, projection: church.projection,
                storage: church.storage, createdAt: church.createdAt, updatedAt: data.now()
            )
            try await data.store.upsert(.church, [(updated.id, updated.name.nameKey, updated)])
        }
        try await data.write(
            APIRequest(.put, "/church/modules", body: modules.dto),
            kind: .church, label: String(localized: "Módulos"), touching: [.church]
        )
    }

    private func church() async -> ChurchDTO? {
        await data.store.all(.church, as: ChurchDTO.self).first
    }
}

struct LiveProjectionSettingsRepository: ProjectionSettingsRepository {
    let data: LiveChurchData

    func changes() -> AsyncStream<Void> { data.changes(of: [.church]) }

    func settings() async throws -> ProjectionSettings {
        await church().map { ProjectionSettings($0.projection) } ?? ProjectionSettings()
    }

    func save(_ settings: ProjectionSettings) async throws {
        if let church = await church() {
            let updated = ChurchDTO(
                id: church.id, name: church.name, timezone: church.timezone, modules: church.modules,
                availableModules: church.availableModules, projection: settings.dto,
                storage: church.storage, createdAt: church.createdAt, updatedAt: data.now()
            )
            try await data.store.upsert(.church, [(updated.id, updated.name.nameKey, updated)])
        }
        try await data.write(
            APIRequest(.put, "/church/projection", body: settings.dto),
            kind: .church, label: String(localized: "Proyección"), touching: [.church]
        )
    }

    private func church() async -> ChurchDTO? {
        await data.store.all(.church, as: ChurchDTO.self).first
    }
}

struct LivePeopleRepository: PeopleRepository {
    let data: LiveChurchData

    func changes() -> AsyncStream<Void> { data.changes(of: [.people]) }

    func people() async throws -> [Person] {
        await data.store.all(.people, as: PersonDTO.self).compactMap { try? Person($0) }
    }

    /// Created with the console's own id, so a retry from the outbox never duplicates it.
    func add(name: String) async throws -> Person {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let existing = await data.store.all(.people, as: PersonDTO.self)
        if existing.contains(where: { $0.name.nameKey == name.nameKey }) {
            throw LocalWriteError(message: String(localized: "Ya existe una persona con ese nombre."))
        }
        let person = Person(name: name)
        let now = data.now()
        let dto = PersonDTO(id: person.id.apiString, name: name, blockCount: 0, createdAt: now, updatedAt: now)
        try await data.store.upsert(.people, [(dto.id, name.nameKey, dto)])
        try await data.write(
            APIRequest(.post, "/people", body: PersonCreateBody(id: dto.id, name: name)),
            kind: .people, label: name, touching: [.people]
        )
        return person
    }

    func rename(_ id: Person.ID, to name: String) async throws {
        guard let current = await data.store.one(.people, id: id.apiString, as: PersonDTO.self) else { return }
        let dto = PersonDTO(id: current.id, name: name, blockCount: current.blockCount, createdAt: current.createdAt, updatedAt: data.now())
        try await data.store.upsert(.people, [(dto.id, name.nameKey, dto)])
        try await data.write(
            APIRequest(.patch, "/people/\(dto.id)", body: PersonRenameBody(name: name)),
            kind: .people, label: name, touching: [.people]
        )
    }

    /// Records keep the person's id and name; templates forget them as suggested leader (as the API does).
    func delete(_ id: Person.ID) async throws {
        let personID = id.apiString
        let name = await data.store.one(.people, id: personID, as: PersonDTO.self)?.name ?? ""
        try await data.store.delete(.people, ids: [personID])

        let types = await data.store.all(.serviceTypes, as: ServiceTypeDTO.self)
        let updated = types.compactMap { type -> ServiceTypeDTO? in
            guard type.blocks.contains(where: { $0.defaultPersonId?.lowercased() == personID }) else { return nil }
            return ServiceTypeDTO(
                id: type.id, name: type.name, color: type.color, schedule: type.schedule,
                blocks: type.blocks.map { block in
                    block.defaultPersonId?.lowercased() == personID
                        ? BlockTemplateDTO(id: block.id, name: block.name, plannedMinutes: block.plannedMinutes, defaultPersonId: nil)
                        : block
                },
                createdAt: type.createdAt, updatedAt: data.now()
            )
        }
        if !updated.isEmpty {
            try await data.store.upsert(.serviceTypes, updated.map { ($0.id, $0.name.nameKey, $0) })
        }
        try await data.write(
            APIRequest(.delete, "/people/\(personID)"),
            kind: .people, label: name, touching: [.people, .serviceTypes]
        )
    }
}

/// What the web (or another console) adelantó for the next service (contract §15): songs and
/// media, resolved against the library like `AddToServiceViewModel` resolves a pick.
struct LiveServicePlanRepository: ServicePlanRepository {
    let data: LiveChurchData
    let library: any LibraryRepository

    func changes() -> AsyncStream<Void> { data.changes(of: [.servicePlan]) }

    func currentService() async throws -> ServicePlan {
        let entries = await data.store.all(.servicePlan, as: ServicePlanItemDTO.self)
        var items: [ServiceItem] = []
        if !entries.isEmpty {
            let lyrics = (try? await library.lyrics()) ?? []
            let media = await library.music() + (await library.uploadedMedia())
            items = entries.compactMap { Self.resolve($0, lyrics: lyrics, media: media) }
        }
        return ServicePlan(id: UUID(), title: String(localized: "Servicio"), date: data.now(), items: items)
    }

    @discardableResult
    func add(kind: PlanItemKind, refID: String, label: String) async throws -> UUID {
        let id = UUID()
        let position = await data.store.count(.servicePlan)
        let now = data.now()
        let dto = ServicePlanItemDTO(id: id.apiString, kind: kind.dto, refId: refID, position: position, createdAt: now, updatedAt: now)
        try await data.store.upsert(.servicePlan, [(dto.id, LocalStore.position(position), dto)])
        try await data.write(
            APIRequest(.post, "/service-plan", body: ServicePlanItemCreateBody(id: dto.id, kind: dto.kind, refId: refID)),
            kind: .servicePlan, label: label, touching: [.servicePlan]
        )
        return id
    }

    func move(_ planItemID: UUID, to position: Int) async throws {
        let id = planItemID.apiString
        var entries = await data.store.all(.servicePlan, as: ServicePlanItemDTO.self)
        guard let from = entries.firstIndex(where: { $0.id == id }) else { return }
        let moved = entries.remove(at: from)
        let to = min(max(position, 0), entries.count)
        entries.insert(moved, at: to)

        let now = data.now()
        let reindexed = entries.enumerated().map { index, entry in
            ServicePlanItemDTO(
                id: entry.id, kind: entry.kind, refId: entry.refId, position: index,
                createdAt: entry.createdAt, updatedAt: entry.id == id ? now : entry.updatedAt
            )
        }
        try await data.store.upsert(.servicePlan, reindexed.map { ($0.id, LocalStore.position($0.position), $0) })
        try await data.write(
            APIRequest(.put, "/service-plan/\(id)/position", body: ServicePlanItemMoveBody(position: to)),
            kind: .servicePlan, label: "", touching: [.servicePlan]
        )
    }

    func remove(_ planItemID: UUID, label: String) async throws {
        let id = planItemID.apiString
        try await data.store.delete(.servicePlan, ids: [id])
        try await data.write(
            APIRequest(.delete, "/service-plan/\(id)"),
            kind: .servicePlan, label: label, touching: [.servicePlan]
        )
    }

    func clear() async throws {
        let ids = await data.store.all(.servicePlan, as: ServicePlanItemDTO.self).map(\.id)
        guard !ids.isEmpty else { return }
        try await data.store.delete(.servicePlan, ids: ids)
        try await data.write(
            APIRequest(.delete, "/service-plan"),
            kind: .servicePlan, label: "", touching: [.servicePlan]
        )
    }

    private static func resolve(_ entry: ServicePlanItemDTO, lyrics: [LyricSheet], media: [MediaAsset]) -> ServiceItem? {
        var item: ServiceItem?
        switch PlanItemKind(entry.kind) {
        case .song:
            item = lyrics.first { $0.id.apiString == entry.refId }.map(ServiceItem.init(lyric:))
        case .media:
            item = media.first { $0.id == entry.refId }.map(ServiceItem.init(asset:))
        case nil:
            item = nil
        }
        item?.planItemID = UUID(uuidString: entry.id)
        return item
    }
}

struct LiveServiceTypeRepository: ServiceTypeRepository {
    let data: LiveChurchData

    func changes() -> AsyncStream<Void> { data.changes(of: [.serviceTypes]) }

    func serviceTypes() async throws -> [ServiceType] {
        await data.store.all(.serviceTypes, as: ServiceTypeDTO.self).compactMap { try? ServiceType($0) }
    }

    /// `PUT` creates or replaces, so creating and editing are the same idempotent write.
    func save(_ type: ServiceType) async throws {
        let id = type.id.apiString
        let input = type.inputDTO
        let now = data.now()
        let createdAt = await data.store.one(.serviceTypes, id: id, as: ServiceTypeDTO.self)?.createdAt ?? now
        let dto = ServiceTypeDTO(
            id: id, name: input.name, color: input.color, schedule: input.schedule, blocks: input.blocks,
            createdAt: createdAt, updatedAt: now
        )
        try await data.store.upsert(.serviceTypes, [(id, type.name.nameKey, dto)])
        try await data.write(
            APIRequest(.put, "/service-types/\(id)", body: input),
            kind: .serviceTypes, label: type.name, touching: [.serviceTypes]
        )
    }

    func delete(_ id: ServiceType.ID) async throws {
        let typeID = id.apiString
        let name = await data.store.one(.serviceTypes, id: typeID, as: ServiceTypeDTO.self)?.name ?? ""
        try await data.store.delete(.serviceTypes, ids: [typeID])
        try await data.write(
            APIRequest(.delete, "/service-types/\(typeID)"),
            kind: .serviceTypes, label: name, touching: [.serviceTypes]
        )
    }
}
