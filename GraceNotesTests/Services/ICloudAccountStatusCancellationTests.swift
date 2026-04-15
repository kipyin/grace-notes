import CloudKit
import XCTest
@testable import GraceNotes

final class ICloudAccountStatusCancellationTests: XCTestCase {
    func test_isCancellationLike_recognizesSwiftCancellation() {
        XCTAssertTrue(isCancellationLike(CancellationError()))
    }

    func test_isCancellationLike_recognizesCKOperationCancelled() {
        let error = CKError(.operationCancelled)
        XCTAssertTrue(isCancellationLike(error))
    }

    func test_isCancellationLike_recognizesNSURLCancelled() {
        let error = URLError(.cancelled) as NSError
        XCTAssertTrue(isCancellationLike(error))
    }

    func test_isCancellationLike_recognizesCloudKitNSErrorByDomainAndCode() {
        let nsError = NSError(
            domain: CKError.errorDomain,
            code: CKError.Code.operationCancelled.rawValue,
            userInfo: nil
        )
        XCTAssertTrue(isCancellationLike(nsError))
    }

    func test_isCancellationLike_walksNSUnderlyingErrorKey() {
        let inner = CKError(.operationCancelled)
        let wrapped = NSError(
            domain: "TestDomain",
            code: 1,
            userInfo: [NSUnderlyingErrorKey: inner]
        )
        XCTAssertTrue(isCancellationLike(wrapped))
    }

    func test_isCancellationLike_walksNSUnderlyingErrorsKey() {
        let inner = URLError(.cancelled) as NSError
        let wrapped = NSError(
            domain: "TestDomain",
            code: 1,
            userInfo: ["NSUnderlyingErrorsKey": [inner]]
        )
        XCTAssertTrue(isCancellationLike(wrapped))
    }

    func test_isCancellationLike_walksNestedUnderlyingChain() {
        let innermost = CKError(.operationCancelled)
        let middle = NSError(
            domain: "Middle",
            code: 2,
            userInfo: [NSUnderlyingErrorKey: innermost]
        )
        let outer = NSError(
            domain: "Outer",
            code: 3,
            userInfo: [NSUnderlyingErrorKey: middle]
        )
        XCTAssertTrue(isCancellationLike(outer))
    }

    func test_isCancellationLike_returnsFalseForUnrelatedErrors() {
        let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet, userInfo: nil)
        XCTAssertFalse(isCancellationLike(error))
    }
}
