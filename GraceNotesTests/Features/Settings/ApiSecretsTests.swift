import XCTest
@testable import GraceNotes

final class ApiSecretsTests: XCTestCase {
    func test_isUsableCloudApiKey_placeholder_returnsFalse() {
        XCTAssertFalse(ApiSecrets.isUsableCloudApiKey("YOUR_KEY_HERE"))
    }

    func test_isUsableCloudApiKey_whitespacePlaceholder_returnsFalse() {
        XCTAssertFalse(ApiSecrets.isUsableCloudApiKey("  YOUR_KEY_HERE  "))
    }

    func test_isUsableCloudApiKey_empty_returnsFalse() {
        XCTAssertFalse(ApiSecrets.isUsableCloudApiKey(""))
    }

    func test_isUsableCloudApiKey_nonPlaceholder_returnsTrue() {
        XCTAssertTrue(ApiSecrets.isUsableCloudApiKey("sk-test"))
    }
}
