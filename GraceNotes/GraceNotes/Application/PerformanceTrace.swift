import Foundation
import os

enum PerformanceTrace {
    private static let logger = Logger(
        subsystem: "com.gracenotes.GraceNotes",
        category: "Performance"
    )

    static func begin(_ label: String) -> TimeInterval {
        logger.log("[BEGIN] \(label, privacy: .public)")
        return ProcessInfo.processInfo.systemUptime
    }

    static func end(_ label: String, startedAt start: TimeInterval) {
        let elapsedMs = max(0, (ProcessInfo.processInfo.systemUptime - start) * 1000)
        logger.log("[END] \(label, privacy: .public) (\(elapsedMs, format: .fixed(precision: 2)) ms)")
    }

    static func instant(_ label: String) {
        logger.log("[MARK] \(label, privacy: .public)")
    }
}
