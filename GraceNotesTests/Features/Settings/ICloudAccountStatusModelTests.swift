import XCTest
@testable import GraceNotes

@MainActor
final class ICloudAccountStatusModelTests: XCTestCase {
    private final class MockProvider: ICloudAccountStatusProviding {
        var bucket: ICloudAccountBucket
        init(bucket: ICloudAccountBucket) {
            self.bucket = bucket
        }

        func fetchAccountBucket() async -> ICloudAccountBucket {
            bucket
        }
    }

    func test_refresh_publishesBucketFromProvider() async {
        let mock = MockProvider(bucket: .noAccount)
        let model = ICloudAccountStatusModel(provider: mock)

        model.refresh()
        try? await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertEqual(model.displayedBucket, .noAccount)
    }
}
