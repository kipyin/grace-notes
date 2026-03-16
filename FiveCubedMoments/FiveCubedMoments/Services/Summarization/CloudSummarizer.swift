import Foundation
import os

private let log = Logger(subsystem: "com.fivecubedmoments.FiveCubedMoments", category: "CloudSummarizer")

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

    func summarize(_ sentence: String, section: SummarizationSection) async throws -> SummarizationResult {
        let trimmed = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return SummarizationResult(label: "", isTruncated: false) }

        do {
            let label = try await callAPI(sentence: trimmed, section: section)
            let capped = label.count > maxLabelChars ? String(label.prefix(maxLabelChars)) : label
            log.debug("Cloud summarization succeeded: \"\(trimmed)\" -> \"\(capped)\"")
            return SummarizationResult(label: capped, isTruncated: label.count > maxLabelChars)
        } catch {
            log.info("Cloud API failed, using NL fallback: \(String(describing: error))")
            if let result = try? await fallback.summarize(sentence, section: section) {
                return result
            }
            return SummarizationResult(label: String(trimmed.prefix(maxLabelChars)), isTruncated: trimmed.count > maxLabelChars)
        }
    }

    private func prompt(for section: SummarizationSection, sentence: String) -> String {
        let bilingualNote = " Input may be in English or Chinese (中文); respond in the same language as the input with a short chip label (1–5 words or 1–5 字)."
        let baseSuffix = " Reply with only the label, no punctuation."
        switch section {
        case .gratitude:
            return "Extract 1–5 words for a chip label. This is for a gratitude list — do NOT include words like gratitude, grateful (or 感恩, 感谢, 感激). Just the essence: \(sentence).\(bilingualNote)\(baseSuffix)"
        case .need:
            return "Extract 1–5 words for a chip label. This is for a needs list — do NOT include words like need, needs (or 需要, 想). Just the essence: \(sentence).\(bilingualNote)\(baseSuffix)"
        case .person:
            return "Extract 1–5 words for a chip label about people. MUST include the person's name(s) if mentioned (人名 if in Chinese): \(sentence).\(bilingualNote)\(baseSuffix)"
        }
    }

    private func callAPI(sentence: String, section: SummarizationSection) async throws -> String {
        guard let url = URL(string: "\(baseURL)/chat/completions") else {
            throw CloudSummarizerError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10

        let promptText = prompt(for: section, sentence: sentence)
        let body: [String: Any] = [
            "model": model,
            "messages": [["role": "user", "content": promptText]],
            "max_tokens": 20,
            "temperature": 0.3
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw CloudSummarizerError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            log.info("Cloud API HTTP \(http.statusCode)")
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
