import Combine
import Foundation

@MainActor
final class ICloudAccountStatusModel: ObservableObject {
    /// `nil` until the first fetch completes; later refreshes keep the last value visible to avoid row flicker.
    @Published private(set) var displayedBucket: ICloudAccountBucket?

    private let provider: any ICloudAccountStatusProviding
    /// Increments on each `refresh()` so a slower, older fetch cannot overwrite a newer result.
    private var refreshGeneration = 0

    init(provider: any ICloudAccountStatusProviding = ICloudAccountStatusService()) {
        self.provider = provider
    }

    func refresh() {
        refreshGeneration += 1
        let generation = refreshGeneration
        let provider = self.provider
        Task { @MainActor [weak self] in
            let bucket = await provider.fetchAccountBucket()
            guard let self else { return }
            guard generation == self.refreshGeneration else { return }
            self.displayedBucket = bucket
        }
    }
}
