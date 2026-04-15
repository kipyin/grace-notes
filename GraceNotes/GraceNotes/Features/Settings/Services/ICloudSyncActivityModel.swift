import CoreData
import Foundation
import UIKit

/// Best-effort “last time iCloud-related store activity was observed” using persistent-store
/// remote-change notifications.
@MainActor
final class ICloudSyncActivityModel: ObservableObject {
    nonisolated static let persistedTimestampKey = "ICloudSync.lastRemoteChangeTimestamp"

    @Published private(set) var lastRemoteChangeAt: Date?

    private var remoteChangeObserverToken: NSObjectProtocol?
    private var appLifecycleObserverTokens: [NSObjectProtocol] = []
    /// Limits disk writes when many remote-change notifications arrive in a short burst (e.g. sync).
    private var pendingUserDefaultsPersist = false

    init() {
        let raw = UserDefaults.standard.double(forKey: Self.persistedTimestampKey)
        if raw > 0 {
            lastRemoteChangeAt = Date(timeIntervalSince1970: raw)
        }
    }

    func startMonitoring() {
        guard remoteChangeObserverToken == nil else { return }

        remoteChangeObserverToken = NotificationCenter.default.addObserver(
            forName: .NSPersistentStoreRemoteChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.recordRemoteChange()
        }

        let center = NotificationCenter.default
        appLifecycleObserverTokens = [
            center.addObserver(
                forName: UIApplication.didEnterBackgroundNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.persistLastRemoteChangeIfNeeded()
            },
            center.addObserver(
                forName: UIApplication.willTerminateNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.persistLastRemoteChangeIfNeeded()
            }
        ]
    }

    deinit {
        if let remoteChangeObserverToken {
            NotificationCenter.default.removeObserver(remoteChangeObserverToken)
        }
        for token in appLifecycleObserverTokens {
            NotificationCenter.default.removeObserver(token)
        }
    }

    /// Synchronously mirrors `lastRemoteChangeAt` into `UserDefaults` when present.
    /// Used on background/terminate so disk is less likely to lag in-memory state if the process exits
    /// before a coalesced write runs.
    func persistLastRemoteChangeIfNeeded() {
        pendingUserDefaultsPersist = false
        if let stamp = lastRemoteChangeAt {
            UserDefaults.standard.set(stamp.timeIntervalSince1970, forKey: Self.persistedTimestampKey)
        }
    }

    private func recordRemoteChange() {
        lastRemoteChangeAt = Date()
        if pendingUserDefaultsPersist {
            return
        }
        pendingUserDefaultsPersist = true
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.pendingUserDefaultsPersist = false
            if let stamp = self.lastRemoteChangeAt {
                UserDefaults.standard.set(stamp.timeIntervalSince1970, forKey: Self.persistedTimestampKey)
            }
        }
    }
}
