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
        let weekRange = ReviewInsightsPeriod.currentPeriod(containing: referenceDate, calendar: calendar)
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

        // `narrativeSummary` maps to the Thinking panel on `ReviewSummaryCard`; keep a single `weeklyInsights`
        // row so the flat payload and this array stay aligned for Observation / Action (#80).
        return [firstInsight]
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
            switch AppInstructionLocale.preferred(bundle: Bundle.main) {
            case .english:
                return .english
            case .simplifiedChinese:
                return .simplifiedChinese
            }
        case .english, .simplifiedChinese:
            return promptLanguage
        }
    }

    private func promptEnglish(contextText: String) -> String {
        """
        You are generating journaling insights for a guided reflection app.
        Analyze the entries from the past seven days and return STRICT JSON with this shape:
        {
          "narrativeSummary": "string",
          "resurfacingMessage": "string",
          "continuityPrompt": "string",
          "recurringGratitudes": [{"label":"string","count":number}],
          "recurringNeeds": [{"label":"string","count":number}],
          "recurringPeople": [{"label":"string","count":number}]
        }

        Rules:
        - Do not judge or pressure the user. Ground every line in their entries.
        - Ground messages in the provided seven-day context. Avoid generic wellness phrases.
        - resurfacingMessage is Observation: factual resurfacing only (counts, who/what showed up).
        - Keep Observation free of therapy clichés or feelings interpretation.
        - narrativeSummary is Thinking: one sentence naming a relationship or pattern across signals.
        - Thinking must use different wording than resurfacingMessage; do not repeat the same counts or structure.
        - continuityPrompt is Action: one short, invitational follow-up question tied to those themes.
        - Prefer one concrete, calm link between two recurring signals when evidence supports it.
        - Do not invent connections the entries do not support.
        - If recurring themes exist, reference at least one concrete theme label in narrativeSummary.
        - continuityPrompt must be a specific follow-up question tied to recent themes in these entries.
        - Keep each message under 160 characters.
        - Return at most 3 items per recurring list.
        - Counts must be positive integers.
        - Output ONLY valid JSON; no markdown or prose.

        Entries from the past seven days:
        \(contextText)
        """
    }

    private func promptSimplifiedChinese(contextText: String) -> String {
        """
        你在为 App「感恩记」的「回顾」准备最近七天的小结：平实、不施压。
        请结合下方最近七天的记录，只输出符合下列结构的 JSON（结构严格；键名用英文，方便程序解析）：
        {
          "narrativeSummary": "string",
          "resurfacingMessage": "string",
          "continuityPrompt": "string",
          "recurringGratitudes": [{"label":"string","count":number}],
          "recurringNeeds": [{"label":"string","count":number}],
          "recurringPeople": [{"label":"string","count":number}]
        }

        要求：
        - 不评判、不施压；说法贴着记录走。
        - 紧扣下方记录，别写空洞的励志话或养生套话。
        - `resurfacingMessage` 只写「观察」：事实性复盘（频次、反复出现的人/事），不要心理诊断式措辞。
        - `narrativeSummary` 写「思考」：用**不同于** `resurfacingMessage` 的句式，点出信号之间的关系或模式；不要简单重复同一句话或同一组数字。
        - `continuityPrompt` 写「行动」：一句简短、可接住的追问。
        - 如果最近七天里确实反复出现某些内容，可以用一句简短、具体的话，把两件事连起来（例如某件感恩的事、某件需要的事、某位牵挂的人）；不要臆测记录里没出现的事。
        - 若有重复主题，`narrativeSummary` 里至少要点到其中一条，说法尽量贴近用户原文或自然归纳。
        - `continuityPrompt` 只能是一句具体的追问，和这些记录里的内容有关。
        - `narrativeSummary`、`resurfacingMessage`、`continuityPrompt` 这三段正文用简体中文。
        - 每段正文不超过 160 个字。
        - `recurringGratitudes`、`recurringNeeds`、`recurringPeople` 每个列表最多 3 条；`count` 为正整数。
        - 只输出合法 JSON，不要用 markdown 代码块，不要加任何前言或后记。

        下方是最近七天的记录：
        \(contextText)
        """
    }

    private func callAPI(
        request: CloudReviewInsightsRequest
    ) async throws -> CloudReviewInsightsPayload {
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

        let content = try decodeAssistantMessageContent(from: data)

        let parsedData = Data(sanitizer.extractJSONPayload(from: content).utf8)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        do {
            return try decoder.decode(CloudReviewInsightsPayload.self, from: parsedData)
        } catch {
            throw CloudReviewInsightsError.invalidPayload
        }
    }

    private func decodeAssistantMessageContent(from data: Data) throws -> String {
        let responseBody = try JSONDecoder().decode(CloudReviewInsightsResponse.self, from: data)
        guard let content = responseBody.choices.first?.message.content else {
            throw CloudReviewInsightsError.missingContent
        }
        return content
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

    enum CodingKeys: String, CodingKey {
        case narrativeSummary
        case resurfacingMessage
        case continuityPrompt
        case recurringGratitudes
        case recurringNeeds
        case recurringPeople
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        narrativeSummary = try container.decodeIfPresent(String.self, forKey: .narrativeSummary) ?? ""
        resurfacingMessage = try container.decodeIfPresent(String.self, forKey: .resurfacingMessage) ?? ""
        continuityPrompt = try container.decodeIfPresent(String.self, forKey: .continuityPrompt) ?? ""
        recurringGratitudes = try container.decodeIfPresent([CloudReviewTheme].self, forKey: .recurringGratitudes) ?? []
        recurringNeeds = try container.decodeIfPresent([CloudReviewTheme].self, forKey: .recurringNeeds) ?? []
        recurringPeople = try container.decodeIfPresent([CloudReviewTheme].self, forKey: .recurringPeople) ?? []
    }

    init(
        narrativeSummary: String,
        resurfacingMessage: String,
        continuityPrompt: String,
        recurringGratitudes: [CloudReviewTheme],
        recurringNeeds: [CloudReviewTheme],
        recurringPeople: [CloudReviewTheme]
    ) {
        self.narrativeSummary = narrativeSummary
        self.resurfacingMessage = resurfacingMessage
        self.continuityPrompt = continuityPrompt
        self.recurringGratitudes = recurringGratitudes
        self.recurringNeeds = recurringNeeds
        self.recurringPeople = recurringPeople
    }
}

struct CloudReviewTheme: Decodable {
    let label: String
    let count: Int

    enum CodingKeys: String, CodingKey {
        case label
        case count
    }

    init(label: String, count: Int) {
        self.label = label
        self.count = count
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawLabel = try container.decodeIfPresent(String.self, forKey: .label) ?? ""
        label = rawLabel
        if let intVal = try? container.decode(Int.self, forKey: .count) {
            count = max(0, intVal)
        } else if let doubleVal = try? container.decode(Double.self, forKey: .count) {
            count = max(0, Int(doubleVal.rounded()))
        } else if let strVal = try? container.decode(String.self, forKey: .count) {
            let trimmed = strVal.trimmingCharacters(in: .whitespacesAndNewlines)
            count = max(0, Int(trimmed) ?? 1)
        } else {
            count = 1
        }
    }
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
