import Foundation
import NaturalLanguage

struct WeeklyInsightTextNormalizer {
    private let conceptEngine = ReviewThemeConceptEngine(map: ReviewCuratedThemeMap.defaultMap)

    func extractThemesFromText(_ text: String) -> [String] {
        distillConcepts(from: text, source: .reflections).map(\.displayLabel)
    }

    func distillConcepts(
        from text: String,
        source: ReviewThemeSourceCategory,
        maximumCount: Int = 3,
        highConfidenceOnly: Bool = true
    ) -> [ReviewDistilledConcept] {
        conceptEngine.distillConcepts(
            from: text,
            source: source,
            maximumCount: maximumCount,
            highConfidenceOnly: highConfidenceOnly
        )
    }

    func displayLabel(for canonicalConcept: String, source: ReviewThemeSourceCategory) -> String {
        conceptEngine.displayLabel(for: canonicalConcept, source: source)
    }

    func themesMatch(_ needKey: String, against gratitudeKeys: Set<String>) -> Bool {
        if gratitudeKeys.contains(needKey) {
            return true
        }

        for gratitudeKey in gratitudeKeys where overlapScore(between: needKey, and: gratitudeKey) >= 1 {
            return true
        }
        return false
    }

    func normalizeThemeLabel(_ value: String) -> String {
        let folded = value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
        let withoutSymbols = folded.replacingOccurrences(
            of: "[\\p{P}\\p{S}]+",
            with: " ",
            options: .regularExpression
        )
        let collapsedSpaces = withoutSymbols.replacingOccurrences(
            of: "\\s+",
            with: " ",
            options: .regularExpression
        )
        return trimmed(collapsedSpaces)
    }

    func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    fileprivate func containsHanCharacters(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            switch scalar.value {
            case 0x3400...0x4DBF,
                 0x4E00...0x9FFF,
                 0xF900...0xFAFF,
                 0x20000...0x2A6DF,
                 0x2A700...0x2B73F,
                 0x2B740...0x2B81F,
                 0x2B820...0x2CEAF,
                 0x2CEB0...0x2EBEF,
                 0x2F800...0x2FA1F:
                return true
            default:
                return false
            }
        }
    }

    fileprivate func isStopWord(_ normalizedToken: String) -> Bool {
        ReviewThemeConceptEngine.stopWords.contains(normalizedToken)
    }

    fileprivate func overlapScore(between lhs: String, and rhs: String) -> Int {
        let lhsTokens = Set(lhs.split(separator: " ").map(String.init).filter { $0.count >= 3 })
        let rhsTokens = Set(rhs.split(separator: " ").map(String.init).filter { $0.count >= 3 })
        if lhsTokens.isEmpty || rhsTokens.isEmpty {
            return 0
        }
        return lhsTokens.intersection(rhsTokens).count
    }
}

struct ReviewDistilledConcept: Equatable, Hashable, Sendable {
    let canonicalConcept: String
    let displayLabel: String
    let score: Int
}

// swiftlint:disable type_body_length
private struct ReviewThemeConceptEngine {
    /// Caps phrase n-gram mining so long chip text does not emit sentence-sized “themes.”
    private static let maxWordsForPhraseMining = 20

    static let stopWords: Set<String> = [
        "with", "from", "that", "this", "your", "have", "will", "about", "into", "after", "before",
        "today", "week", "really", "just", "very", "more", "need", "needs", "gratitude", "grateful",
        "thankful", "thanks", "thank", "prayer", "pray", "praying", "felt", "feeling", "feel", "make", "made",
        "good", "better", "best",
        "今天", "这个", "那个", "我们", "你们", "他们", "自己", "需要", "感恩", "感谢", "一些", "很多", "祷告"
    ]

    private let map: ReviewCuratedThemeMap

    init(map: ReviewCuratedThemeMap) {
        self.map = map
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    func distillConcepts(
        from text: String,
        source: ReviewThemeSourceCategory,
        maximumCount: Int,
        highConfidenceOnly: Bool
    ) -> [ReviewDistilledConcept] {
        let trimmedText = trimmed(text)
        guard !trimmedText.isEmpty else { return [] }

        let normalizedSurface = normalizeThemeLabel(trimmedText)
        guard !normalizedSurface.isEmpty else { return [] }

        var candidates: [String: Int] = [:]
        var canonicalOrder: [String: Int] = [:]
        var sequence = 0

        let curatedCandidates = curatedMatches(in: normalizedSurface, source: source)
        for candidate in curatedCandidates {
            let canonical = canonicalConcept(for: candidate, source: source)
            guard !isHardBanned(canonical) else { continue }
            let score = scoredCandidate(
                candidate: candidate,
                canonical: canonical,
                source: source,
                baseScore: 9
            )
            if score <= 0 { continue }
            candidates[canonical] = max(candidates[canonical] ?? 0, score)
            if canonicalOrder[canonical] == nil {
                canonicalOrder[canonical] = sequence
                sequence += 1
            }
        }

        let deterministicCandidates = deterministicCandidates(from: trimmedText, normalizedSurface: normalizedSurface)
        for candidate in deterministicCandidates {
            let canonical = canonicalConcept(for: candidate.token, source: source)
            guard !isHardBanned(canonical) else { continue }
            let score = scoredCandidate(
                candidate: candidate.token,
                canonical: canonical,
                source: source,
                baseScore: candidate.baseScore
            )
            if score <= 0 { continue }
            candidates[canonical] = max(candidates[canonical] ?? 0, score)
            if canonicalOrder[canonical] == nil {
                canonicalOrder[canonical] = sequence
                sequence += 1
            }
        }

        let threshold = highConfidenceOnly ? confidenceThreshold(for: source) : 3
        return candidates
            .compactMap { canonical, score -> ReviewDistilledConcept? in
                guard score >= threshold else { return nil }
                return ReviewDistilledConcept(
                    canonicalConcept: canonical,
                    displayLabel: displayLabel(for: canonical, source: source),
                    score: score
                )
            }
            .sorted { lhs, rhs in
                if lhs.score != rhs.score {
                    return lhs.score > rhs.score
                }
                let lhsOrder = canonicalOrder[lhs.canonicalConcept] ?? .max
                let rhsOrder = canonicalOrder[rhs.canonicalConcept] ?? .max
                if lhsOrder != rhsOrder {
                    return lhsOrder < rhsOrder
                }
                return lhs.canonicalConcept.localizedCaseInsensitiveCompare(rhs.canonicalConcept) == .orderedAscending
            }
            .prefix(maximumCount)
            .map { $0 }
    }

    func displayLabel(for canonicalConcept: String, source: ReviewThemeSourceCategory) -> String {
        if source == .people {
            return personDisplayLabel(from: canonicalConcept)
        }
        if let authored = map.canonicalDisplayLabels[canonicalConcept] {
            return authored
        }
        if containsHanCharacters(canonicalConcept) {
            return canonicalConcept
        }
        return canonicalConcept
            .split(separator: " ")
            .map { word in
                guard let first = word.first else { return String(word) }
                return String(first).uppercased() + String(word.dropFirst())
            }
            .joined(separator: " ")
    }

    private func confidenceThreshold(for source: ReviewThemeSourceCategory) -> Int {
        switch source {
        case .people:
            return 4
        case .gratitudes, .needs, .readingNotes, .reflections:
            return 5
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
    private func deterministicCandidates(
        from text: String,
        normalizedSurface: String
    ) -> [(token: String, baseScore: Int)] {
        var candidates: [(token: String, baseScore: Int)] = []

        let textRange = text.startIndex..<text.endIndex
        let tagger = NLTagger(tagSchemes: [.nameTypeOrLexicalClass])
        tagger.string = text
        if let language = NLLanguageRecognizer.dominantLanguage(for: text) {
            tagger.setLanguage(language, range: textRange)
        }

        let options: NLTagger.Options = [.joinNames, .omitWhitespace, .omitPunctuation]
        tagger.enumerateTags(
            in: textRange,
            unit: .word,
            scheme: .nameTypeOrLexicalClass,
            options: options
        ) { tag, tokenRange in
            guard let tag else { return true }
            switch tag {
            case .personalName:
                let token = normalizeThemeLabel(String(text[tokenRange]))
                if !token.isEmpty {
                    candidates.append((token: token, baseScore: 8))
                }
            case .noun, .organizationName, .placeName:
                let token = normalizeThemeLabel(String(text[tokenRange]))
                if shouldKeepDeterministicToken(token) {
                    candidates.append((token: token, baseScore: 6))
                }
            default:
                break
            }
            return true
        }

        let phraseTokens = normalizedSurface
            .split(separator: " ")
            .map(String.init)
            .prefix(Self.maxWordsForPhraseMining)
            .filter { shouldKeepDeterministicToken($0) }
        if !phraseTokens.isEmpty {
            for token in phraseTokens {
                candidates.append((token: token, baseScore: 4))
            }

            if phraseTokens.count > 1 {
                for size in 2...min(3, phraseTokens.count) {
                    for start in 0...(phraseTokens.count - size) {
                        let phrase = phraseTokens[start..<(start + size)].joined(separator: " ")
                        candidates.append((token: phrase, baseScore: 5 + size))
                    }
                }
            }
        }

        return candidates
    }

    private func shouldKeepDeterministicToken(_ token: String) -> Bool {
        guard !token.isEmpty else { return false }
        guard !isStopWord(token) else { return false }
        if containsHanCharacters(token) {
            return token.count >= 1
        }
        return token.count >= 3
    }

    private func curatedMatches(in normalizedSurface: String, source: ReviewThemeSourceCategory) -> [String] {
        var matches: [String] = []
        for alias in map.globalAliases.keys where containsAlias(alias, in: normalizedSurface) {
            matches.append(alias)
        }
        if let overrides = map.sectionOverrides[source] {
            for alias in overrides.keys where containsAlias(alias, in: normalizedSurface) {
                matches.append(alias)
            }
        }
        for alias in map.crossLanguageAliases.keys where containsAlias(alias, in: normalizedSurface) {
            matches.append(alias)
        }
        return matches
    }

    private func containsAlias(_ alias: String, in normalizedSurface: String) -> Bool {
        if containsHanCharacters(alias) {
            return normalizedSurface.contains(alias)
        }
        let paddedSurface = " \(normalizedSurface) "
        let paddedAlias = " \(alias) "
        return paddedSurface.contains(paddedAlias)
    }

    private func canonicalConcept(for candidate: String, source: ReviewThemeSourceCategory) -> String {
        let normalized = normalizeThemeLabel(candidate)
        guard !normalized.isEmpty else { return "" }

        if source == .people {
            if let personOverride = map.sectionOverrides[.people]?[normalized] {
                return personOverride
            }
            return normalizePersonLiteral(normalized)
        }

        if let override = map.sectionOverrides[source]?[normalized] {
            return override
        }
        if let mapped = map.globalAliases[normalized] {
            return mapped
        }
        if let mapped = map.crossLanguageAliases[normalized] {
            return mapped
        }
        return normalized
    }

    private func scoredCandidate(
        candidate: String,
        canonical: String,
        source: ReviewThemeSourceCategory,
        baseScore: Int
    ) -> Int {
        var score = baseScore
        let isMultiWord = canonical.split(separator: " ").count > 1 || containsHanCharacters(canonical)
        if isMultiWord {
            score += 2
        }
        if map.globalAliases[candidate] != nil
            || map.sectionOverrides[source]?[candidate] != nil
            || map.crossLanguageAliases[candidate] != nil {
            score += 4
        }
        if map.penalizedConcepts.contains(canonical) {
            score -= 3
        }
        if canonical.count < 3 && !containsHanCharacters(canonical) {
            score -= 3
        }
        if !isMultiWord && isStopWord(canonical) {
            score -= 4
        }
        return score
    }

    private func isHardBanned(_ canonical: String) -> Bool {
        map.hardBannedConcepts.contains(canonical)
    }

    private func normalizePersonLiteral(_ value: String) -> String {
        let collapsed = value.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return trimmed(collapsed)
    }

    private func personDisplayLabel(from canonical: String) -> String {
        if let authored = map.canonicalDisplayLabels[canonical] {
            return authored
        }
        if containsHanCharacters(canonical) {
            return canonical
        }
        return canonical
            .split(separator: " ")
            .map { token in
                guard let first = token.first else { return String(token) }
                return String(first).uppercased() + String(token.dropFirst())
            }
            .joined(separator: " ")
    }

    private func normalizeThemeLabel(_ value: String) -> String {
        let folded = value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
        let withoutSymbols = folded.replacingOccurrences(
            of: "[\\p{P}\\p{S}]+",
            with: " ",
            options: .regularExpression
        )
        let collapsedSpaces = withoutSymbols.replacingOccurrences(
            of: "\\s+",
            with: " ",
            options: .regularExpression
        )
        return trimmed(collapsedSpaces)
    }

    private func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func containsHanCharacters(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            switch scalar.value {
            case 0x3400...0x4DBF,
                 0x4E00...0x9FFF,
                 0xF900...0xFAFF,
                 0x20000...0x2A6DF,
                 0x2A700...0x2B73F,
                 0x2B740...0x2B81F,
                 0x2B820...0x2CEAF,
                 0x2CEB0...0x2EBEF,
                 0x2F800...0x2FA1F:
                return true
            default:
                return false
            }
        }
    }

    private func isStopWord(_ normalizedToken: String) -> Bool {
        Self.stopWords.contains(normalizedToken)
    }
}
// swiftlint:enable type_body_length
