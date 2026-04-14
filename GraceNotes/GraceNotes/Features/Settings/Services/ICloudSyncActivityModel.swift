import CoreData
import Foundation

/// Best-effort “last time iCloud-related store activity was observed” using persistent-store
/// remote-change notifications.
@MainActor
final class ICloudSyncActivityModel: ObservableObject {
    nonisolated static let persistedTimestampKey = "ICloudSync.lastRemoteChangeTimestamp"

    @Published private(set) var lastRemoteChangeAt: Date?

    private var observerToken: NSObjectProtocol?
    /// Limits disk writes when many remote-change notifications arrive in a short burst (e.g. sync).
    private var pendingUserDefaultsPersist = false

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
        lastRemoteChangeAt = Date()
        if pendingUserDefaultsPersist {
            return
        }
        pendingUserDefaultsPersist = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.pendingUserDefaultsPersist = false
            if let stamp = self.lastRemoteChangeAt {
                UserDefaults.standard.set(stamp.timeIntervalSince1970, forKey: Self.persistedTimestampKey)
            }
        }
    }
}
