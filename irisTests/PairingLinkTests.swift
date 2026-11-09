//
//  PairingLinkTests.swift
//  irisTests
//

import XCTest
@testable import iris

final class PairingLinkTests: XCTestCase {
    func testValidLink() throws {
        let link = try PairingLink.parse("iris://pair?v=1&c=abcDEF_123-xyz&p=47831&n=PC%20del%20santuario&h=192.168.1.20").get()
        XCTAssertEqual(link.secret, "abcDEF_123-xyz")
        XCTAssertEqual(link.port, 47831)
        XCTAssertEqual(link.computerName, "PC del santuario")
        XCTAssertEqual(link.hosts, ["192.168.1.20"])
        XCTAssertEqual(link.urls.map(\.absoluteString), ["ws://192.168.1.20:47831/remote"])
    }

    func testMultipleHostsKeepOrder() throws {
        let link = try PairingLink.parse("iris://pair?v=1&c=s&p=5000&h=10.0.0.5&h=192.168.1.20&h=172.16.0.2").get()
        XCTAssertEqual(link.hosts, ["10.0.0.5", "192.168.1.20", "172.16.0.2"])
        XCTAssertNil(link.computerName)
    }

    func testMissingFields() {
        for text in [
            "iris://pair?v=1&p=5000&h=10.0.0.5",          // no secret
            "iris://pair?v=1&c=s&h=10.0.0.5",             // no port
            "iris://pair?v=1&c=s&p=5000",                 // no hosts
            "iris://pair?c=s&p=5000&h=10.0.0.5",          // no version
            "iris://pair?v=1&c=s&p=99999&h=10.0.0.5",     // port out of range
            "iris://pair?v=1&c=s&p=5000&h=evil.example",  // not an IPv4
            "iris://pair?v=1&c=s&p=5000&h=10.0.0.999",
        ] {
            XCTAssertEqual(PairingLink.parse(text), .failure(.malformed), text)
        }
    }

    func testWrongVersion() {
        XCTAssertEqual(PairingLink.parse("iris://pair?v=2&c=s&p=5000&h=10.0.0.5"), .failure(.unsupportedVersion))
    }

    func testWrongSchemeOrAction() {
        XCTAssertEqual(PairingLink.parse("https://example.com/?v=1&c=s&p=5000&h=10.0.0.5"), .failure(.notIris))
        XCTAssertEqual(PairingLink.parse("iris://other?v=1&c=s&p=5000&h=10.0.0.5"), .failure(.notIris))
        XCTAssertEqual(PairingLink.parse("hello"), .failure(.notIris))
    }
}
