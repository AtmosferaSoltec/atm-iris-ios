//
//  ContractDecodingTests.swift
//  irisTests
//

import Foundation
import Testing
@testable import iris

/// The contract's examples decode, dates keep milliseconds and unknown enum values never break decoding.
struct ContractDecodingTests {
    private func decode<T: Decodable & Sendable>(_ json: String, as type: T.Type) throws -> T {
        try JSONCoding.decoder.decode(DataEnvelope<T>.self, from: Data("{\"data\":\(json)}".utf8)).data
    }

    @Test func authResultBecomesASession() throws {
        let result = try decode(ContractSamples.authResult(), as: AuthResultDTO.self)
        let session = try UserSession(result.sessionView)
        #expect(session.church.name == "Iglesia Vida Nueva")
        #expect(session.church.timeZone.identifier == "America/Lima")
        #expect(session.role == .owner)
        #expect(session.permissions == Set(Permission.allCases))
        #expect(session.can(.recordsManage))
        #expect(result.refreshToken == "refresh-1")
    }

    @Test func datesKeepMilliseconds() throws {
        let result = try decode(ContractSamples.authResult(), as: AuthResultDTO.self)
        let expected = try #require(ISO8601DateFormatter().date(from: "2026-10-05T15:45:31Z")).addingTimeInterval(0.022)
        #expect(abs(result.accessTokenExpiresAt.timeIntervalSince(expected)) < 0.0005)
        #expect(JSONCoding.string(from: result.accessTokenExpiresAt) == "2026-10-05T15:45:31.022Z")
    }

    @Test func unknownEnumValuesAreTolerated() throws {
        let result = try decode(ContractSamples.authResult(role: "superadmin"), as: AuthResultDTO.self)
        #expect(result.role == .unknown)
        // One account per church: whatever role an older server sends, the account can do everything.
        let session = try UserSession(result.sessionView)
        #expect(session.role == .owner)
        #expect(session.permissions == Set(Permission.allCases))
        #expect(session.churches.isEmpty)
        #expect(try JSONCoding.decoder.decode(MediaKindDTO.self, from: Data("\"document\"".utf8)) == .unknown)
    }

    @Test func syncPageWithChangesAndDeletions() throws {
        let json = ContractSamples.syncPage(
            church: ContractSamples.church,
            people: [ContractSamples.person("0199dddd-0000-7000-8000-000000000001", "Ana Torres")],
            deletedPeople: ["0199dddd-0000-7000-8000-000000000002"],
            cursor: "42",
            hasMore: true
        )
        let page = try decode(json, as: SyncPageDTO.self)
        #expect(page.church?.modules.multimedia == false)
        #expect(page.changes.people.map(\.name) == ["Ana Torres"])
        #expect(page.deleted.people == ["0199dddd-0000-7000-8000-000000000002"])
        #expect(page.cursor == "42")
        #expect(page.hasMore)
    }

    @Test func serviceTypeMapsBothWays() throws {
        let dto = try decode(ContractSamples.serviceType("0199cccc-0000-7000-8000-000000000001", "Culto general", defaultPersonID: "0199dddd-0000-7000-8000-000000000001"), as: ServiceTypeDTO.self)
        let type = try ServiceType(dto)
        #expect(type.color == 0xFFB547)
        #expect(type.schedule == ServiceType.Schedule(weekday: 1, hour: 10, minute: 0))
        #expect(type.blocks.first?.plannedMinutes == 40)
        #expect(type.inputDTO.color == "#FFB547")
        #expect(type.inputDTO.blocks.first?.id == "0199aaaa-0000-7000-8000-000000000001")
    }

    @Test func serviceRecordKeepsNamesAndStatuses() throws {
        let record = try ServiceRecord(decode(ContractSamples.serviceRecord, as: ServiceRecordDTO.self))
        #expect(record.serviceTypeName == "Culto general")
        #expect(record.blocks.map(\.status) == [.adjusted, .skipped])
        #expect(record.blocks.first?.personName == "Daniel Ruiz")
        // Skipped blocks don't count.
        #expect(record.actualSeconds == 2700)
    }

    @Test func optionalFieldsTravelAsNull() throws {
        let block = BlockRecord(name: "Prédica", plannedSeconds: 60, actualSeconds: 70, personID: nil)
        let json = try #require(String(data: JSONCoding.encoder.encode(block.dto), encoding: .utf8))
        #expect(json.contains("\"personId\":null"))
        #expect(json.contains("\"personName\":null"))
    }

    @Test func errorBodyWithFieldErrors() throws {
        let json = """
        {"statusCode":409,"code":"PERSON_NAME_TAKEN","message":"Ya existe una persona con ese nombre.",
        "errors":{"name":"Ya existe una persona con ese nombre."},"timestamp":"2026-10-05T15:30:31.022Z","path":"/api/v1/people"}
        """
        let body = try JSONCoding.decoder.decode(APIErrorBody.self, from: Data(json.utf8))
        let error = APIError.http(status: 409, body: body)
        #expect(error.code == "PERSON_NAME_TAKEN")
        #expect(error.fieldErrors["name"] == "Ya existe una persona con ese nombre.")
        #expect(error.message == "Ya existe una persona con ese nombre.")
        #expect(!error.isTransient)
        #expect(AuthError(error).fieldErrors["name"] != nil)
    }

    @Test func nameKeyCollapsesInnerSpaces() {
        #expect("  José   Pérez ".nameKey == "jose perez")
        #expect("ÁNGEL\tRUIZ".nameKey == "angel ruiz")
        #expect("Ana Torres".nameKey == "ana  torres".nameKey)
    }
}
