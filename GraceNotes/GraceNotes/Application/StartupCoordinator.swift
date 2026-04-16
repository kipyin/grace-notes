import Combine
import Foundation
import os

private let startupCoordinatorLogger = Logger(
    subsystem: "com.gracenotes.GraceNotes",
    category: "StartupCoordinator"
)

/// Default startup copy is kept outside ``StartupCoordinator`` so `init` default arguments stay
/// valid in Swift 6 strict concurrency (defaults are evaluated in a nonisolated context).
private enum StartupCoordinatorDefaultCopy {
    static let loading: [String] = [
        String(localized: "startup.status.settingUp"),
        String(localized: "startup.status.preparingCalm"),
        String(localized: "startup.status.almostReady")
    ]

    static let reassurance: [String] = [
        String(localized: "startup.status.stillWorking"),
        String(localized: "startup.status.thanksPatience")
    ]
}

@MainActor
final class StartupCoordinator: ObservableObject {
    enum Phase {
        case loading
        case reassurance
        case retryableFailure(message: String)
        case ready(PersistenceController)
    }

    struct Timing {
        let copyRotationInterval: Duration
        let reassuranceDelay: Duration

        static let `default` = Timing(
            copyRotationInterval: .seconds(3.5),
            reassuranceDelay: .seconds(4.5)
        )

        static let uiTesting = Timing(
            copyRotationInterval: .seconds(5),
            reassuranceDelay: .seconds(60)
        )
    }

    typealias PersistenceFactory = () async throws -> PersistenceController

    @Published private(set) var phase: Phase = .loading
    @Published private(set) var startupMessage: String
    @Published private(set) var isStartingUp = false

    private let loadingCopy: [String]
    private let reassuranceCopy: [String]
    private let timing: Timing
    private let persistenceFactory: PersistenceFactory

    private var hasStarted = false
    private var currentAttemptID: UInt64 = 0
    private var loadingCopyIndex = 0
    private var reassuranceCopyIndex = 0
    private var startupTask: Task<Void, Never>?
    private var copyRotationTask: Task<Void, Never>?
    private var reassuranceTask: Task<Void, Never>?

    init(
        timing: Timing = .default,
        loadingCopy: [String] = StartupCoordinatorDefaultCopy.loading,
        reassuranceCopy: [String] = StartupCoordinatorDefaultCopy.reassurance,
        persistenceFactory: @escaping PersistenceFactory = {
            try await PersistenceController.makeForStartup()
        }
    ) {
        self.timing = timing
        self.loadingCopy = loadingCopy
        self.reassuranceCopy = reassuranceCopy
        self.persistenceFactory = persistenceFactory
        self.startupMessage = loadingCopy.first
            ?? String(localized: "startup.status.settingUp")
    }

    deinit {
        startupTask?.cancel()
        copyRotationTask?.cancel()
        reassuranceTask?.cancel()
    }

    func startIfNeeded() {
        guard !hasStarted else { return }
        hasStarted = true
        beginStartupAttempt()
    }

    func retry() {
        guard case .retryableFailure = phase else { return }
        beginStartupAttempt()
    }

    private func beginStartupAttempt() {
        guard !isStartingUp else { return }

        currentAttemptID += 1
        let attemptID = currentAttemptID
        let runPersistence = persistenceFactory
        let copyRotationInterval = timing.copyRotationInterval
        let reassuranceDelay = timing.reassuranceDelay
        isStartingUp = true
        loadingCopyIndex = 0
        reassuranceCopyIndex = 0
        phase = .loading
        startupMessage = loadingMessage(for: loadingCopyIndex)
        startCopyRotation(for: attemptID, interval: copyRotationInterval)
        scheduleReassuranceTransition(for: attemptID, delay: reassuranceDelay)

        startupTask?.cancel()
        startupTask = Task {
            let trace = PerformanceTrace.begin("StartupCoordinator.startupAttempt")
            do {
                let controller = try await runPersistence()
                await MainActor.run { [weak self] in
                    guard let self else {
                        PerformanceTrace.end("StartupCoordinator.startupAttempt.teardown", startedAt: trace)
                        return
                    }
                    self.handleStartupSuccess(controller, attemptID: attemptID, traceStart: trace)
                }
            } catch {
                await MainActor.run { [weak self] in
                    guard let self else {
                        PerformanceTrace.end("StartupCoordinator.startupAttempt.teardown", startedAt: trace)
                        return
                    }
                    self.handleStartupFailure(error, attemptID: attemptID, traceStart: trace)
                }
            }
        }
    }

    private func startCopyRotation(for attemptID: UInt64, interval: Duration) {
        copyRotationTask?.cancel()
        copyRotationTask = Task {
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: interval)
                } catch {
                    break
                }
                await MainActor.run { [weak self] in
                    self?.advanceCopyIfNeeded(for: attemptID)
                }
            }
        }
    }

    private func scheduleReassuranceTransition(for attemptID: UInt64, delay: Duration) {
        reassuranceTask?.cancel()
        reassuranceTask = Task {
            do {
                try await Task.sleep(for: delay)
            } catch {
                return
            }
            await MainActor.run { [weak self] in
                self?.enterReassuranceIfNeeded(for: attemptID)
            }
        }
    }

    private func advanceCopyIfNeeded(for attemptID: UInt64) {
        guard attemptID == currentAttemptID else { return }
        switch phase {
        case .loading:
            loadingCopyIndex = nextIndex(current: loadingCopyIndex, count: loadingCopy.count)
            startupMessage = loadingMessage(for: loadingCopyIndex)
        case .reassurance:
            reassuranceCopyIndex = nextIndex(current: reassuranceCopyIndex, count: reassuranceCopy.count)
            startupMessage = reassuranceMessage(for: reassuranceCopyIndex)
        case .retryableFailure, .ready:
            break
        }
    }

    private func enterReassuranceIfNeeded(for attemptID: UInt64) {
        guard attemptID == currentAttemptID else { return }
        guard case .loading = phase else { return }
        reassuranceCopyIndex = 0
        phase = .reassurance
        startupMessage = reassuranceMessage(for: reassuranceCopyIndex)
    }

    private func handleStartupSuccess(
        _ controller: PersistenceController,
        attemptID: UInt64,
        traceStart: TimeInterval
    ) {
        guard attemptID == currentAttemptID else {
            PerformanceTrace.end("StartupCoordinator.startupAttempt.superseded", startedAt: traceStart)
            return
        }
        finishAttempt()
        phase = .ready(controller)
        PerformanceTrace.end("StartupCoordinator.startupAttempt.success", startedAt: traceStart)
    }

    private func handleStartupFailure(
        _ error: Error,
        attemptID: UInt64,
        traceStart: TimeInterval
    ) {
        guard attemptID == currentAttemptID else {
            PerformanceTrace.end("StartupCoordinator.startupAttempt.superseded", startedAt: traceStart)
            return
        }
        finishAttempt()
        let message = startupErrorMessage(from: error)
        startupMessage = message
        phase = .retryableFailure(message: message)
        PerformanceTrace.end("StartupCoordinator.startupAttempt.failure", startedAt: traceStart)
    }

    private func finishAttempt() {
        isStartingUp = false
        startupTask = nil
        copyRotationTask?.cancel()
        copyRotationTask = nil
        reassuranceTask?.cancel()
        reassuranceTask = nil
    }

    private func loadingMessage(for index: Int) -> String {
        guard !loadingCopy.isEmpty else {
            return String(localized: "startup.status.settingUp")
        }
        return loadingCopy[safe: index] ?? loadingCopy[0]
    }

    private func reassuranceMessage(for index: Int) -> String {
        guard !reassuranceCopy.isEmpty else {
            return String(localized: "startup.status.stillWorking")
        }
        return reassuranceCopy[safe: index] ?? reassuranceCopy[0]
    }

    private func nextIndex(current: Int, count: Int) -> Int {
        guard count > 1 else { return 0 }
        return (current + 1) % count
    }

    private func startupErrorMessage(from error: Error) -> String {
        startupCoordinatorLogger.error(
            "Persistence startup failed: \(String(reflecting: error), privacy: .public)"
        )
        return String(localized: "startup.error.setupFailed")
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}
