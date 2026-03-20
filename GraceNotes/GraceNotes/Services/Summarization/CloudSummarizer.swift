import Foundation
import os

private let log = Logger(subsystem: "com.gracenotes.GraceNotes", category: "CloudSummarizer")

/// Calls OpenAI-compatible chat completions API at chat.cloudapi.vip.
/// On any failure (network, timeout, invalid key, empty response), falls back to a deterministic
/// trimmed full-text label by default; a different summarizer may be injected.
/// See doc.newapi.pro for API details.
struct CloudSummarizer: Summarizer {
    private let baseURL: String
    private let model: String
    private let apiKey: String
    private let fallback: any Summarizer
    private let urlSession: URLSession

    init(
        baseURL: String = ApiSecrets.cloudAPIBaseURL,
        model: String = "gpt-4o-mini",
        apiKey: String,
        fallback: (any Summarizer)? = nil,
        urlSession: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.model = model
        self.apiKey = apiKey
        self.fallback = fallback ?? DeterministicChipLabelSummarizer()
        self.urlSession = urlSession
    }

    func summarize(_ sentence: String, section: SummarizationSection) async throws -> SummarizationResult {
        let trimmed = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return SummarizationResult(label: "", isTruncated: false) }

        do {
            let label = try await callAPI(sentence: trimmed, section: section)
            let cleanedLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
            log.debug("Cloud summarization succeeded: \"\(trimmed)\" -> \"\(cleanedLabel)\"")
            return SummarizationResult(label: cleanedLabel, isTruncated: false)
        } catch {
            log.info("Cloud API failed, using fallback summarizer: \(String(describing: error))")
            if let result = try? await fallback.summarize(sentence, section: section) {
                return result
            }
            return SummarizationResult(label: trimmed, isTruncated: false)
        }
    }

    private func prompt(for section: SummarizationSection, sentence: String) -> String {
        let bilingualNote = " Input may be in English or Chinese (中文); respond in the same language " +
            "as the input with a short chip label (target <= 10 units, where 1 Chinese character counts as 2 units " +
            "and 1 Latin character counts as 1 unit)."
        let baseSuffix = " Reply with only the label, no punctuation."
        switch section {
        case .gratitude:
            let prefix = "Extract 1–5 words for a chip label. This is for a gratitude list — "
            let restriction = "do NOT include words like gratitude, grateful (or 感恩, 感谢, 感激). Just the essence"
            return "\(prefix)\(restriction): \(sentence).\(bilingualNote)\(baseSuffix)"
        case .need:
            let prefix = "Extract 1–5 words for a chip label. This is for a needs list — "
            let restriction = "do NOT include words like need, needs (or 需要, 想). Just the essence"
            return "\(prefix)\(restriction): \(sentence).\(bilingualNote)\(baseSuffix)"
        case .person:
            let prefix = "Extract 1–5 words for a chip label about people. "
            let requirement = "MUST include the person's name(s) if mentioned (人名 if in Chinese)"
            return "\(prefix)\(requirement): \(sentence).\(bilingualNote)\(baseSuffix)"
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
        let body = CloudChatRequest(
            model: model,
            messages: [CloudChatMessage(role: "user", content: promptText)],
            maxTokens: 20,
            temperature: 0.3
        )
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw CloudSummarizerError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            log.info("Cloud API HTTP \(http.statusCode)")
            throw CloudSummarizerError.httpError(statusCode: http.statusCode)
        }

        guard let responseBody = try? JSONDecoder().decode(CloudChatResponse.self, from: data),
              let content = responseBody.choices.first?.message.content
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

private struct CloudChatRequest: Encodable {
    let model: String
    let messages: [CloudChatMessage]
    let maxTokens: Int
    let temperature: Double

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case maxTokens = "max_tokens"
        case temperature
    }
}

private struct CloudChatResponse: Decodable {
    let choices: [CloudChatChoice]
}

private struct CloudChatChoice: Decodable {
    let message: CloudChatResponseMessage
}

private struct CloudChatResponseMessage: Decodable {
    let content: String
}

private struct CloudChatMessage: Codable {
    let role: String
    let content: String
}

private enum CloudSummarizerError: Error {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    case invalidJSON
    case emptyContent
}
