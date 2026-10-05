//
//  JSONCoding.swift
//  iris
//

import Foundation

/// Shared JSON coders for the API: ISO-8601 dates in UTC with milliseconds.
nonisolated enum JSONCoding {
    private static let withFraction = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
    private static let withoutFraction = Date.ISO8601FormatStyle()

    static func date(from text: String) -> Date? {
        (try? withFraction.parse(text)) ?? (try? withoutFraction.parse(text))
    }

    /// Rounds to the millisecond first: formatting the raw value can truncate .022 to .021.
    static func string(from date: Date) -> String {
        let milliseconds = Int64((date.timeIntervalSince1970 * 1000).rounded())
        let seconds = Date(timeIntervalSince1970: TimeInterval(milliseconds.quotientAndRemainder(dividingBy: 1000).quotient))
        let fraction = String(format: "%03lld", (milliseconds % 1000 + 1000) % 1000)
        return String(withoutFraction.format(seconds).dropLast()) + ".\(fraction)Z"
    }

    static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let text = try container.decode(String.self)
            guard let date = date(from: text) else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Fecha no ISO-8601: \(text)")
            }
            return date
        }
        return decoder
    }

    static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(string(from: date))
        }
        return encoder
    }
}

/// A string enum that decodes values it does not know as `.unknown`, so new API values never break decoding.
nonisolated protocol TolerantStringEnum: Codable, Hashable, Sendable, RawRepresentable where RawValue == String {
    static var unknown: Self { get }
}

nonisolated extension TolerantStringEnum {
    init(from decoder: any Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = Self(rawValue: raw) ?? .unknown
    }
}

nonisolated extension UUID {
    /// Lowercased text form sent to the API.
    var apiString: String { uuidString.lowercased() }
}
