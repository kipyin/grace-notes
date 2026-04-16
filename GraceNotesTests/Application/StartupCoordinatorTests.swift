import XCTest
@testable import GraceNotes

@MainActor
final class StartupCoordinatorTests: XCTestCase {
    /// Hosted CI can take several seconds for the first in-memory `ModelContainer` on a cold simulator.
    private let asyncConditionTimeoutSeconds: TimeInterval = 15

    func test_startIfNeeded_immediateSuccess_transitionsToReady() async throws {
        let coordinator = StartupCoordinator(
            timing: .init(copyRotationInterval: .milliseconds(200), reassuranceDelay: .seconds(2)),
            persistenceFactory: {
                try PersistenceController.makeInMemoryForTesting()
            }
        )

        coordinator.startIfNeeded()

        try await waitUntil(timeoutSeconds: asyncConditionTimeoutSeconds) {
            if case .ready = coordinator.phase {
                return true
            }
            return false
        }
    }

    func test_startIfNeeded_delayedSuccess_transitionsThroughReassurance() async throws {
        let coordinator = StartupCoordinator(
            timing: .init(copyRotationInterval: .milliseconds(50), reassuranceDelay: .milliseconds(120)),
            persistenceFactory: {
                try await Task.sleep(for: .milliseconds(250))
                return try PersistenceController.makeInMemoryForTesting()
            }
        )

        coordinator.startIfNeeded()

        try await waitUntil(timeoutSeconds: asyncConditionTimeoutSeconds) {
            if case .reassurance = coordinator.phase {
                return true
            }
            return false
        }

        try await waitUntil(timeoutSeconds: asyncConditionTimeoutSeconds) {
            if case .ready = coordinator.phase {
                return true
            }
            return false
        }
    }

    func test_startIfNeeded_duringLongStartup_rotatesLoadingMessage() async throws {
        let coordinator = StartupCoordinator(
            timing: .init(copyRotationInterval: .milliseconds(80), reassuranceDelay: .seconds(5)),
            persistenceFactory: {
                try await Task.sleep(for: .milliseconds(450))
                return try PersistenceController.makeInMemoryForTesting()
            }
        )

        let firstMessage = coordinator.startupMessage
        coordinator.startIfNeeded()

        try await waitUntil(timeoutSeconds: asyncConditionTimeoutSeconds) {
            coordinator.startupMessage != firstMessage
        }
    }

    func test_startIfNeeded_whenFactoryThrows_transitionsToRetryableFailure() async throws {
        let coordinator = StartupCoordinator(
            timing: .init(copyRotationInterval: .milliseconds(80), reassuranceDelay: .milliseconds(200)),
            persistenceFactory: {
                throw MockStartupError.bootstrapFailed
            }
        )

        coordinator.startIfNeeded()

        try await waitUntil(timeoutSeconds: asyncConditionTimeoutSeconds) {
            if case .retryableFailure = coordinator.phase {
                return true
            }
            return false
        }
    }

    func test_retry_afterFailure_succeedsWithSingleInFlightAttempt() async throws {
        let attempts = AttemptCounter()
        let coordinator = StartupCoordinator(
            timing: .init(copyRotationInterval: .milliseconds(50), reassuranceDelay: .milliseconds(150)),
            persistenceFactory: {
                let currentAttempt = await attempts.incrementAndGet()
                if currentAttempt == 1 {
                    throw MockStartupError.bootstrapFailed
                }
                try await Task.sleep(for: .milliseconds(120))
                return try PersistenceController.makeInMemoryForTesting()
            }
        )

        coordinator.startIfNeeded()

        try await waitUntil(timeoutSeconds: asyncConditionTimeoutSeconds) {
            if case .retryableFailure = coordinator.phase {
                return true
            }
            return false
        }

        coordinator.retry()
        coordinator.retry()
        coordinator.retry()

        try await waitUntil(timeoutSeconds: asyncConditionTimeoutSeconds) {
            if case .ready = coordinator.phase {
                return true
            }
            return false
        }

        let totalAttempts = await attempts.currentValue()
        XCTAssertEqual(totalAttempts, 2)
    }

    func test_retry_whileAlreadyStarting_doesNotCreateOverlappingAttempt() async throws {
        let attempts = AttemptCounter()
        let coordinator = StartupCoordinator(
            timing: .init(copyRotationInterval: .milliseconds(60), reassuranceDelay: .milliseconds(500)),
            persistenceFactory: {
                _ = await attempts.incrementAndGet()
                try await Task.sleep(for: .milliseconds(180))
                return try PersistenceController.makeInMemoryForTesting()
            }
        )

        coordinator.startIfNeeded()
        coordinator.retry()
        coordinator.retry()

        try await waitUntil(timeoutSeconds: asyncConditionTimeoutSeconds) {
            if case .ready = coordinator.phase {
                return true
            }
            return false
        }

        let totalAttempts = await attempts.currentValue()
        XCTAssertEqual(totalAttempts, 1)
    }
}

private enum MockStartupError: Error {
    case bootstrapFailed
}

private actor AttemptCounter {
    private var attempts = 0

    func incrementAndGet() -> Int {
        attempts += 1
        return attempts
    }

    func currentValue() -> Int {
        attempts
    }
}

@MainActor
private func waitUntil(
    timeoutSeconds: TimeInterval,
    pollInterval: Duration = .milliseconds(20),
    condition: @escaping () -> Bool
) async throws {
    let deadline = Date().addingTimeInterval(timeoutSeconds)
    while Date() < deadline {
        if condition() {
            return
        }
        try await Task.sleep(for: pollInterval)
    }
    XCTFail("Condition did not pass within \(timeoutSeconds) seconds.")
}
