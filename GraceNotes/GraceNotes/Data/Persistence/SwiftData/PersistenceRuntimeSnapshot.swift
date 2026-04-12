import Foundation

/// This-launch persistence: bootstrap preference, CloudKit store use, and silent local fallback.
struct PersistenceRuntimeSnapshot: Equatable, Sendable {
    /// `PersistenceController.cloudSyncEnabled(using:)` at startup (or explicit flag for in-memory / UI tests).
    var userRequestedCloudSync: Bool
    /// `true` only when the opened store used `cloudKitDatabase == .automatic` (not in-memory).
    var storeUsesCloudKit: Bool
    /// `true` only when a cloud disk open failed and the local-only container was used instead.
    var startupUsedCloudKitFallback: Bool

    /// SwiftUI environment default for previews only; inject from `PersistenceController` at the app root.
    static let previewPlaceholder = PersistenceRuntimeSnapshot(
        userRequestedCloudSync: true,
        storeUsesCloudKit: true,
        startupUsedCloudKitFallback: false
    )

    static func forInMemory(userRequestedCloudSync: Bool) -> PersistenceRuntimeSnapshot {
        PersistenceRuntimeSnapshot(
            userRequestedCloudSync: userRequestedCloudSync,
            storeUsesCloudKit: false,
            startupUsedCloudKitFallback: false
        )
    }

    static func forDiskLaunch(
        userRequestedCloudSync: Bool,
        storeUsesCloudKit: Bool,
        startupUsedCloudKitFallback: Bool
    ) -> PersistenceRuntimeSnapshot {
        // A CloudKit-backed store and a startup fallback cannot both be true; callers (or tests) can
        // accidentally pass both, which would confuse settings copy and `isJournalOnCloudKitStore`.
        let effectiveStoreUsesCloudKit = startupUsedCloudKitFallback ? false : storeUsesCloudKit
        let effectiveFallback = effectiveStoreUsesCloudKit ? false : startupUsedCloudKitFallback
        return PersistenceRuntimeSnapshot(
            userRequestedCloudSync: userRequestedCloudSync,
            storeUsesCloudKit: effectiveStoreUsesCloudKit,
            startupUsedCloudKitFallback: effectiveFallback
        )
    }
}
