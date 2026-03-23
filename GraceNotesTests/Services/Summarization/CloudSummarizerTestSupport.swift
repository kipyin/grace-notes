import Foundation

enum CloudSummarizerTestSupport {
    /// Resolves JSON chat `messages[0].content` from a URL request (body or body stream).
    static func chatPrompt(from request: URLRequest) -> String? {
        let body: Data?
        if let direct = request.httpBody {
            body = direct
        } else if let stream = request.httpBodyStream {
            body = Data(readingFrom: stream)
        } else {
            body = nil
        }
        return chatPrompt(fromEncodedJSONBody: body)
    }

    static func chatPrompt(fromEncodedJSONBody body: Data?) -> String? {
        guard let body,
              let root = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
              let rawMessages = root["messages"] as? [Any],
              let firstMessage = rawMessages.first as? [String: Any],
              let content = firstMessage["content"] as? String else {
            return nil
        }
        return content
    }
}

private extension Data {
    /// Reads an input stream until EOF (for mocked URLProtocol requests that use `httpBodyStream`).
    init(readingFrom stream: InputStream) {
        self.init()
        stream.open()
        defer { stream.close() }
        let bufferSize = 4096
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }
        while stream.hasBytesAvailable {
            let readCount = stream.read(buffer, maxLength: bufferSize)
            if readCount > 0 {
                append(buffer, count: readCount)
            } else if readCount < 0 {
                break
            }
        }
    }
}
