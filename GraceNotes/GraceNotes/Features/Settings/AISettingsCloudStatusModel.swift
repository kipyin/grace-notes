import Combine
import Foundation
import Network

enum AISettingsCloudStatusRow: Equatable {
    case misconfigured
    case checking
    case offline
    case checkFailed
    /// After a successful **manual** check. Cleared on new check, AI off, Settings disappear, or unsatisfied route.
    case connectionVerified
}

/// Derives AI cloud status for Settings: path monitoring, optional probe, precedence per initiative architecture.
@MainActor
final class AISettingsCloudStatusModel: ObservableObject {
    static let lastConnectivitySuccessDefaultsKey = "aiConnectivityLastSuccessDate"

    @Published private(set) var statusRow: AISettingsCloudStatusRow?

    private var monitor: NWPathMonitor?
    private let monitorQueue = DispatchQueue(label: "com.gracenotes.gracenotes.networkpath")
    private var isPathSatisfied = true
    private var isProbing = false
    private var lastProbeFailed = false
    /// Sticky after manual probe success; cleared like `connectionVerified` doc on the enum case.
    private var manualConnectionVerifiedSticky = false
    private var aiFeaturesEnabled = false
    private let connectivityVerifier: AICloudConnectivityVerifying
    private let userDefaults: UserDefaults
    private let cloudApiKeyConfigured: () -> Bool
    private let installsPathMonitor: Bool

    private static let autoCheckThrottle: TimeInterval = 15 * 60

    private enum ProbeTrigger {
        case manual
        case automatic
    }

    init(
        connectivityVerifier: AICloudConnectivityVerifying = AICloudConnectivityVerifier(),
        userDefaults: UserDefaults = .standard,
        cloudApiKeyConfigured: @escaping () -> Bool = { ApiSecrets.isCloudApiKeyConfigured },
        installsPathMonitor: Bool = true,
        initialPathSatisfied: Bool = true
    ) {
        self.connectivityVerifier = connectivityVerifier
        self.userDefaults = userDefaults
        self.cloudApiKeyConfigured = cloudApiKeyConfigured
        self.installsPathMonitor = installsPathMonitor
        self.isPathSatisfied = initialPathSatisfied
    }

    /// Call when Settings appears or AI toggle changes.
    func refresh(aiFeaturesEnabled: Bool) {
        self.aiFeaturesEnabled = aiFeaturesEnabled
        if !aiFeaturesEnabled {
            clearManualSuccessUI()
        }
        if aiFeaturesEnabled, cloudApiKeyConfigured() {
            startPathMonitorIfNeeded()
        } else {
            stopPathMonitor()
        }
        recomputeStatusRow()
    }

    /// Throttled silent auto-check when Settings is shown (skipped if a recent probe succeeded).
    func scheduleThrottledAutoCheckIfNeeded() {
        guard aiFeaturesEnabled, cloudApiKeyConfigured(), isPathSatisfied, !isProbing else {
            return
        }
        let lastSuccess = userDefaults.object(forKey: Self.lastConnectivitySuccessDefaultsKey) as? Date
        if let lastSuccess, Date().timeIntervalSince(lastSuccess) < Self.autoCheckThrottle {
            return
        }
        Task { await runProbe(trigger: .automatic) }
    }

    func onSettingsDisappear() {
        stopPathMonitor()
        clearManualSuccessUI()
        recomputeStatusRow()
    }

    func sceneDidBecomeActive() {
        if aiFeaturesEnabled, cloudApiKeyConfigured() {
            startPathMonitorIfNeeded()
        }
        recomputeStatusRow()
        scheduleThrottledAutoCheckIfNeeded()
    }

    func requestManualConnectivityCheck() {
        clearManualSuccessUI()
        Task { await runProbe(trigger: .manual) }
    }

    private func runProbe(trigger: ProbeTrigger) async {
        guard !isProbing else { return }
        isProbing = true
        clearManualSuccessUI()
        recomputeStatusRow()
        let reachable = await connectivityVerifier.verifyReachable()
        isProbing = false
        if reachable {
            userDefaults.set(Date(), forKey: Self.lastConnectivitySuccessDefaultsKey)
            lastProbeFailed = false
            if trigger == .manual {
                manualConnectionVerifiedSticky = true
            }
        } else {
            lastProbeFailed = true
        }
        recomputeStatusRow()
    }

    private func clearManualSuccessUI() {
        manualConnectionVerifiedSticky = false
    }

    private func startPathMonitorIfNeeded() {
        guard installsPathMonitor else { return }
        guard monitor == nil else { return }
        let pathMonitor = NWPathMonitor()
        pathMonitor.pathUpdateHandler = { [weak self] path in
            let satisfied = path.status == .satisfied
            Task { @MainActor in
                self?.handlePathUpdate(satisfied: satisfied)
            }
        }
        pathMonitor.start(queue: monitorQueue)
        monitor = pathMonitor
    }

    private func stopPathMonitor() {
        monitor?.cancel()
        monitor = nil
    }

    private func handlePathUpdate(satisfied: Bool) {
        let wasSatisfied = isPathSatisfied
        isPathSatisfied = satisfied
        if wasSatisfied && !satisfied {
            clearManualSuccessUI()
        }
        recomputeStatusRow()
        // Do not schedule auto-probes from path churn: it can chain a second probe right after a
        // manual check and clear failure / checking state before the user sees the outcome.
        // Throttled auto-check runs from Settings `.task` and `sceneDidBecomeActive` only.
    }

    private func recomputeStatusRow() {
        guard aiFeaturesEnabled else {
            statusRow = nil
            return
        }
        if !cloudApiKeyConfigured() {
            statusRow = .misconfigured
            return
        }
        if isProbing {
            statusRow = .checking
            return
        }
        if !isPathSatisfied {
            statusRow = .offline
            return
        }
        if lastProbeFailed {
            statusRow = .checkFailed
            return
        }
        if manualConnectionVerifiedSticky {
            statusRow = .connectionVerified
            return
        }
        statusRow = nil
    }
}
