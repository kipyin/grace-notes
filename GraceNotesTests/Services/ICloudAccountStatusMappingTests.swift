import CloudKit
import XCTest
@testable import GraceNotes

final class ICloudAccountStatusMappingTests: XCTestCase {
    func test_mapsCkAccountStatuses() {
        XCTAssertEqual(ICloudAccountBucket(CKAccountStatus.available), .available)
        XCTAssertEqual(ICloudAccountBucket(CKAccountStatus.noAccount), .noAccount)
        XCTAssertEqual(ICloudAccountBucket(CKAccountStatus.restricted), .restricted)
        XCTAssertEqual(ICloudAccountBucket(CKAccountStatus.temporarilyUnavailable), .temporarilyUnavailable)
        XCTAssertEqual(ICloudAccountBucket(CKAccountStatus.couldNotDetermine), .couldNotDetermine)
    }

    func test_showsICloudSyncToggle_perBucket() {
        XCTAssertTrue(ICloudAccountBucket.available.showsICloudSyncToggle)
        XCTAssertFalse(ICloudAccountBucket.noAccount.showsICloudSyncToggle)
        XCTAssertFalse(ICloudAccountBucket.restricted.showsICloudSyncToggle)
        XCTAssertTrue(ICloudAccountBucket.temporarilyUnavailable.showsICloudSyncToggle)
        XCTAssertTrue(ICloudAccountBucket.couldNotDetermine.showsICloudSyncToggle)
    }
}
