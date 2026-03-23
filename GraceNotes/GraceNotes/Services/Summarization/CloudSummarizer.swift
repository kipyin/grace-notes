import Foundation
import os

private let log = Logger(subsystem: "com.gracenotes.GraceNotes", category: "CloudSummarizer")

/// Instruction language for chip cloud summarization.
/// `.automatic` follows `AppInstructionLocale` (same rule as Review).
enum ChipCloudPromptLanguage: Equatable, Sendable {
    case automatic
    case english
    case simplifiedChinese
}

/// Calls OpenAI-compatible chat completions API at chat.cloudapi.vip.
/// On any failure (network, timeout, invalid key, empty response), falls back to a deterministic
/// trimmed full-text label by default; a different summarizer may be injected.
///
/// **Prompt language:** Instructions match the app UI locale (`zh-Hans` → Chinese; otherwise English),
/// aligned with `CloudReviewInsightsGenerator`. The chip *label* should still follow the user’s entry language.
///
/// **Low-signal input:** Obvious keyboard mash or repeated characters skip the network call and use the
/// fallback summarizer (trimmed literal). If the model returns a label that is not grounded in the user’s
/// text or looks like generic spiritual filler unrelated to the entry, the response is discarded and the
/// fallback is used (same as API failure).
///
/// See doc.newapi.pro for API details.
struct CloudSummarizer: Summarizer {
    private let baseURL: String
    private let model: String
    private let apiKey: String
    private let fallback: any Summarizer
    private let urlSession: URLSession
    private let promptLanguage: ChipCloudPromptLanguage
    private let instructionLocale: AppInstructionLocale

    init(
        baseURL: String = ApiSecrets.cloudAPIBaseURL,
        model: String = "gpt-4o-mini",
        apiKey: String,
        fallback: (any Summarizer)? = nil,
        urlSession: URLSession = .shared,
        promptLanguage: ChipCloudPromptLanguage = .automatic,
        bundleForAutomaticLanguage: Bundle = .main
    ) {
        self.baseURL = baseURL
        self.model = model
        self.apiKey = apiKey
        self.fallback = fallback ?? DeterministicChipLabelSummarizer()
        self.urlSession = urlSession
        self.promptLanguage = promptLanguage
        switch promptLanguage {
        case .automatic:
            self.instructionLocale = AppInstructionLocale.preferred(bundle: bundleForAutomaticLanguage)
        case .english:
            self.instructionLocale = .english
        case .simplifiedChinese:
            self.instructionLocale = .simplifiedChinese
        }
    }

    func summarize(_ sentence: String, section: SummarizationSection) async throws -> SummarizationResult {
        let trimmed = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return SummarizationResult(label: "", isTruncated: false) }

        if Self.shouldSkipCloudForLowSignal(trimmed) {
            log.debug("Skipping cloud summarization for low-signal input")
            return await resultFromFallback(sentence: sentence, trimmed: trimmed, section: section)
        }

        do {
            let label = try await callAPI(sentence: trimmed, section: section)
            let cleanedLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
            log.debug("Cloud summarization succeeded: \"\(trimmed)\" -> \"\(cleanedLabel)\"")
            if !Self.isLabelGroundedInInput(label: cleanedLabel, input: trimmed)
                || Self.labelLooksLikeUnrelatedGenericFiller(label: cleanedLabel, input: trimmed) {
                log.info("Cloud label failed grounding or generic-filler check; using fallback")
                return await resultFromFallback(sentence: sentence, trimmed: trimmed, section: section)
            }
            return SummarizationResult(label: cleanedLabel, isTruncated: false)
        } catch {
            log.info("Cloud API failed, using fallback summarizer: \(String(describing: error))")
            return await resultFromFallback(sentence: sentence, trimmed: trimmed, section: section)
        }
    }

    private func resultFromFallback(
        sentence: String,
        trimmed: String,
        section: SummarizationSection
    ) async -> SummarizationResult {
        if let result = try? await fallback.summarize(sentence, section: section) {
            return result
        }
        return SummarizationResult(label: trimmed, isTruncated: false)
    }

    private func prompt(for section: SummarizationSection, sentence: String) -> String {
        switch instructionLocale {
        case .english:
            return promptEnglish(for: section, sentence: sentence)
        case .simplifiedChinese:
            return promptSimplifiedChinese(for: section, sentence: sentence)
        }
    }

    private func promptEnglish(for section: SummarizationSection, sentence: String) -> String {
        let unitRule = "Target <= 10 units (1 Chinese character = 2 units; 1 Latin character = 1 unit). " +
            "The label language should match the user’s entry (English or Chinese)."
        let grounding = "Use only content grounded in the user’s text. " +
            "If the text is random keystrokes or meaningless, reply with the exact same user text, unchanged."
        let suffix = " User text: \(sentence)\n\(unitRule)\nReply with only the label, no punctuation."
        switch section {
        case .gratitude:
            return "Extract 1–5 words for a short chip label. Context: a gratitude list line. " +
                "Do NOT use gratitude, grateful, thankful, thanks (or 感恩, 感谢, 感激, 谢谢). " +
                "\(grounding)\(suffix)"
        case .need:
            return "Extract 1–5 words for a short chip label. Context: a needs list line. " +
                "Do NOT use need, needs, want (or 需要, 想要). " +
                "\(grounding)\(suffix)"
        case .person:
            return "Extract 1–5 words for a short chip label about people. " +
                "Include the person’s name(s) if mentioned (中文人名 if in Chinese). " +
                "\(grounding)\(suffix)"
        }
    }

    private func promptSimplifiedChinese(for section: SummarizationSection, sentence: String) -> String {
        let unitRule = "标签长度目标不超过 10 个「单位」（1 个汉字算 2 单位，1 个拉丁字母算 1 单位）。" +
            "标签用语与用户条目语言一致（中文或英文皆可，以条目为准）。"
        let grounding = "只能概括用户文字里真的出现的内容；若文字像乱敲键盘、无意义字符，请原样返回用户原文，不要改写。"
        let suffix = "用户原文：\(sentence)\n\(unitRule)\n只输出标签本身，不要标点或解释。"
        switch section {
        case .gratitude:
            return "请从下面这条「感恩」列表条目中提取 1–5 个词作为简短标签。" +
                "不要用「感恩」「感谢」「感激」「谢谢」等空泛词当标签主体。" +
                grounding + suffix
        case .need:
            return "请从下面这条「需要」列表条目中提取 1–5 个词作为简短标签。" +
                "不要用「需要」「想要」等词当标签主体。" +
                grounding + suffix
        case .person:
            return "请从下面这条「人物」相关条目中提取 1–5 个词作为简短标签；若提到姓名须保留姓名。" +
                grounding + suffix
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

    // MARK: - Low-signal and grounding (on-device)

    /// Skips the cloud call for obvious non-text or mash input. Conservative: real short phrases still go to the model.
    private static func shouldSkipCloudForLowSignal(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return false }

        if Set(trimmed).count == 1 {
            return trimmed.count >= 4
        }

        let asciiLetters = trimmed.unicodeScalars.filter { scalar in
            let code = scalar.value
            return (65...90).contains(code) || (97...122).contains(code)
        }
        let letterCount = asciiLetters.count
        if letterCount >= 12, !trimmed.contains(where: { $0.isWhitespace }) {
            let vowelValues: Set<UInt32> = [65, 69, 73, 79, 85, 97, 101, 105, 111, 117]
            let vowelCount = asciiLetters.filter { vowelValues.contains($0.value) }.count
            if Double(vowelCount) / Double(letterCount) < 0.18 {
                return true
            }
        }
        return false
    }

    private static func isLabelGroundedInInput(label: String, input: String) -> Bool {
        let labelText = label.trimmingCharacters(in: .whitespacesAndNewlines)
        let inputText = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !labelText.isEmpty, !inputText.isEmpty else { return false }

        let labelLower = labelText.lowercased()
        let inputLower = inputText.lowercased()

        if labelLower == inputLower { return true }
        if inputLower.contains(labelLower) { return true }
        if labelLower.contains(inputLower), inputText.count >= 3 { return true }

        for word in latinWords(in: inputLower) where word.count >= 2 {
            if labelLower.contains(word) { return true }
        }

        for character in inputText where character.isIdeographicCharacter {
            if labelText.contains(character) { return true }
        }

        let lettersOnly = String(inputLower.filter { $0.isLetter })
        if lettersOnly.count >= 4, !inputLower.contains(where: { $0.isWhitespace }) {
            let prefix = String(lettersOnly.prefix(4))
            if labelLower.contains(prefix) { return true }
        }

        return false
    }

    /// Generic spiritual / section filler in the model output language that does not appear in the user entry.
    private static func labelLooksLikeUnrelatedGenericFiller(label: String, input: String) -> Bool {
        let bannedChinese = ["心存感激", "感恩的心", "心怀感恩", "学会感恩", "感恩生活"]
        for phrase in bannedChinese where label.contains(phrase) && !input.contains(phrase) {
            return true
        }
        let bannedEnglish = ["gratitude", "thankful", "blessed", "grateful"]
        let labelLower = label.lowercased()
        let inputLower = input.lowercased()
        for phrase in bannedEnglish where labelLower.contains(phrase) && !inputLower.contains(phrase) {
            return true
        }
        return false
    }

    private static func latinWords(in string: String) -> [String] {
        var words: [String] = []
        var current = ""
        for character in string {
            if character.isLetter, character.isASCII {
                current.append(character)
            } else if !current.isEmpty {
                words.append(current)
                current = ""
            }
        }
        if !current.isEmpty {
            words.append(current)
        }
        return words
    }
}

private extension Character {
    var isIdeographicCharacter: Bool {
        unicodeScalars.contains { $0.properties.isIdeographic }
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
