import Foundation

/// Lightweight reachability check for the cloud AI API host (no user journal content).
protocol AICloudConnectivityVerifying: Sendable {
    func verifyReachable() async -> Bool
}

/// Uses the same API origin as `CloudSummarizer`’s default `baseURL`.
final class AICloudConnectivityVerifier: AICloudConnectivityVerifying, @unchecked Sendable {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func verifyReachable() async -> Bool {
        guard let url = URL(string: "\(Self.apiBaseURLString)/models") else {
            return false
        }
        if await headIndicatesReachable(url: url) {
            return true
        }
        return await getIndicatesReachable(url: url)
    }

    /// Matches `CloudSummarizer` default `baseURL` (see `CloudSummarizer.swift`).
    private static let apiBaseURLString = "https://chat.cloudapi.vip/v1"

    private func headIndicatesReachable(url: URL) async -> Bool {
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 5
        do {
            let (_, response) = try await session.data(for: request)
            return httpResponseIsReachable(response)
        } catch {
            return false
        }
    }

    private func getIndicatesReachable(url: URL) async -> Bool {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 5
        do {
            let (_, response) = try await session.data(for: request)
            return httpResponseIsReachable(response)
        } catch {
            return false
        }
    }

    private func httpResponseIsReachable(_ response: URLResponse) -> Bool {
        guard let http = response as? HTTPURLResponse else {
            return false
        }
        let code = http.statusCode
        if (200...399).contains(code) {
            return true
        }
        if code == 401 || code == 403 {
            return true
        }
        return false
    }
}
