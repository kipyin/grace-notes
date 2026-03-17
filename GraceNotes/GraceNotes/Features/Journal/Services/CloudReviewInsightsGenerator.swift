import Foundation

struct CloudReviewInsightsGenerator: ReviewInsightsGenerating {
    private let baseURL: String
    private let model: String
    private let apiKey: String
    private let urlSession: URLSession
    private let sanitizer = CloudReviewInsightsSanitizer()
    private let maxEntriesForContext = 14

    init(
        baseURL: String = "https://chat.cloudapi.vip/v1",
        model: String = "gpt-4o-mini",
        apiKey: String,
        urlSession: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.model = model
        self.apiKey = apiKey
        self.urlSession = urlSession
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

        let contexts = weeklyEntries.map(makeContextEntry)
        let payload = sanitizer.sanitizePayload(
            try await callAPI(
                request: CloudReviewInsightsRequest(
                    model: model,
                    messages: [CloudReviewMessage(role: "user", content: prompt(for: contexts))],
                    maxTokens: 350,
                    temperature: 0.2
                )
            )
        )

        return ReviewInsights(
            source: .cloudAI,
            generatedAt: referenceDate,
            weekStart: weekRange.lowerBound,
            weekEnd: weekRange.upperBound,
            recurringGratitudes: payload.recurringGratitudes.map { .init(label: $0.label, count: $0.count) },
            recurringNeeds: payload.recurringNeeds.map { .init(label: $0.label, count: $0.count) },
            recurringPeople: payload.recurringPeople.map { .init(label: $0.label, count: $0.count) },
            resurfacingMessage: payload.resurfacingMessage,
            continuityPrompt: payload.continuityPrompt,
            narrativeSummary: payload.narrativeSummary
        )
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
            gratitudes: entry.gratitudes.map(\.fullText),
            needs: entry.needs.map(\.fullText),
            people: entry.people.map(\.fullText),
            readingNotes: entry.readingNotes,
            reflections: entry.reflections
        )
    }

    private func prompt(for entries: [CloudReviewContextEntry]) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = (try? encoder.encode(entries)) ?? Data("[]".utf8)
        let contextText = String(data: data, encoding: .utf8) ?? "[]"

        return """
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

private enum CloudReviewInsightsError: Error {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    case missingContent
    case invalidPayload
}
