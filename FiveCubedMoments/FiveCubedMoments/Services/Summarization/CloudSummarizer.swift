import Foundation

/// Calls OpenAI-compatible chat completions API at chat.cloudapi.vip.
/// On any failure (network, timeout, invalid key, empty response), falls back to NaturalLanguageSummarizer.
/// See doc.newapi.pro for API details.
struct CloudSummarizer: Summarizer {
    private let baseURL: String
    private let model: String
    private let apiKey: String
    private let fallback: NaturalLanguageSummarizer
    private let urlSession: URLSession
    private let maxLabelChars = 20

    init(
        baseURL: String = "https://chat.cloudapi.vip/v1",
        model: String = "gpt-4o-mini",
        apiKey: String,
        fallback: NaturalLanguageSummarizer = NaturalLanguageSummarizer(),
        urlSession: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.model = model
        self.apiKey = apiKey
        self.fallback = fallback
        self.urlSession = urlSession
    }

    func summarize(_ sentence: String) async throws -> SummarizationResult {
        let trimmed = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return SummarizationResult(label: "", isTruncated: false) }

        do {
            let label = try await callAPI(sentence: trimmed)
            let capped = label.count > maxLabelChars ? String(label.prefix(maxLabelChars)) : label
            return SummarizationResult(label: capped, isTruncated: label.count > maxLabelChars)
        } catch {
            if let result = try? await fallback.summarize(sentence) {
                return result
            }
            let trimmed = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
            return SummarizationResult(label: String(trimmed.prefix(maxLabelChars)), isTruncated: trimmed.count > maxLabelChars)
        }
    }

    private func callAPI(sentence: String) async throws -> String {
        guard let url = URL(string: "\(baseURL)/chat/completions") else {
            throw CloudSummarizerError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10

        let prompt = "Summarize this into 1–5 words for a chip label: \(sentence). Reply with only the label, no punctuation."
        let body: [String: Any] = [
            "model": model,
            "messages": [["role": "user", "content": prompt]],
            "max_tokens": 20,
            "temperature": 0.3
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw CloudSummarizerError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            throw CloudSummarizerError.httpError(statusCode: http.statusCode)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let first = choices.first,
              let message = first["message"] as? [String: Any],
              let content = message["content"] as? String
        else {
            throw CloudSummarizerError.invalidJSON
        }

        let parsed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !parsed.isEmpty else {
            throw CloudSummarizerError.emptyContent
        }
        return parsed
    }
}

private enum CloudSummarizerError: Error {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    case invalidJSON
    case emptyContent
}
