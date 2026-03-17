import Foundation

/// Intercepts URLSession requests for testing. Set `mockResponse` before making requests.
final class MockURLProtocol: URLProtocol {
    // swiftlint:disable:next large_tuple
    static var mockResponse: ((URLRequest) -> (Data?, HTTPURLResponse?, Error?))?

    // swiftlint:disable:next static_over_final_class
    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    // swiftlint:disable:next static_over_final_class
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.mockResponse else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
            return
        }
        let (data, response, error) = handler(request)

        if let error = error {
            client?.urlProtocol(self, didFailWithError: error)
            return
        }
        guard let response = response else {
            let err = URLError(
                .unknown,
                userInfo: [NSLocalizedDescriptionKey: "Mock returned nil response and nil error"]
            )
            client?.urlProtocol(self, didFailWithError: err)
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        if let data = data {
            client?.urlProtocol(self, didLoad: data)
        }
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
