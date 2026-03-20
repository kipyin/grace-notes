import XCTest
@testable import GraceNotes

@MainActor
final class AISettingsCloudStatusModelTests: XCTestCase {
    private final class MockConnectivityVerifier: AICloudConnectivityVerifying, @unchecked Sendable {
        var result: Bool
        init(result: Bool) {
            self.result = result
        }

        func verifyReachable() async -> Bool {
            result
        }
    }

    private func isolatedDefaults() -> UserDefaults {
        let name = "test.AISettingsCloudStatus.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    private func waitForStatus(
        _ model: AISettingsCloudStatusModel,
        matches: @escaping (AISettingsCloudStatusRow?) -> Bool,
        timeout: TimeInterval = 2.0
    ) async {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if matches(model.statusRow) {
                return
            }
            try? await Task.sleep(nanoseconds: 15_000_000)
        }
        XCTFail("Timed out waiting for statusRow")
    }

    func test_manualProbeSuccess_showsConnectionVerified() async {
        let defaults = isolatedDefaults()
        let model = AISettingsCloudStatusModel(
            connectivityVerifier: MockConnectivityVerifier(result: true),
            userDefaults: defaults,
            cloudApiKeyConfigured: { true },
            installsPathMonitor: false,
            initialPathSatisfied: true
        )
        model.refresh(aiFeaturesEnabled: true)
        model.requestManualConnectivityCheck()
        await waitForStatus(model) { $0 == .connectionVerified }
    }

    func test_automaticProbeSuccess_doesNotEmitConnectionVerified() async {
        let defaults = isolatedDefaults()
        defaults.removeObject(forKey: AISettingsCloudStatusModel.lastConnectivitySuccessDefaultsKey)
        let model = AISettingsCloudStatusModel(
            connectivityVerifier: MockConnectivityVerifier(result: true),
            userDefaults: defaults,
            cloudApiKeyConfigured: { true },
            installsPathMonitor: false,
            initialPathSatisfied: true
        )
        model.refresh(aiFeaturesEnabled: true)
        model.scheduleThrottledAutoCheckIfNeeded()
        await waitForStatus(model) { $0 == nil }
    }

    func test_onSettingsDisappearClearsStickyManualSuccess() async {
        let defaults = isolatedDefaults()
        let model = AISettingsCloudStatusModel(
            connectivityVerifier: MockConnectivityVerifier(result: true),
            userDefaults: defaults,
            cloudApiKeyConfigured: { true },
            installsPathMonitor: false,
            initialPathSatisfied: true
        )
        model.refresh(aiFeaturesEnabled: true)
        model.requestManualConnectivityCheck()
        await waitForStatus(model) { $0 == .connectionVerified }

        model.onSettingsDisappear()
        model.refresh(aiFeaturesEnabled: true)
        XCTAssertNil(model.statusRow)
    }

    func test_misconfiguredWhenKeyMissing() {
        let model = AISettingsCloudStatusModel(
            connectivityVerifier: MockConnectivityVerifier(result: true),
            userDefaults: isolatedDefaults(),
            cloudApiKeyConfigured: { false },
            installsPathMonitor: false,
            initialPathSatisfied: true
        )
        model.refresh(aiFeaturesEnabled: true)
        XCTAssertEqual(model.statusRow, .misconfigured)
    }
}
