import SwiftUI

private struct PersistenceRuntimeSnapshotKey: EnvironmentKey {
    static let defaultValue = PersistenceRuntimeSnapshot.previewPlaceholder
}

extension EnvironmentValues {
    var persistenceRuntimeSnapshot: PersistenceRuntimeSnapshot {
        get { self[PersistenceRuntimeSnapshotKey.self] }
        set { self[PersistenceRuntimeSnapshotKey.self] = newValue }
    }
}
