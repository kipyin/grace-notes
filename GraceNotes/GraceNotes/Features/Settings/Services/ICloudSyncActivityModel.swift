import CoreData
import Foundation

/// Best-effort “last time iCloud-related store activity was observed” using persistent-store
/// remote-change notifications.
@MainActor
final class ICloudSyncActivityModel: ObservableObject {
    private static let persistedTimestampKey = "ICloudSync.lastRemoteChangeTimestamp"

    @Published private(set) var lastRemoteChangeAt: Date?

    private var observerToken: NSObjectProtocol?

    init() {
        let raw = UserDefaults.standard.double(forKey: Self.persistedTimestampKey)
        if raw > 0 {
            lastRemoteChangeAt = Date(timeIntervalSince1970: raw)
        }
    }

    func startMonitoring() {
        guard observerToken == nil else { return }
        observerToken = NotificationCenter.default.addObserver(
            forName: .NSPersistentStoreRemoteChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.recordRemoteChange()
        }
    }

    deinit {
        if let observerToken {
            NotificationCenter.default.removeObserver(observerToken)
        }
    }

    private func recordRemoteChange() {
        let now = Date()
        lastRemoteChangeAt = now
        UserDefaults.standard.set(now.timeIntervalSince1970, forKey: Self.persistedTimestampKey)
    }
}
