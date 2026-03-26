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

    private func waitForDisplayedBucket(
        _ model: ICloudAccountStatusModel,
        equals expected: ICloudAccountBucket,
        timeout: TimeInterval = 1,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if model.displayedBucket == expected {
                return
            }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTFail("Timed out waiting for displayedBucket to equal \(expected).", file: file, line: line)
    }

    func test_refresh_publishesBucketFromProvider() async {
        let mock = MockProvider(bucket: .noAccount)
        let model = ICloudAccountStatusModel(provider: mock)

        model.refresh()
        await waitForDisplayedBucket(model, equals: .noAccount)

        XCTAssertEqual(model.displayedBucket, .some(.noAccount))
    }
}
