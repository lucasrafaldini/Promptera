import Foundation

/// Result of a fuzzy match: a relevance score plus the character offsets that matched.
public struct FuzzyMatch: Equatable, Sendable {
    public let score: Int
    /// Offsets measured in `Character`s of the original candidate string.
    public let matchedOffsets: [Int]

    public init(score: Int, matchedOffsets: [Int]) {
        self.score = score
        self.matchedOffsets = matchedOffsets
    }
}

/// Lightweight fzf-style subsequence matcher with word-boundary and consecutive bonuses.
public enum FuzzyMatcher {
    public static func match(query: String, in candidate: String) -> FuzzyMatch? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return FuzzyMatch(score: 0, matchedOffsets: []) }

        let foldedQuery = fold(trimmed)
        guard !foldedQuery.isEmpty else { return nil }

        let candidateCharacters = Array(candidate)
        var foldedCandidate: [Character] = []
        var originalIndex: [Int] = []
        foldedCandidate.reserveCapacity(candidateCharacters.count)
        originalIndex.reserveCapacity(candidateCharacters.count)

        for (index, character) in candidateCharacters.enumerated() {
            for foldedCharacter in fold(String(character)) {
                foldedCandidate.append(foldedCharacter)
                originalIndex.append(index)
            }
        }

        var matchedOffsets: [Int] = []
        var searchStart = 0
        var previousMatch: Int?
        var score = 0

        for queryCharacter in foldedQuery {
            var found: Int?
            var index = searchStart
            while index < foldedCandidate.count {
                if foldedCandidate[index] == queryCharacter {
                    found = index
                    break
                }
                index += 1
            }

            guard let matchIndex = found else { return nil }
            let characterOffset = originalIndex[matchIndex]
            matchedOffsets.append(characterOffset)

            score += 10
            if let previousMatch {
                if matchIndex == previousMatch + 1 {
                    score += 12
                } else {
                    score -= min(matchIndex - previousMatch - 1, 20)
                }
                let previousCharacterOffset = originalIndex[previousMatch]
                if characterOffset != previousCharacterOffset,
                   isBoundary(candidateCharacters[previousCharacterOffset]) {
                    score += 15
                }
            } else if characterOffset == 0 {
                score += 20
            } else if isBoundary(candidateCharacters[characterOffset - 1]) {
                score += 15
            }

            previousMatch = matchIndex
            searchStart = matchIndex + 1
        }

        let foldedCandidateString = String(foldedCandidate)
        let foldedQueryString = String(foldedQuery)
        if foldedCandidateString.contains(foldedQueryString) {
            score += 25
        }
        // Prefer shorter candidates when relevance is otherwise equal.
        score -= min(candidateCharacters.count / 80, 10)

        return FuzzyMatch(score: score, matchedOffsets: Array(Set(matchedOffsets)).sorted())
    }

    private static func fold(_ string: String) -> [Character] {
        Array(string.folding(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: Locale(identifier: "en_US_POSIX")
        ))
    }

    private static func isBoundary(_ character: Character) -> Bool {
        !character.isLetter && !character.isNumber
    }
}
