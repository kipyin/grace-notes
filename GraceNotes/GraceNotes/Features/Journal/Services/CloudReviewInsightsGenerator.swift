import Foundation

/// Natural language for cloud Review insight *instructions* (not user-facing app strings).
enum CloudReviewInsightsPromptLanguage: Equatable, Sendable {
    /// `zh-Hans` when the app’s active localization is Simplified Chinese; otherwise English.
    case automatic
    case english
    case simplifiedChinese
}

struct CloudReviewInsightsGenerator: ReviewInsightsGenerating {
    private let baseURL: String
    private let model: String
    private let apiKey: String
    private let urlSession: URLSession
    private let promptLanguage: CloudReviewInsightsPromptLanguage
    private let sanitizer = CloudReviewInsightsSanitizer()
    private let maxEntriesForContext = 14

    init(
        baseURL: String = ApiSecrets.cloudAPIBaseURL,
        model: String = "gpt-4o-mini",
        apiKey: String,
        urlSession: URLSession = .shared,
        promptLanguage: CloudReviewInsightsPromptLanguage = .automatic
    ) {
        self.baseURL = baseURL
        self.model = model
        self.apiKey = apiKey
        self.urlSession = urlSession
        self.promptLanguage = promptLanguage
    }

    func generateInsights(
        from entries: [JournalEntry],
        referenceDate: Date,
        calendar: Calendar = .current
    ) async throws -> ReviewInsights {
        let weekRange = weekDateRange(containing: referenceDate, calendar: calendar)
        let weeklyEntries = entries
            .filter { weekRange.contains($0.entryDate) }
            .sorted { $0.entryDate < $1.entryDate }
            .suffix(maxEntriesForContext)
        let meaningfulWeeklyEntries = weeklyEntries.filter(\.hasMeaningfulContent)
        guard meaningfulWeeklyEntries.count >= ReviewInsightsCloudEligibility.minimumMeaningfulEntriesForCloudAI else {
            throw CloudReviewInsightsError.insufficientContext
        }

        let contexts = meaningfulWeeklyEntries.map(makeContextEntry)
        let rawPayload = try await callAPI(
            request: CloudReviewInsightsRequest(
                model: model,
                messages: [CloudReviewMessage(role: "user", content: prompt(for: contexts))],
                maxTokens: 350,
                temperature: 0.2
            )
        )
        let payload = sanitizer.sanitizePayload(rawPayload)
        try sanitizer.validateGroundedQuality(payload)
        let weeklyInsights = makeWeeklyInsights(from: payload)

        return ReviewInsights(
            source: .cloudAI,
            generatedAt: referenceDate,
            weekStart: weekRange.lowerBound,
            weekEnd: weekRange.upperBound,
            weeklyInsights: weeklyInsights,
            recurringGratitudes: payload.recurringGratitudes.map { .init(label: $0.label, count: $0.count) },
            recurringNeeds: payload.recurringNeeds.map { .init(label: $0.label, count: $0.count) },
            recurringPeople: payload.recurringPeople.map { .init(label: $0.label, count: $0.count) },
            resurfacingMessage: payload.resurfacingMessage,
            continuityPrompt: payload.continuityPrompt,
            narrativeSummary: payload.narrativeSummary
        )
    }

    private func makeWeeklyInsights(from payload: CloudReviewInsightsPayload) -> [ReviewWeeklyInsight] {
        let primaryTheme = payload.recurringNeeds.first?.label
            ?? payload.recurringPeople.first?.label
            ?? payload.recurringGratitudes.first?.label

        let firstInsight = ReviewWeeklyInsight(
            pattern: .recurringTheme,
            observation: payload.resurfacingMessage,
            action: payload.continuityPrompt,
            primaryTheme: primaryTheme,
            mentionCount: payload.recurringNeeds.first?.count
                ?? payload.recurringPeople.first?.count
                ?? payload.recurringGratitudes.first?.count,
            dayCount: nil
        )

        guard !payload.narrativeSummary.isEmpty else { return [firstInsight] }
        let secondInsight = ReviewWeeklyInsight(
            pattern: .continuityShift,
            observation: payload.narrativeSummary,
            action: nil,
            primaryTheme: primaryTheme,
            mentionCount: nil,
            dayCount: nil
        )
        return [firstInsight, secondInsight]
    }

    private func weekDateRange(containing date: Date, calendar: Calendar) -> Range<Date> {
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        let start = calendar.date(from: components) ?? calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 7, to: start) ?? start
        return start..<end
    }

    private func makeContextEntry(from entry: JournalEntry) -> CloudReviewContextEntry {
        CloudReviewContextEntry(
            date: entry.entryDate.formatted(date: .abbreviated, time: .omitted),
            gratitudes: (entry.gratitudes ?? []).map(\.fullText),
            needs: (entry.needs ?? []).map(\.fullText),
            people: (entry.people ?? []).map(\.fullText),
            readingNotes: entry.readingNotes,
            reflections: entry.reflections
        )
    }

    private func prompt(for entries: [CloudReviewContextEntry]) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = (try? encoder.encode(entries)) ?? Data("[]".utf8)
        let contextText = String(data: data, encoding: .utf8) ?? "[]"

        switch resolvedPromptLanguage {
        case .simplifiedChinese:
            return promptSimplifiedChinese(contextText: contextText)
        case .english, .automatic:
            return promptEnglish(contextText: contextText)
        }
    }

    private var resolvedPromptLanguage: CloudReviewInsightsPromptLanguage {
        switch promptLanguage {
        case .automatic:
            return Self.appUsesSimplifiedChinese ? .simplifiedChinese : .english
        case .english, .simplifiedChinese:
            return promptLanguage
        }
    }

    /// Matches the app bundle’s active localization (same idea as UI language).
    private static var appUsesSimplifiedChinese: Bool {
        guard let preferred = Bundle.main.preferredLocalizations.first else {
            return false
        }
        return preferred == "zh-Hans" || preferred.hasPrefix("zh-Hans")
    }

    private func promptEnglish(contextText: String) -> String {
        """
        You are generating weekly journaling insights for a calm guided reflection app.
        Analyze this week's entries and return STRICT JSON with this shape:
        {
          "narrativeSummary": "string",
          "resurfacingMessage": "string",
          "continuityPrompt": "string",
          "recurringGratitudes": [{"label":"string","count":number}],
          "recurringNeeds": [{"label":"string","count":number}],
          "recurringPeople": [{"label":"string","count":number}]
        }

        Rules:
        - Keep tone gentle and non-judgmental.
        - Ground messages in the provided week context. Avoid generic wellness phrases.
        - Prefer one concrete, calm link between two recurring signals when evidence supports it.
        - Do not invent connections the entries do not support.
        - If recurring themes exist, reference at least one concrete theme label in narrativeSummary.
        - continuityPrompt must be a specific follow-up question tied to the week's themes.
        - Keep each message under 160 characters.
        - Return at most 3 items per recurring list.
        - Counts must be positive integers.
        - Output ONLY valid JSON; no markdown or prose.

        Weekly context:
        \(contextText)
        """
    }

    private func promptSimplifiedChinese(contextText: String) -> String {
        """
        你在为 App「感恩记」的「回顾」准备本周小结：语气安静、温暖，不要让人有压力。
        请结合下方本周记录，只输出符合下列结构的 JSON（结构严格；键名用英文，方便程序解析）：
        {
          "narrativeSummary": "string",
          "resurfacingMessage": "string",
          "continuityPrompt": "string",
          "recurringGratitudes": [{"label":"string","count":number}],
          "recurringNeeds": [{"label":"string","count":number}],
          "recurringPeople": [{"label":"string","count":number}]
        }

        要求：
        - 温柔、不评判。
        - 紧扣下方记录，别写空洞的励志话或养生套话。
        - 如果本周确实反复出现某些内容，可以用一句简短、具体的话，把两件事轻轻连起来（例如某件感恩的事、某件需要的事、某位牵挂的人）；不要臆测记录里没出现的事。
        - 若有重复主题，`narrativeSummary` 里至少要点到其中一条，说法尽量贴近用户原文或自然归纳。
        - `continuityPrompt` 只能是一句具体的追问，和本周内容有关。
        - `narrativeSummary`、`resurfacingMessage`、`continuityPrompt` 这三段正文用简体中文。
        - 每段正文不超过 160 个字。
        - `recurringGratitudes`、`recurringNeeds`、`recurringPeople` 每个列表最多 3 条；`count` 为正整数。
        - 只输出合法 JSON，不要用 markdown 代码块，不要加任何前言或后记。

        下方是本周记录：
        \(contextText)
        """
    }

    private func callAPI(request: CloudReviewInsightsRequest) async throws -> CloudReviewInsightsPayload {
        guard let url = URL(string: "\(baseURL)/chat/completions") else {
            throw CloudReviewInsightsError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.timeoutInterval = 15
        urlRequest.httpBody = try JSONEncoder().encode(request)

        let (data, response) = try await urlSession.data(for: urlRequest)
        guard let http = response as? HTTPURLResponse else {
            throw CloudReviewInsightsError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            throw CloudReviewInsightsError.httpError(statusCode: http.statusCode)
        }

        let responseBody = try JSONDecoder().decode(CloudReviewInsightsResponse.self, from: data)
        guard let content = responseBody.choices.first?.message.content else {
            throw CloudReviewInsightsError.missingContent
        }

        let parsedData = Data(sanitizer.extractJSONPayload(from: content).utf8)
        do {
            return try JSONDecoder().decode(CloudReviewInsightsPayload.self, from: parsedData)
        } catch {
            throw CloudReviewInsightsError.invalidPayload
        }
    }
}

private struct CloudReviewInsightsRequest: Encodable {
    let model: String
    let messages: [CloudReviewMessage]
    let maxTokens: Int
    let temperature: Double

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case maxTokens = "max_tokens"
        case temperature
    }
}

private struct CloudReviewMessage: Codable {
    let role: String
    let content: String
}

private struct CloudReviewInsightsResponse: Decodable {
    let choices: [CloudReviewChoice]
}

private struct CloudReviewChoice: Decodable {
    let message: CloudReviewResponseMessage
}

private struct CloudReviewResponseMessage: Decodable {
    let content: String
}

private struct CloudReviewContextEntry: Encodable {
    let date: String
    let gratitudes: [String]
    let needs: [String]
    let people: [String]
    let readingNotes: String
    let reflections: String
}

struct CloudReviewInsightsPayload: Decodable {
    let narrativeSummary: String
    let resurfacingMessage: String
    let continuityPrompt: String
    let recurringGratitudes: [CloudReviewTheme]
    let recurringNeeds: [CloudReviewTheme]
    let recurringPeople: [CloudReviewTheme]
}

struct CloudReviewTheme: Decodable {
    let label: String
    let count: Int
}

enum CloudReviewInsightsError: Error, Equatable {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    case missingContent
    case invalidPayload
    case insufficientContext
    case failedQualityGate
}
