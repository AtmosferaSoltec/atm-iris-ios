//
//  LiveTimeRecordRepository.swift
//  iris
//
//  Service timings over the local copy (contract §14). Only times are stored, never projected content.
//

import Foundation

struct LiveTimeRecordRepository: TimeRecordRepository {
    let data: LiveChurchData

    func changes() -> AsyncStream<Void> { data.changes(of: [.serviceRecords]) }

    /// Every console's records, newest first.
    func records() async throws -> [ServiceRecord] {
        await data.store.all(.serviceRecords, as: ServiceRecordDTO.self)
            .compactMap { try? ServiceRecord($0) }
            .sorted { $0.date > $1.date }
    }

    /// `PUT` with the console's id: retrying (or saving again after a failure) never creates a second record.
    func save(_ record: ServiceRecord) async throws {
        let id = record.id.apiString
        let now = data.now()
        let createdAt = await data.store.one(.serviceRecords, id: id, as: ServiceRecordDTO.self)?.createdAt ?? now
        try await store(record.dto(createdAt: createdAt, updatedAt: now))
        try await data.write(
            APIRequest(.put, Self.path(id), body: record.inputDTO),
            kind: .serviceRecords, label: record.serviceTypeName ?? String(localized: "Registro de tiempos"), touching: [.serviceRecords]
        )
    }

    func adjust(_ recordID: ServiceRecord.ID, block blockID: BlockRecord.ID, actualSeconds: TimeInterval) async throws {
        let seconds = Int(max(0, actualSeconds).rounded())
        try await patch(recordID, blockID, body: BlockRecordPatchBody(change: .actualSeconds(seconds))) { block in
            block.actualSeconds = TimeInterval(seconds)
            block.status = .adjusted
        }
    }

    func changeLeader(_ recordID: ServiceRecord.ID, block blockID: BlockRecord.ID, to personID: Person.ID?) async throws {
        let name = await personID.asyncFlatMap { id in
            await data.store.one(.people, id: id.apiString, as: PersonDTO.self)?.name
        }
        try await patch(recordID, blockID, body: BlockRecordPatchBody(change: .person(personID?.apiString))) { block in
            block.personID = personID
            block.personName = name
        }
    }

    func delete(_ id: ServiceRecord.ID) async throws {
        let recordID = id.apiString
        let label = await data.store.one(.serviceRecords, id: recordID, as: ServiceRecordDTO.self)?.serviceTypeName ?? ""
        try await data.store.delete(.serviceRecords, ids: [recordID])
        try await data.write(APIRequest(.delete, Self.path(recordID)), kind: .serviceRecords, label: label, touching: [.serviceRecords])
    }

    func isPendingUpload(_ id: ServiceRecord.ID) async -> Bool {
        await data.store.hasPendingOperation(path: Self.path(id.apiString))
    }

    // MARK: Private

    private static func path(_ id: String) -> String { "/service-records/\(id)" }

    private func store(_ dto: ServiceRecordDTO) async throws {
        try await data.store.upsert(.serviceRecords, [(dto.id, LocalStore.newestFirst(dto.date), dto)])
    }

    private func patch(
        _ recordID: ServiceRecord.ID,
        _ blockID: BlockRecord.ID,
        body: BlockRecordPatchBody,
        change: (inout BlockRecord) -> Void
    ) async throws {
        let id = recordID.apiString
        guard let dto = await data.store.one(.serviceRecords, id: id, as: ServiceRecordDTO.self),
              var record = try? ServiceRecord(dto),
              let index = record.blocks.firstIndex(where: { $0.id == blockID }) else { return }
        change(&record.blocks[index])
        try await store(record.dto(createdAt: dto.createdAt, updatedAt: data.now()))
        try await data.write(
            APIRequest(.patch, "\(Self.path(id))/blocks/\(blockID.apiString)", body: body),
            kind: .serviceRecords, label: dto.serviceTypeName, touching: [.serviceRecords]
        )
    }
}

private extension Optional {
    func asyncFlatMap<U>(_ transform: (Wrapped) async -> U?) async -> U? {
        guard let self else { return nil }
        return await transform(self)
    }
}
