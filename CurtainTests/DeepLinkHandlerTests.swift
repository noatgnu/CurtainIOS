//
//  DeepLinkHandlerTests.swift
//  CurtainTests
//
//  Created by Toan Phung on 02/02/2026.
//

import XCTest
@testable import Curtain

@MainActor
class DeepLinkHandlerTests: XCTestCase {

    var handler: DeepLinkHandler!

    override func setUp() {
        super.setUp()
        handler = DeepLinkHandler.shared
    }

    // MARK: - Curtain Session URL Tests (curtain://open?uniqueId=...&apiURL=...)

    func testCurtainSessionURLWithAllParameters() async {
        let url = URL(string: "curtain://open?uniqueId=abc123&apiURL=https://api.example.com&frontendURL=https://frontend.example.com&desc=Test%20Session")!

        let result = await handler.processURL(url)

        XCTAssertEqual(result.type, .curtainSession)
        XCTAssertEqual(result.linkId, "abc123")
        XCTAssertEqual(result.apiUrl, "https://api.example.com")
        XCTAssertEqual(result.frontendUrl, "https://frontend.example.com")
        XCTAssertEqual(result.description, "Test Session")
        XCTAssertTrue(result.isValid)
    }

    func testCurtainSessionURLWithMinimalParameters() async {
        let url = URL(string: "curtain://open?uniqueId=xyz789&apiURL=https://api.test.com")!

        let result = await handler.processURL(url)

        XCTAssertEqual(result.type, .curtainSession)
        XCTAssertEqual(result.linkId, "xyz789")
        XCTAssertEqual(result.apiUrl, "https://api.test.com")
        XCTAssertTrue(result.isValid)
    }

    func testCurtainSessionURLWithAlternativeParameterNames() async {
        // Test with snake_case parameter names
        let url = URL(string: "curtain://open?unique_id=test-id&api_url=https://api.com&frontend_url=https://web.com")!

        let result = await handler.processURL(url)

        XCTAssertEqual(result.type, .curtainSession)
        XCTAssertEqual(result.linkId, "test-id")
        XCTAssertEqual(result.apiUrl, "https://api.com")
        XCTAssertEqual(result.frontendUrl, "https://web.com")
        XCTAssertTrue(result.isValid)
    }

    func testCurtainSessionURLWithIdParameter() async {
        let url = URL(string: "curtain://open?id=simple-id&host=https://host.com")!

        let result = await handler.processURL(url)

        XCTAssertEqual(result.type, .curtainSession)
        XCTAssertEqual(result.linkId, "simple-id")
        XCTAssertEqual(result.apiUrl, "https://host.com")
        XCTAssertTrue(result.isValid)
    }

    func testCurtainSessionURLMissingRequiredParameters() async {
        // Missing apiURL
        let url1 = URL(string: "curtain://open?uniqueId=abc123")!
        let result1 = await handler.processURL(url1)
        XCTAssertEqual(result1.type, .invalid)
        XCTAssertFalse(result1.isValid)

        // Missing uniqueId
        let url2 = URL(string: "curtain://open?apiURL=https://api.com")!
        let result2 = await handler.processURL(url2)
        XCTAssertEqual(result2.type, .invalid)
        XCTAssertFalse(result2.isValid)
    }

    // MARK: - DOI URL Tests

    func testDOIURLWithCurtainScheme() async {
        let url = URL(string: "curtain://open?doi=doi.org/10.1234/example&sessionId=session123")!

        let result = await handler.processURL(url)

        XCTAssertEqual(result.type, .doiSession)
        XCTAssertEqual(result.doi, "doi.org/10.1234/example")
        XCTAssertEqual(result.sessionId, "session123")
        XCTAssertTrue(result.isValid)
    }

    func testDOIURLWithoutSessionId() async {
        let url = URL(string: "curtain://open?doi=doi.org/10.5678/dataset")!

        let result = await handler.processURL(url)

        XCTAssertEqual(result.type, .doiSession)
        XCTAssertEqual(result.doi, "doi.org/10.5678/dataset")
        XCTAssertNil(result.sessionId)
        XCTAssertTrue(result.isValid)
    }

    func testDOIURLWithWebFormat() async {
        let url = URL(string: "https://curtain.proteo.info/#/doi.org/10.9999/test&session456")!

        let result = await handler.processURL(url)

        XCTAssertEqual(result.type, .doiSession)
        XCTAssertEqual(result.doi, "doi.org/10.9999/test")
        XCTAssertEqual(result.sessionId, "session456")
        XCTAssertTrue(result.isValid)
    }

    func testDOIURLWithWebFormatNoSession() async {
        let url = URL(string: "https://example.com/#/doi.org/10.1111/paper")!

        let result = await handler.processURL(url)

        XCTAssertEqual(result.type, .doiSession)
        XCTAssertEqual(result.doi, "doi.org/10.1111/paper")
        XCTAssertTrue(result.isValid)
    }

    // MARK: - Collection URL Tests

    func testCollectionURLWithCurtainScheme() async {
        let url = URL(string: "curtain://open?collectionId=42&apiURL=https://api.test.com&frontendURL=https://frontend.test.com")!

        let result = await handler.processURL(url)

        XCTAssertEqual(result.type, .collection)
        XCTAssertEqual(result.collectionId, 42)
        XCTAssertEqual(result.collectionApiUrl, "https://api.test.com")
        XCTAssertEqual(result.frontendUrl, "https://frontend.test.com")
        XCTAssertTrue(result.isValid)
    }

    func testCollectionURLWithSnakeCaseParams() async {
        let url = URL(string: "curtain://open?collection_id=99&api_url=https://api.com")!

        let result = await handler.processURL(url)

        XCTAssertEqual(result.type, .collection)
        XCTAssertEqual(result.collectionId, 99)
        XCTAssertTrue(result.isValid)
    }

    func testCollectionURLWithWebFormat() async {
        let url = URL(string: "https://curtain.proteo.info/#/collection/123")!

        let result = await handler.processURL(url)

        XCTAssertEqual(result.type, .collection)
        XCTAssertEqual(result.collectionId, 123)
        XCTAssertTrue(result.isValid)
    }

    func testCollectionURLWithDefaultApiUrl() async {
        // When apiURL is not provided, should default to celsusBackend
        let url = URL(string: "curtain://open?collectionId=5")!

        let result = await handler.processURL(url)

        XCTAssertEqual(result.type, .collection)
        XCTAssertEqual(result.collectionId, 5)
        XCTAssertEqual(result.collectionApiUrl, CurtainConstants.PredefinedHosts.celsusBackend)
        XCTAssertTrue(result.isValid)
    }

    // MARK: - Curtain Proteo URL Tests

    func testCurtainProteoURLWithLinkId() async {
        let url = URL(string: "https://curtain.proteo.info/#/f4b009f3-ac3c-470a-a68b-55fcadf68d0f")!

        let result = await handler.processURL(url)

        XCTAssertEqual(result.type, .curtainSession)
        XCTAssertEqual(result.linkId, "f4b009f3-ac3c-470a-a68b-55fcadf68d0f")
        XCTAssertEqual(result.apiUrl, CurtainConstants.PredefinedHosts.celsusBackend)
        XCTAssertEqual(result.frontendUrl, CurtainConstants.PredefinedHosts.proteoFrontend)
        XCTAssertTrue(result.isValid)
    }

    func testCurtainProteoURLWithSimpleLinkId() async {
        let url = URL(string: "https://curtain.proteo.info/#/my-dataset")!

        let result = await handler.processURL(url)

        XCTAssertEqual(result.type, .curtainSession)
        XCTAssertEqual(result.linkId, "my-dataset")
        XCTAssertTrue(result.isValid)
    }

    // MARK: - Generic Curtain URL Tests (Known Hosts)

    func testGenericCurtainURLFromKnownHost() async {
        let url = URL(string: "https://celsus.muttsu.xyz/session/abc-123")!

        let result = await handler.processURL(url)

        XCTAssertEqual(result.type, .curtainSession)
        XCTAssertEqual(result.linkId, "abc-123")
        XCTAssertTrue(result.isValid)
    }

    // MARK: - Unknown URL Tests (UUID Extraction)

    func testUnknownURLWithUUID() async {
        let uuid = "a1b2c3d4-e5f6-7890-abcd-ef1234567890"
        let url = URL(string: "https://unknown-site.com/path/\(uuid)/extra")!

        let result = await handler.processURL(url)

        XCTAssertEqual(result.type, .curtainSession)
        XCTAssertEqual(result.linkId, uuid)
        XCTAssertTrue(result.isValid)
    }

    func testUnknownURLWithoutUUID() async {
        let url = URL(string: "https://random-site.com/no-uuid-here")!

        let result = await handler.processURL(url)

        XCTAssertEqual(result.type, .invalid)
        XCTAssertFalse(result.isValid)
        XCTAssertNotNil(result.error)
    }

    // MARK: - QR Code Processing Tests

    func testQRCodeWithURL() async {
        let qrContent = "https://curtain.proteo.info/#/test-session-id"

        let result = await handler.processQRCode(qrContent)

        XCTAssertEqual(result.type, .curtainSession)
        XCTAssertEqual(result.linkId, "test-session-id")
        XCTAssertTrue(result.isValid)
    }

    func testQRCodeWithCurtainScheme() async {
        let qrContent = "curtain://open?uniqueId=qr-test&apiURL=https://api.qr.com"

        let result = await handler.processQRCode(qrContent)

        XCTAssertEqual(result.type, .curtainSession)
        XCTAssertEqual(result.linkId, "qr-test")
        XCTAssertEqual(result.apiUrl, "https://api.qr.com")
        XCTAssertTrue(result.isValid)
    }

    func testQRCodeWithJSON() async {
        let jsonContent = """
        {"uniqueId":"json-session","apiURL":"https://api.json.com","description":"JSON Test"}
        """

        let result = await handler.processQRCode(jsonContent)

        XCTAssertEqual(result.type, .curtainSession)
        XCTAssertEqual(result.linkId, "json-session")
        XCTAssertEqual(result.apiUrl, "https://api.json.com")
        XCTAssertEqual(result.description, "JSON Test")
        XCTAssertTrue(result.isValid)
    }

    func testQRCodeWithAlternativeJSONKeys() async {
        let jsonContent = """
        {"id":"alt-id","host":"https://alt.host.com","title":"Alt Title"}
        """

        let result = await handler.processQRCode(jsonContent)

        XCTAssertEqual(result.type, .curtainSession)
        XCTAssertEqual(result.linkId, "alt-id")
        XCTAssertEqual(result.apiUrl, "https://alt.host.com")
        XCTAssertEqual(result.description, "Alt Title")
        XCTAssertTrue(result.isValid)
    }

    func testQRCodeWithInvalidContent() async {
        let qrContent = "invalid-content-not-url-or-json"

        let result = await handler.processQRCode(qrContent)

        XCTAssertEqual(result.type, .invalid)
        XCTAssertFalse(result.isValid)
    }

    func testQRCodeWithBase64EncodedContent() async {
        // Base64 decoding is attempted as a fallback
        // The decoder tries JSON parsing first which may succeed before base64
        // This tests that malformed base64 doesn't crash
        let result = await handler.processQRCode("not-valid-base64!!!")

        // Should return invalid since it's neither URL, JSON, nor valid base64
        XCTAssertEqual(result.type, .invalid)
        XCTAssertFalse(result.isValid)
    }

    // MARK: - DeepLinkResult Validity Tests

    func testDeepLinkResultValidityForCurtainSession() {
        let validResult = DeepLinkResult(type: .curtainSession, linkId: "test", apiUrl: "https://api.com")
        XCTAssertTrue(validResult.isValid)

        let invalidResult1 = DeepLinkResult(type: .curtainSession, linkId: nil, apiUrl: "https://api.com")
        XCTAssertFalse(invalidResult1.isValid)

        let invalidResult2 = DeepLinkResult(type: .curtainSession, linkId: "test", apiUrl: nil)
        XCTAssertFalse(invalidResult2.isValid)
    }

    func testDeepLinkResultValidityForDOISession() {
        let validResult = DeepLinkResult(type: .doiSession, doi: "doi.org/10.1234/test")
        XCTAssertTrue(validResult.isValid)

        let invalidResult = DeepLinkResult(type: .doiSession, doi: nil)
        XCTAssertFalse(invalidResult.isValid)
    }

    func testDeepLinkResultValidityForCollection() {
        let validResult = DeepLinkResult(type: .collection, collectionId: 1, collectionApiUrl: "https://api.com")
        XCTAssertTrue(validResult.isValid)

        let invalidResult1 = DeepLinkResult(type: .collection, collectionId: nil, collectionApiUrl: "https://api.com")
        XCTAssertFalse(invalidResult1.isValid)

        let invalidResult2 = DeepLinkResult(type: .collection, collectionId: 1, collectionApiUrl: nil)
        XCTAssertFalse(invalidResult2.isValid)
    }

    func testDeepLinkResultValidityForInvalid() {
        let invalidResult = DeepLinkResult(type: .invalid, error: "Test error")
        XCTAssertFalse(invalidResult.isValid)
    }

    // MARK: - Deep Link URL Generation Tests

    func testGenerateSessionURL() {
        let url = CurtainConstants.DeepLinks.generateSessionURL(
            linkId: "test-link",
            apiUrl: "https://api.example.com",
            frontendUrl: "https://frontend.example.com"
        )

        XCTAssertNotNil(url)
        XCTAssertEqual(url?.scheme, "curtain")
        XCTAssertEqual(url?.host, "open")
        XCTAssertTrue(url?.absoluteString.contains("uniqueId=test-link") ?? false)
        XCTAssertTrue(url?.absoluteString.contains("apiURL=") ?? false)
        XCTAssertTrue(url?.absoluteString.contains("frontendURL=") ?? false)
    }

    func testGenerateSessionURLWithoutFrontend() {
        let url = CurtainConstants.DeepLinks.generateSessionURL(
            linkId: "minimal-link",
            apiUrl: "https://api.min.com"
        )

        XCTAssertNotNil(url)
        XCTAssertTrue(url?.absoluteString.contains("uniqueId=minimal-link") ?? false)
        XCTAssertFalse(url?.absoluteString.contains("frontendURL=") ?? false)
    }

    func testGenerateWebShareURL() {
        let url = CurtainConstants.DeepLinks.generateWebShareURL(
            linkId: "share-id",
            frontendUrl: "https://curtain.proteo.info"
        )

        XCTAssertNotNil(url)
        XCTAssertEqual(url?.absoluteString, "https://curtain.proteo.info/#/share-id")
    }

    func testGenerateWebShareURLWithTrailingSlash() {
        let url = CurtainConstants.DeepLinks.generateWebShareURL(
            linkId: "share-id",
            frontendUrl: "https://curtain.proteo.info/"
        )

        XCTAssertNotNil(url)
        XCTAssertEqual(url?.absoluteString, "https://curtain.proteo.info/#/share-id")
    }

    func testGenerateJSONQRCodeData() {
        let json = CurtainConstants.DeepLinks.generateJSONQRCodeData(
            linkId: "json-id",
            apiUrl: "https://api.json.com",
            frontendUrl: "https://frontend.json.com",
            description: "Test Description"
        )

        XCTAssertNotNil(json)
        // Parse the JSON and check values (key order in JSON is not guaranteed)
        if let jsonData = json?.data(using: .utf8),
           let parsed = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
            XCTAssertEqual(parsed["uniqueId"] as? String, "json-id")
            XCTAssertEqual(parsed["apiURL"] as? String, "https://api.json.com")
            XCTAssertEqual(parsed["type"] as? String, "curtain-session")
        } else {
            XCTFail("Failed to parse generated JSON")
        }
    }

    // MARK: - Round-Trip Tests (Generate URL -> Process URL)

    func testRoundTripSessionURL() async {
        let originalLinkId = "round-trip-test"
        let originalApiUrl = "https://api.roundtrip.com"
        let originalFrontendUrl = "https://frontend.roundtrip.com"

        guard let generatedURL = CurtainConstants.DeepLinks.generateSessionURL(
            linkId: originalLinkId,
            apiUrl: originalApiUrl,
            frontendUrl: originalFrontendUrl
        ) else {
            XCTFail("Failed to generate URL")
            return
        }

        let result = await handler.processURL(generatedURL)

        XCTAssertEqual(result.type, .curtainSession)
        XCTAssertEqual(result.linkId, originalLinkId)
        XCTAssertEqual(result.apiUrl, originalApiUrl)
        XCTAssertEqual(result.frontendUrl, originalFrontendUrl)
        XCTAssertTrue(result.isValid)
    }

    func testRoundTripWebShareURL() async {
        let originalLinkId = "web-share-round-trip"
        let frontendUrl = "https://curtain.proteo.info"

        guard let generatedURL = CurtainConstants.DeepLinks.generateWebShareURL(
            linkId: originalLinkId,
            frontendUrl: frontendUrl
        ) else {
            XCTFail("Failed to generate web share URL")
            return
        }

        let result = await handler.processURL(generatedURL)

        XCTAssertEqual(result.type, .curtainSession)
        XCTAssertEqual(result.linkId, originalLinkId)
        XCTAssertTrue(result.isValid)
    }

    func testRoundTripJSONQRCode() async {
        let originalLinkId = "json-round-trip"
        let originalApiUrl = "https://api.json-rt.com"
        let originalDescription = "JSON Round Trip Test"

        guard let jsonContent = CurtainConstants.DeepLinks.generateJSONQRCodeData(
            linkId: originalLinkId,
            apiUrl: originalApiUrl,
            description: originalDescription
        ) else {
            XCTFail("Failed to generate JSON QR code data")
            return
        }

        let result = await handler.processQRCode(jsonContent)

        XCTAssertEqual(result.type, .curtainSession)
        XCTAssertEqual(result.linkId, originalLinkId)
        XCTAssertEqual(result.apiUrl, originalApiUrl)
        XCTAssertEqual(result.description, originalDescription)
        XCTAssertTrue(result.isValid)
    }
}
