import XCTest

@testable import Cloude

final class OnboardingPairingPayloadTests: XCTestCase {
    func testParsesPairingURLWithDefaults() {
        let payload = OnboardingPairingPayload(
            url: URL(string: "cloude://pair?host=127.0.0.1&token=secret&name=Mac%20Mini")!)

        XCTAssertEqual(payload, OnboardingPairingPayload(host: "127.0.0.1", token: "secret", name: "Mac Mini"))
    }

    func testParsesExplicitPort() {
        let payload = OnboardingPairingPayload(
            url: URL(string: "cloude://pair?host=remotecc.example&port=9443&token=secret")!)

        XCTAssertEqual(payload, OnboardingPairingPayload(host: "remotecc.example", port: 9443, token: "secret"))
    }

    func testRejectsInvalidPairingURLs() {
        XCTAssertNil(OnboardingPairingPayload(url: URL(string: "https://pair?host=127.0.0.1&token=secret")!))
        XCTAssertNil(OnboardingPairingPayload(url: URL(string: "cloude://pair?host=127.0.0.1")!))
        XCTAssertNil(OnboardingPairingPayload(url: URL(string: "cloude://pair?token=secret")!))
    }
}
