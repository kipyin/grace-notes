import Foundation

/// Natural language for cloud Review insight *instructions* (not user-facing app strings).
enum CloudReviewInsightsPromptLanguage: Equatable, Sendable {
    /// `zh-Hans` when the app’s active localization is Simplified Chinese; otherwise English.
    case automatic
    case english
    case simplifiedChinese
}

// Prompt blocks are intentionally long; keep line breaks for translators and reviewers.
// swiftlint:disable line_length function_body_length
struct CloudReviewInsightsGenerator: ReviewInsightsGenerating {
    private let baseURL: String
    private let model: String
    private let apiKey: String
    private let urlSession: URLSession
    private let promptLanguage: CloudReviewInsightsPromptLanguage
    private let aggregatesBuilder = WeeklyReviewAggregatesBuilder()
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
        let previousPeriod = ReviewInsightsPeriod.previousPeriod(before: weekRange, calendar: calendar)
        let currentWeekEntries = entries
            .filter { weekRange.contains($0.entryDate) }
            .sorted { $0.entryDate < $1.entryDate }
        let previousWeekEntries = entries
            .filter { previousPeriod.contains($0.entryDate) }
            .sorted { $0.entryDate < $1.entryDate }
        let weeklyEntries = currentWeekEntries
            .suffix(maxEntriesForContext)
        let meaningfulWeeklyEntries = weeklyEntries.filter(\.hasMeaningfulContent)
        guard meaningfulWeeklyEntries.count >= ReviewInsightsCloudEligibility.minimumMeaningfulEntriesForCloudAI else {
            throw CloudReviewInsightsError.insufficientContext
        }
        let aggregates = aggregatesBuilder.build(
            currentPeriod: weekRange,
            currentWeekEntries: currentWeekEntries,
            previousWeekEntries: previousWeekEntries,
            calendar: calendar
        )
        let deviceRecurringLists = recurringLists(from: aggregates)

        let contexts = meaningfulWeeklyEntries.map(makeContextEntry)
        let typedRaw = try await callTypedInsightAPI(
            request: CloudReviewInsightsRequest(
                model: model,
                messages: [CloudReviewMessage(role: "user", content: prompt(for: contexts))],
                maxTokens: 600,
                temperature: 0.15
            )
        )
        guard !deviceRecurringLists.gratitudes.isEmpty
            || !deviceRecurringLists.needs.isEmpty
            || !deviceRecurringLists.people.isEmpty else {
            throw CloudReviewInsightsError.failedQualityGate
        }
        let resolved = try CloudStructuredInsightResolver.resolve(
            typedRaw,
            gratitudes: deviceRecurringLists.gratitudes,
            needs: deviceRecurringLists.needs,
            people: deviceRecurringLists.people
        )
        let rendered = CloudStructuredReviewInsightRenderer.makePayload(
            resolved: resolved,
            recurringGratitudes: deviceRecurringLists.gratitudes,
            recurringNeeds: deviceRecurringLists.needs,
            recurringPeople: deviceRecurringLists.people
        )
        let payload = sanitizer.sanitizeStructuredPayload(rendered)
        try sanitizer.validateGroundedQuality(payload)
        let weeklyInsights = makeWeeklyInsights(from: payload)

        return ReviewInsights(
            source: .cloudAI,
            presentationMode: aggregates.supportsInsightNarrative ? .insight : .statsFirst,
            generatedAt: referenceDate,
            weekStart: weekRange.lowerBound,
            weekEnd: weekRange.upperBound,
            weeklyInsights: weeklyInsights,
            recurringGratitudes: payload.recurringGratitudes.map { .init(label: $0.label, count: $0.count) },
            recurringNeeds: payload.recurringNeeds.map { .init(label: $0.label, count: $0.count) },
            recurringPeople: payload.recurringPeople.map { .init(label: $0.label, count: $0.count) },
            resurfacingMessage: payload.resurfacingMessage,
            continuityPrompt: payload.continuityPrompt,
            narrativeSummary: payload.narrativeSummary,
            weekStats: aggregates.stats,
            cloudSkippedReason: nil
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
        You are selecting one structured weekly insight for a guided reflection app.
        Analyze the entries from the past seven days and return STRICT JSON with exactly this shape:
        {
          "insightType": "cooccurrence" | "contrast" | "temporalShift" | "personThemePairing" | "dominantCategory",
          "primaryTheme": {"label":"string","category":"gratitudes"|"needs"|"people"},
          "secondaryTheme": {"label":"string","category":"gratitudes"|"needs"|"people"} | null,
          "evidenceDays": number | null,
          "recurringGratitudes": [{"label":"string","count":number}],
          "recurringNeeds": [{"label":"string","count":number}],
          "recurringPeople": [{"label":"string","count":number}]
        }

        The app renders user-facing Observation / Thinking / Action copy locally from your typed choice. Do not output narrativeSummary, resurfacingMessage, or continuityPrompt.

        insightType — pick the single best fit:
        - cooccurrence: two themes that tend to appear together; secondaryTheme required; categories may repeat or differ.
        - contrast: a recurring gratitude vs a recurring need; secondaryTheme required; categories must be gratitudes for one theme and needs for the other (order of primary/secondary may be either way).
        - temporalShift: one theme grows clearer in the second half of the week; secondaryTheme must be null; evidenceDays optional—if present, integer ≥ 2 for days of support.
        - personThemePairing: primaryTheme.category must be people; secondaryTheme required with category gratitudes or needs; person + theme co-occur in the week.
        - dominantCategory: the strongest single recurring theme; secondaryTheme null; primaryTheme points at that label and its category.

        recurring* lists: at most 3 items each; positive integer counts; labels must match short phrases distilled from the entries (same language as the journal text). Every label in primaryTheme and secondaryTheme must appear in the matching recurring list for that category.

        Shared rules:
        - Ground every label and count in the entry JSON; no invented people, habits, or goals.
        - No character judgments, therapy clichés, or motivational filler.
        - Output ONLY valid JSON; no markdown fences or prose outside the JSON object.

        Entries from the past seven days:
        \(contextText)
        """
    }

    private func promptSimplifiedChinese(contextText: String) -> String {
        """
        你在为 App「感恩记」的「回顾」从最近七天里**选定一种结构化洞察**：平实、可核对、不施压。
        请只输出符合下列结构的 JSON（键名保持英文，便于解析；label 正文与记录语言一致，通常为简体中文）：
        {
          "insightType": "cooccurrence" | "contrast" | "temporalShift" | "personThemePairing" | "dominantCategory",
          "primaryTheme": {"label":"string","category":"gratitudes"|"needs"|"people"},
          "secondaryTheme": {"label":"string","category":"gratitudes"|"needs"|"people"} | null,
          "evidenceDays": number | null,
          "recurringGratitudes": [{"label":"string","count":number}],
          "recurringNeeds": [{"label":"string","count":number}],
          "recurringPeople": [{"label":"string","count":number}]
        }

        App 会在本地根据你的结构化结果生成「观察 / 思考 / 行动」正文。**不要**输出 narrativeSummary、resurfacingMessage、continuityPrompt。

        insightType 含义（只选最贴切的一种）：
        - cooccurrence：两个主题常一起出现；必须有 secondaryTheme；类别可相同或不同。
        - contrast：一条重复感恩主题 vs 一条重复需要主题；必须有 secondaryTheme；两人分别为 gratitudes 与 needs（primary/secondary 顺序不限）。
        - temporalShift：同一主题在周内后段更明显；secondaryTheme 必须为 null；evidenceDays 可省略，若填写须为 ≥ 2 的整数。
        - personThemePairing：primaryTheme.category 必须是 people；secondaryTheme 必填且为 gratitudes 或 needs；人与该主题在周记录里常同现。
        - dominantCategory：本周最强的一条重复主题；secondaryTheme 为 null；primaryTheme 指向该标签及对应 category。

        recurring*：每类最多 3 条；count 为正整数；label 必须与条目原文短语一致。primaryTheme / secondaryTheme 里的每个 label 必须出现在对应 category 的 recurring 列表中。

        共用：所有标签与次数必须能从下方 JSON 记录核对；禁止臆测记录未出现的人或事；禁止心理诊断式与空洞励志套话。
        只输出合法 JSON，不要使用 markdown 代码块，不要加前言或后记。

        下方是最近七天的记录：
        \(contextText)
        """
    }

    private func callTypedInsightAPI(
        request: CloudReviewInsightsRequest
    ) async throws -> CloudTypedInsightAPIResponse {
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
            return try decoder.decode(CloudTypedInsightAPIResponse.self, from: parsedData)
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
// swiftlint:enable line_length function_body_length

private extension CloudReviewInsightsGenerator {
    func recurringLists(from aggregates: WeeklyReviewAggregates) -> CloudSanitizedRecurringThemeLists {
        CloudSanitizedRecurringThemeLists(
            gratitudes: aggregates.recurringGratitudes.map(makeCloudReviewTheme),
            needs: aggregates.recurringNeeds.map(makeCloudReviewTheme),
            people: aggregates.recurringPeople.map(makeCloudReviewTheme)
        )
    }

    func makeCloudReviewTheme(from theme: ReviewInsightTheme) -> CloudReviewTheme {
        CloudReviewTheme(label: theme.label, count: theme.count)
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

struct CloudReviewTheme: Decodable, Equatable {
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
