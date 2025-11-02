import Foundation
import NaturalLanguage

/// Grammar Arithmetic Layer for RAG responses
///
/// This lightweight NLG system polishes generated text using:
/// - Spacing and punctuation fixes
/// - Sentence capitalization
/// - Redundancy removal
/// - Grammar rules (no heavy LLM needed)
///
/// Think of it as "arithmetic on language" - simple, fast, on-device operations

struct GrammarRefiner {

    private let tagger = NLTagger(tagSchemes: [.lexicalClass, .nameType])

    // MARK: - Main Refinement Pipeline

    func refine(_ text: String) -> String {
        guard !text.isEmpty else { return text }

        var refined = text

        // Step 1: Fix spacing and punctuation
        refined = fixSpacing(refined)

        // Step 2: Capitalize sentences properly
        refined = capitalizeSentences(refined)

        // Step 3: Remove redundant phrases
        refined = deduplicatePhrases(refined)

        // Step 4: Ensure proper ending
        refined = ensureProperEnding(refined)

        // Step 5: Clean up extra whitespace
        refined = refined.trimmingCharacters(in: .whitespacesAndNewlines)

        return refined
    }

    // MARK: - Step 1: Fix Spacing

    private func fixSpacing(_ text: String) -> String {
        var fixed = text

        // Fix spacing before punctuation
        fixed = fixed.replacingOccurrences(of: " .", with: ".")
        fixed = fixed.replacingOccurrences(of: " ,", with: ",")
        fixed = fixed.replacingOccurrences(of: " !", with: "!")
        fixed = fixed.replacingOccurrences(of: " ?", with: "?")
        fixed = fixed.replacingOccurrences(of: " ;", with: ";")
        fixed = fixed.replacingOccurrences(of: " :", with: ":")

        // Fix spacing after punctuation
        fixed = fixed.replacingOccurrences(of: ".", with: ". ")
        fixed = fixed.replacingOccurrences(of: ",", with: ", ")
        fixed = fixed.replacingOccurrences(of: "!", with: "! ")
        fixed = fixed.replacingOccurrences(of: "?", with: "? ")

        // Clean up double spaces
        while fixed.contains("  ") {
            fixed = fixed.replacingOccurrences(of: "  ", with: " ")
        }

        // Fix multiple punctuation
        fixed = fixed.replacingOccurrences(of: ". .", with: ".")
        fixed = fixed.replacingOccurrences(of: ". ,", with: ".")
        fixed = fixed.replacingOccurrences(of: ", ,", with: ",")

        return fixed
    }

    // MARK: - Step 2: Capitalize Sentences

    private func capitalizeSentences(_ text: String) -> String {
        let sentenceEnders: Set<Character> = [".", "!", "?"]
        var result = ""
        var shouldCapitalize = true

        for char in text {
            if shouldCapitalize && char.isLetter {
                result.append(char.uppercased())
                shouldCapitalize = false
            } else {
                result.append(char)
                if sentenceEnders.contains(char) {
                    shouldCapitalize = true
                }
            }
        }

        return result
    }

    // MARK: - Step 3: Deduplicate Phrases

    private func deduplicatePhrases(_ text: String) -> String {
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        var seen = Set<String>()
        var unique: [String] = []

        for sentence in sentences {
            // Normalize for comparison (lowercase, remove punctuation)
            let normalized = sentence.lowercased()
                .components(separatedBy: .punctuationCharacters)
                .joined()
                .trimmingCharacters(in: .whitespaces)

            if !seen.contains(normalized) {
                seen.insert(normalized)
                unique.append(sentence)
            }
        }

        return unique.joined(separator: ". ")
    }

    // MARK: - Step 4: Ensure Proper Ending

    private func ensureProperEnding(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespaces)

        guard !trimmed.isEmpty else { return trimmed }

        let lastChar = trimmed.last!
        let properEndings: Set<Character> = [".", "!", "?"]

        if properEndings.contains(lastChar) {
            return trimmed
        }

        // Add period if missing
        return trimmed + "."
    }

    // MARK: - Advanced Grammar Arithmetic

    /// Uses NLTagger to improve fluency based on part-of-speech patterns
    func refineWithPOS(_ text: String) -> String {
        var refined = text

        // Set up tagger
        tagger.string = text

        // Find awkward patterns and fix them
        refined = fixDoubleArticles(refined)
        refined = fixRepeatedWords(refined)

        return refined
    }

    // MARK: - Pattern Fixes

    private func fixDoubleArticles(_ text: String) -> String {
        var fixed = text

        // Fix "a a", "the the", etc.
        let patterns = [
            ("a a ", "a "),
            ("an an ", "an "),
            ("the the ", "the "),
            ("A a ", "A "),
            ("An an ", "An "),
            ("The the ", "The ")
        ]

        for (pattern, replacement) in patterns {
            fixed = fixed.replacingOccurrences(of: pattern, with: replacement)
        }

        return fixed
    }

    private func fixRepeatedWords(_ text: String) -> String {
        let words = text.components(separatedBy: .whitespaces)
        var result: [String] = []
        var lastWord = ""

        for word in words {
            let normalized = word.lowercased()
                .trimmingCharacters(in: .punctuationCharacters)

            // Skip if same as previous word (but keep punctuation variations)
            if normalized != lastWord || word.count <= 2 {
                result.append(word)
                lastWord = normalized
            }
        }

        return result.joined(separator: " ")
    }

    // MARK: - Fluency Scoring (Optional Enhancement)

    /// Scores text fluency from 0.0 to 1.0 based on grammar rules
    func fluencyScore(_ text: String) -> Float {
        var score: Float = 1.0

        // Penalize for issues
        if !text.first!.isUppercase { score -= 0.1 }
        if ![".", "!", "?"].contains(String(text.last!)) { score -= 0.1 }
        if text.contains("  ") { score -= 0.1 }
        if text.contains(" .") || text.contains(" ,") { score -= 0.2 }

        // Check sentence variety
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?"))
        if sentences.count > 3 {
            let avgLength = Float(text.count) / Float(sentences.count)
            if avgLength < 10 { score -= 0.1 } // Too short
            if avgLength > 200 { score -= 0.1 } // Too long
        }

        return max(0, min(1, score))
    }

    // MARK: - Context-Aware Refinement

    /// Refines text based on query context
    func refineForContext(_ text: String, query: String) -> String {
        var refined = refine(text)

        // If query is a question, ensure answer format
        if query.hasSuffix("?") {
            refined = ensureAnswerFormat(refined, for: query)
        }

        return refined
    }

    private func ensureAnswerFormat(_ text: String, for query: String) -> String {
        // If text doesn't start with a direct answer, check if we can improve it
        let lowerText = text.lowercased()
        let lowerQuery = query.lowercased()

        // Question starters that might need "Yes" or "No" prefix
        let yesNoQuestions = ["is ", "are ", "do ", "does ", "can ", "will ", "should "]

        for starter in yesNoQuestions {
            if lowerQuery.starts(with: starter) {
                // Check if answer already starts with yes/no
                if !lowerText.starts(with: "yes") && !lowerText.starts(with: "no") {
                    // Text is fine as-is, descriptive answer
                    return text
                }
            }
        }

        return text
    }
}

// MARK: - String Extensions for Grammar Arithmetic

extension String {
    /// Quick fluency fix (lightweight version)
    func grammaticallyRefined() -> String {
        return GrammarRefiner().refine(self)
    }

    /// Check if string looks like a complete sentence
    var isCompleteSentence: Bool {
        let trimmed = self.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return false }

        let hasCapital = trimmed.first?.isUppercase ?? false
        let hasEnding = [".", "!", "?"].contains(String(trimmed.last!))
        let hasMinLength = trimmed.count >= 5

        return hasCapital && hasEnding && hasMinLength
    }
}
