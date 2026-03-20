import Combine
import Foundation

@MainActor
final class ICloudAccountStatusModel: ObservableObject {
    /// `nil` until the first fetch completes; later refreshes keep the last value visible to avoid row flicker.
    @Published private(set) var displayedBucket: ICloudAccountBucket?

    private let provider: any ICloudAccountStatusProviding

    init(provider: any ICloudAccountStatusProviding = ICloudAccountStatusService()) {
        self.provider = provider
    }

    func refresh() {
        Task {
            let bucket = await provider.fetchAccountBucket()
            displayedBucket = bucket
        }
    }
}
