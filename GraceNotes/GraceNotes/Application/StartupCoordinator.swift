import Combine
import Foundation

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

    typealias PersistenceFactory = @Sendable () async throws -> PersistenceController

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
    private var copyRotationTickCount = 0
    private var startupTask: Task<Void, Never>?
    private var copyRotationTask: Task<Void, Never>?
    private var reassuranceTask: Task<Void, Never>?

    init(
        timing: Timing = .default,
        loadingCopy: [String] = StartupCoordinator.defaultLoadingCopy,
        reassuranceCopy: [String] = StartupCoordinator.defaultReassuranceCopy,
        persistenceFactory: @escaping PersistenceFactory = {
            try await PersistenceController.makeForStartup()
        }
    ) {
        self.timing = timing
        self.loadingCopy = loadingCopy
        self.reassuranceCopy = reassuranceCopy
        self.persistenceFactory = persistenceFactory
        self.startupMessage = loadingCopy.first ?? String(localized: "We are setting up your private journal space...")
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
        isStartingUp = true
        loadingCopyIndex = 0
        reassuranceCopyIndex = 0
        copyRotationTickCount = 0
        phase = .loading
        startupMessage = loadingMessage(for: loadingCopyIndex)
        startCopyRotation(for: attemptID)
        scheduleReassuranceTransition(for: attemptID)

        startupTask?.cancel()
        startupTask = Task { [weak self] in
            guard let self else { return }
            let trace = PerformanceTrace.begin("StartupCoordinator.startupAttempt")
            do {
                let controller = try await persistenceFactory()
                await handleStartupSuccess(controller, attemptID: attemptID, traceStart: trace)
            } catch {
                await handleStartupFailure(error, attemptID: attemptID, traceStart: trace)
            }
        }
    }

    private func startCopyRotation(for attemptID: UInt64) {
        copyRotationTask?.cancel()
        copyRotationTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: timing.copyRotationInterval)
                } catch {
                    break
                }
                await advanceCopyIfNeeded(for: attemptID)
            }
        }
    }

    private func scheduleReassuranceTransition(for attemptID: UInt64) {
        reassuranceTask?.cancel()
        reassuranceTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await Task.sleep(for: timing.reassuranceDelay)
            } catch {
                return
            }
            await enterReassuranceIfNeeded(for: attemptID)
        }
    }

    private func advanceCopyIfNeeded(for attemptID: UInt64) {
        guard attemptID == currentAttemptID else { return }
        copyRotationTickCount += 1
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
        guard attemptID == currentAttemptID else { return }
        finishAttempt()
        phase = .ready(controller)
        PerformanceTrace.end("StartupCoordinator.startupAttempt.success", startedAt: traceStart)
    }

    private func handleStartupFailure(
        _ error: Error,
        attemptID: UInt64,
        traceStart: TimeInterval
    ) {
        guard attemptID == currentAttemptID else { return }
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
            return String(localized: "We are setting up your private journal space...")
        }
        return loadingCopy[safe: index] ?? loadingCopy[0]
    }

    private func reassuranceMessage(for index: Int) -> String {
        guard !reassuranceCopy.isEmpty else {
            return String(localized: "Still getting things ready...")
        }
        return reassuranceCopy[safe: index] ?? reassuranceCopy[0]
    }

    private func nextIndex(current: Int, count: Int) -> Int {
        guard count > 1 else { return 0 }
        return (current + 1) % count
    }

    private func startupErrorMessage(from error: Error) -> String {
        if let localizedError = error as? LocalizedError,
           let message = localizedError.errorDescription,
           !message.isEmpty {
            return message
        }
        return String(localized: "We couldn't finish setting up your journal space. Please try again.")
    }
}

private extension StartupCoordinator {
    static let defaultLoadingCopy: [String] = [
        String(localized: "We are setting up your private journal space..."),
        String(localized: "Preparing a calm place for your first reflection..."),
        String(localized: "Almost ready. Bringing your journal space online...")
    ]

    static let defaultReassuranceCopy: [String] = [
        String(localized: "Still getting things ready..."),
        String(localized: "Thanks for your patience. We are almost there.")
    ]
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}
