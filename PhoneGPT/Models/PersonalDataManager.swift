import Foundation
import SwiftUI
import UniformTypeIdentifiers
import NaturalLanguage
import PDFKit
import CoreGraphics
import ZIPFoundation

class PersonalDataManager: NSObject, ObservableObject {
    @Published var indexedDocuments: Int = 0
    @Published var isIndexing = false
    
    private var vectorDB: [DocumentEmbedding] = []
    private let embedder = NLEmbedding.wordEmbedding(for: .english)
    
    struct DocumentEmbedding {
        let content: String
        let source: String
        let embedding: [Float]
        let metadata: [String: Any] = [:]
    }
    
    override init() {
        super.init()
        // REMOVED auto-loading - starts with empty database
        // loadDefaultDocuments() // <-- COMMENTED OUT
    }
    
    // MARK: - Reset Function (NEW)
    
    func resetAll() {
        print("🗑️ Resetting all documents and memory...")
        
        // Clear the entire vector database
        vectorDB.removeAll()
        
        // Reset the document count
        indexedDocuments = 0
        
        // Clear any cached data
        UserDefaults.standard.removeObject(forKey: "lastMessageHash")
        
        // Force UI update
        objectWillChange.send()
        
        print("✅ Reset complete. All documents and memory cleared.")
    }
    
    // MARK: - Document Picker with Multiple Types
    
    func pickDocuments() {
        print("📂 Opening document picker...")
        
        DispatchQueue.main.async {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let rootViewController = windowScene.windows.first?.rootViewController else {
                print("❌ Could not find root view controller")
                return
            }
            
            // Support multiple file types
            let supportedTypes: [UTType] = [
                .text,           // .txt files
                .plainText,      // Plain text
                .pdf,            // PDF files
                .rtf,            // Rich text
                .html,           // HTML files
                UTType(filenameExtension: "docx") ?? .data, // Word documents
                UTType(filenameExtension: "doc") ?? .data,  // Older Word
                UTType(filenameExtension: "md") ?? .text    // Markdown
            ]
            
            let picker = UIDocumentPickerViewController(forOpeningContentTypes: supportedTypes)
            picker.allowsMultipleSelection = true
            picker.delegate = self
            picker.shouldShowFileExtensions = true
            rootViewController.present(picker, animated: true)
        }
    }
    
    // MARK: - PDF Text Extraction
    
    private func extractTextFromPDF(at url: URL) -> String? {
        guard let pdf = PDFDocument(url: url) else {
            print("❌ Could not load PDF: \(url.lastPathComponent)")
            return nil
        }
        
        var fullText = ""
        for pageNum in 0..<pdf.pageCount {
            if let page = pdf.page(at: pageNum),
               let pageContent = page.string {
                fullText += pageContent + "\n"
            }
        }
        
        print("✅ Extracted \(fullText.count) characters from PDF")
        return fullText.isEmpty ? nil : fullText
    }
    
    // MARK: - DOCX Text Extraction with ZIPFoundation
    
    private func extractTextFromDOCX(at url: URL) -> String? {
        do {
            // Try to open as archive (DOCX is a ZIP file)
            guard let archive = Archive(url: url, accessMode: .read) else {
                print("❌ Could not open DOCX as archive")
                return extractTextFromDOCXFallback(at: url)
            }
            
            var extractedText = ""
            
            // Look for word/document.xml
            for entry in archive {
                if entry.path == "word/document.xml" || entry.path.contains("word/document.xml") {
                    var xmlData = Data()
                    _ = try archive.extract(entry) { data in
                        xmlData.append(data)
                    }
                    
                    // Parse XML to extract text
                    if let xmlString = String(data: xmlData, encoding: .utf8) {
                        extractedText = parseWordXML(xmlString)
                    }
                    break
                }
            }
            
            if !extractedText.isEmpty {
                print("✅ Extracted \(extractedText.count) characters from DOCX")
                return extractedText
            }
            
            // Fallback if no text found
            return extractTextFromDOCXFallback(at: url)
            
        } catch {
            print("❌ Error reading DOCX: \(error)")
            return extractTextFromDOCXFallback(at: url)
        }
    }
    
    // Parse Word XML to extract text
    private func parseWordXML(_ xml: String) -> String {
        var text = ""
        
        // Extract text from <w:t> tags (Word text elements)
        let pattern = "<w:t[^>]*>([^<]+)</w:t>"
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
            let matches = regex.matches(in: xml, range: NSRange(xml.startIndex..., in: xml))
            
            for match in matches {
                if let range = Range(match.range(at: 1), in: xml) {
                    text += String(xml[range]) + " "
                }
            }
        }
        
        // Clean up XML entities
        text = text.replacingOccurrences(of: "&amp;", with: "&")
        text = text.replacingOccurrences(of: "&lt;", with: "<")
        text = text.replacingOccurrences(of: "&gt;", with: ">")
        text = text.replacingOccurrences(of: "&quot;", with: "\"")
        text = text.replacingOccurrences(of: "&#39;", with: "'")
        text = text.replacingOccurrences(of: "&apos;", with: "'")
        
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // Fallback DOCX extraction
    private func extractTextFromDOCXFallback(at url: URL) -> String? {
        // Try to read any readable text from the file
        if let data = try? Data(contentsOf: url) {
            var extractedText = ""
            let bytes = [UInt8](data)
            var currentWord = ""
            
            for byte in bytes {
                if (byte >= 32 && byte <= 126) || byte == 10 || byte == 13 {
                    if let char = String(bytes: [byte], encoding: .ascii) {
                        currentWord += char
                    }
                } else {
                    if currentWord.count > 3 && !currentWord.contains("xml") && !currentWord.contains("\\") {
                        extractedText += currentWord + " "
                    }
                    currentWord = ""
                }
            }
            
            // Clean up
            let cleanedText = extractedText
                .components(separatedBy: .whitespacesAndNewlines)
                .filter { $0.count > 2 }
                .joined(separator: " ")
            
            if !cleanedText.isEmpty {
                print("⚠️ Used fallback extraction: \(cleanedText.prefix(100))...")
                return cleanedText
            }
        }
        
        return nil
    }
    
    // MARK: - Process Any Document Type
    
    private func processDocument(at url: URL) async -> String? {
        let fileExtension = url.pathExtension.lowercased()
        
        print("📄 Processing \(fileExtension) file: \(url.lastPathComponent)")
        
        switch fileExtension {
        case "txt", "text", "md":
            // Plain text files
            return try? String(contentsOf: url, encoding: .utf8)
            
        case "pdf":
            // PDF files
            return extractTextFromPDF(at: url)
            
        case "docx":
            // Word documents (new format)
            return extractTextFromDOCX(at: url)
            
        case "doc":
            // Older Word format - try as RTF
            if let data = try? Data(contentsOf: url),
               let attributedString = try? NSAttributedString(
                data: data,
                options: [.documentType: NSAttributedString.DocumentType.rtf],
                documentAttributes: nil
               ) {
                return attributedString.string
            }
            return extractTextFromDOCXFallback(at: url)
            
        case "rtf", "rtfd":
            // Rich text
            if let data = try? Data(contentsOf: url),
               let attributedString = try? NSAttributedString(
                data: data,
                options: [.documentType: NSAttributedString.DocumentType.rtf],
                documentAttributes: nil
               ) {
                return attributedString.string
            }
            
        case "html", "htm":
            // HTML files
            if let data = try? Data(contentsOf: url),
               let attributedString = try? NSAttributedString(
                data: data,
                options: [
                    .documentType: NSAttributedString.DocumentType.html,
                    .characterEncoding: String.Encoding.utf8.rawValue
                ],
                documentAttributes: nil
               ) {
                return attributedString.string
            }
            
        default:
            // Try to read as plain text
            return try? String(contentsOf: url, encoding: .utf8)
        }
        
        return nil
    }
    
    // MARK: - Default Documents (Only loads when explicitly called)
    
    func loadDefaultDocuments() {
        // First, clear any existing default documents
        vectorDB.removeAll { doc in
            doc.source == "Conversation Knowledge" ||
            doc.source == "Practical Skills" ||
            doc.source == "Quick Facts"
        }
        
        print("📚 Loading default documents...")
        
        let defaultDocs = [
            (
                title: "Conversation Knowledge",
                content: """
                Common greetings: Hello, Hi, Hey, Good morning, Good afternoon, Good evening.
                Polite responses: You're welcome, My pleasure, Happy to help, No problem, Anytime.
                Weather discussion: It's sunny, cloudy, rainy, snowy. Temperature is hot, warm, cool, cold.
                Time discussions: Morning is 6am-12pm, Afternoon is 12pm-6pm, Evening is 6pm-10pm.
                Asking for help: How can I assist you? What do you need help with? I'm here to help.
                Expressing gratitude: Thank you, Thanks, I appreciate it, Grateful for your help.
                """
            ),
            (
                title: "Practical Skills",
                content: """
                iPhone tips: Take screenshot with Volume Up + Side button. Force restart with Volume Up, Volume Down, hold Side button.
                Cooking basics: Boil water at 100°C. Simmer at 85-95°C. Room temperature is 20-25°C.
                Emergency numbers: 911 for emergencies in the US. Store emergency contacts in phone.
                First aid: Apply pressure to stop bleeding. Cool water for burns. CPR is chest compressions.
                Home maintenance: Change air filters monthly. Test smoke detectors. Clean gutters annually.
                Financial basics: Budget income minus expenses. Emergency fund 3-6 months. Pay yourself first.
                Exercise: 150 minutes moderate cardio weekly. Strength training 2x per week. Stay hydrated.
                Sleep hygiene: 7-9 hours nightly. Cool dark room. No screens before bed.
                """
            ),
            (
                title: "Quick Facts",
                content: """
                Science facts: Speed of light is 299,792,458 m/s. Gravity on Earth is 9.8 m/s². Water freezes at 0°C.
                Math basics: Pi is 3.14159. Circle area is πr². Pythagorean theorem is a²+b²=c².
                Geography: 7 continents, 5 oceans. Mount Everest is tallest mountain. Pacific is largest ocean.
                History: iPhone released 2007. Internet created 1969. World Wide Web created 1989.
                Fun facts: Octopi have 3 hearts. Bananas are berries. Sharks are older than trees.
                Conversions: 1 mile = 1.6 km. 1 pound = 0.45 kg. 1 gallon = 3.8 liters.
                """
            )
        ]
        
        Task {
            for doc in defaultDocs {
                await self.indexDocument(content: doc.content, source: doc.title)
            }
            
            await MainActor.run {
                self.indexedDocuments = self.vectorDB.count
                print("✅ Loaded \(self.indexedDocuments) default document chunks")
            }
        }
    }
    
    // MARK: - File System Access
    
    func indexDocumentsFromFiles() async {
        await MainActor.run { self.isIndexing = true }
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory,
                                                     in: .userDomainMask).first!
        
        print("📁 Searching for documents in: \(documentsPath.path)")
        
        do {
            let files = try FileManager.default.contentsOfDirectory(
                at: documentsPath,
                includingPropertiesForKeys: nil
            )
            
            print("📄 Found \(files.count) files")
            
            for file in files {
                print("  - Processing: \(file.lastPathComponent)")
                
                if let content = await processDocument(at: file) {
                    await indexDocument(content: content, source: file.lastPathComponent)
                    print("    ✅ Indexed")
                }
            }
        } catch {
            print("❌ Error reading documents: \(error)")
        }
        
        await MainActor.run {
            self.isIndexing = false
            self.indexedDocuments = self.vectorDB.count
            print("📊 Total indexed chunks: \(self.indexedDocuments)")
        }
    }
    
    // MARK: - Indexing
    
    private func indexDocument(content: String, source: String, metadata: [String: Any] = [:]) async {
        let chunks = chunkText(content, chunkSize: 200)
        
        for chunk in chunks {
            let embedding = createEmbedding(for: chunk)
            
            let docEmbedding = DocumentEmbedding(
                content: chunk,
                source: source,
                embedding: embedding
            )
            
            vectorDB.append(docEmbedding)
        }
    }
    
    private func createEmbedding(for text: String) -> [Float] {
        var embedding = Array(repeating: Float(0), count: 128)
        let words = text.lowercased().components(separatedBy: .whitespacesAndNewlines)
        
        for word in words {
            let hash = word.hashValue
            for i in 0..<128 {
                let shifted = hash &>> i
                embedding[i] += Float(shifted & 1) * 2 - 1
            }
        }
        
        let norm = sqrt(embedding.reduce(0) { $0 + $1 * $1 })
        if norm > 0 {
            embedding = embedding.map { $0 / norm }
        }
        
        return embedding
    }
    
    private func chunkText(_ text: String, chunkSize: Int) -> [String] {
        let words = text.components(separatedBy: .whitespacesAndNewlines)
        var chunks: [String] = []
        
        for i in stride(from: 0, to: words.count, by: chunkSize/2) {
            let chunk = words[i..<min(i + chunkSize, words.count)].joined(separator: " ")
            if !chunk.isEmpty {
                chunks.append(chunk)
            }
        }
        
        return chunks
    }
    
    // MARK: - Search
    
    func search(query: String, topK: Int = 3) -> [DocumentEmbedding] {
        guard !vectorDB.isEmpty else { return [] }
        
        let queryEmbedding = createEmbedding(for: query)
        
        let scores = vectorDB.map { doc in
            (doc, cosineSimilarity(queryEmbedding, doc.embedding))
        }
        
        return scores.sorted { $0.1 > $1.1 }
            .prefix(topK)
            .map { $0.0 }
    }
    
    private func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count else { return 0 }
        
        var dotProduct: Float = 0
        var normA: Float = 0
        var normB: Float = 0
        
        for i in 0..<a.count {
            dotProduct += a[i] * b[i]
            normA += a[i] * a[i]
            normB += b[i] * b[i]
        }
        
        let denominator = sqrt(normA) * sqrt(normB)
        return denominator > 0 ? dotProduct / denominator : 0
    }
    
    func buildContext(for query: String) -> String {
        let relevantDocs = search(query: query, topK: 3)

        guard !relevantDocs.isEmpty else {
            return ""
        }

        // Use intelligent summarization instead of raw dumps
        return summarizeDocuments(relevantDocs, for: query)
    }

    // MARK: - Intelligent Document Summarization

    /// Summarizes documents naturally using extractive + reformulation techniques
    private func summarizeDocuments(_ docs: [DocumentEmbedding], for query: String) -> String {
        let queryLower = query.lowercased()

        // Detect query intent
        let isAsking = queryLower.contains("what") || queryLower.contains("who") ||
                       queryLower.contains("where") || queryLower.contains("when") ||
                       queryLower.contains("how") || queryLower.contains("why")
        let wantsSummary = queryLower.contains("summarize") || queryLower.contains("summary") ||
                          queryLower.contains("overview") || queryLower.contains("key points")

        if wantsSummary {
            return generateNaturalSummary(from: docs)
        } else if isAsking {
            return generateNaturalAnswer(from: docs, for: query)
        } else {
            return generateContextualResponse(from: docs, for: query)
        }
    }

    /// Generate natural summary by extracting and reformulating key sentences
    private func generateNaturalSummary(from docs: [DocumentEmbedding]) -> String {
        // Extract key sentences from all docs
        var keySentences: [(sentence: String, score: Double)] = []

        for doc in docs {
            let sentences = extractSentences(from: doc.content)
            for sentence in sentences {
                let score = calculateSentenceImportance(sentence)
                if score > 0.3 { // Only include important sentences
                    keySentences.append((sentence, score))
                }
            }
        }

        // Sort by importance and take top sentences
        keySentences.sort { $0.score > $1.score }
        let topSentences = keySentences.prefix(5).map { $0.sentence }

        if topSentences.isEmpty {
            return docs.map { $0.content }.joined(separator: "\n\n")
        }

        // Reformulate naturally with templates
        var summary = "Here's what I found:\n\n"

        // Group related information
        let firstPoint = topSentences[0]
        summary += "• \(capitalizeFirst(firstPoint))\n"

        for sentence in topSentences.dropFirst() {
            let reformulated = reformulateSentence(sentence)
            summary += "• \(reformulated)\n"
        }

        // Add source attribution
        if docs.count == 1 {
            summary += "\n(from \(docs[0].source))"
        } else {
            summary += "\n(from \(docs.count) documents)"
        }

        return summary
    }

    /// Generate natural answer to specific questions
    private func generateNaturalAnswer(from docs: [DocumentEmbedding], for query: String) -> String {
        let queryKeywords = extractKeywords(from: query)

        // Find sentences containing query keywords
        var relevantSentences: [(sentence: String, relevance: Double)] = []

        for doc in docs {
            let sentences = extractSentences(from: doc.content)
            for sentence in sentences {
                let relevance = calculateRelevance(sentence: sentence, to: queryKeywords)
                if relevance > 0.4 {
                    relevantSentences.append((sentence, relevance))
                }
            }
        }

        relevantSentences.sort { $0.relevance > $1.relevance }

        guard let mostRelevant = relevantSentences.first else {
            // Fallback to summary
            return generateNaturalSummary(from: docs)
        }

        // Reformulate as natural answer
        let queryLower = query.lowercased()

        if queryLower.contains("what") {
            return reformulateAsDefinition(mostRelevant.sentence)
        } else if queryLower.contains("how") {
            return reformulateAsProcess(mostRelevant.sentence)
        } else if queryLower.contains("why") {
            return reformulateAsReason(mostRelevant.sentence)
        } else {
            return capitalizeFirst(mostRelevant.sentence)
        }
    }

    /// Generate contextual response
    private func generateContextualResponse(from docs: [DocumentEmbedding], for query: String) -> String {
        // Extract most relevant information
        let queryKeywords = extractKeywords(from: query)
        var relevantInfo: [String] = []

        for doc in docs {
            let sentences = extractSentences(from: doc.content)
            for sentence in sentences {
                let relevance = calculateRelevance(sentence: sentence, to: queryKeywords)
                if relevance > 0.5 {
                    relevantInfo.append(sentence)
                }
            }
        }

        if relevantInfo.isEmpty {
            relevantInfo = docs.map { $0.content }
        }

        // Combine naturally
        if relevantInfo.count == 1 {
            return capitalizeFirst(relevantInfo[0])
        } else {
            let combined = relevantInfo.prefix(3).map { reformulateSentence($0) }.joined(separator: " ")
            return capitalizeFirst(combined)
        }
    }

    // MARK: - Helper Functions for Natural Language Processing

    private func extractSentences(from text: String) -> [String] {
        // Split by sentence boundaries
        let pattern = "[.!?]+\\s+"
        let regex = try? NSRegularExpression(pattern: pattern)

        let range = NSRange(text.startIndex..., in: text)
        let sentences = regex?.matches(in: text, range: range).map { match -> String in
            let endIndex = text.index(text.startIndex, offsetBy: match.range.location)
            return String(text[..<endIndex])
        } ?? []

        // Fallback: split by periods
        if sentences.isEmpty {
            return text.components(separatedBy: ". ").filter { !$0.isEmpty }
        }

        return sentences.filter { $0.count > 20 } // Filter out short fragments
    }

    private func calculateSentenceImportance(_ sentence: String) -> Double {
        var score = 0.0
        let lower = sentence.lowercased()

        // Boost sentences with important indicators
        let importantWords = ["important", "key", "main", "primary", "essential", "critical",
                             "first", "second", "third", "finally", "conclusion", "summary"]
        for word in importantWords {
            if lower.contains(word) { score += 0.2 }
        }

        // Boost sentences with numbers/data
        if sentence.range(of: "\\d+", options: .regularExpression) != nil {
            score += 0.15
        }

        // Penalize very short or very long sentences
        let wordCount = sentence.components(separatedBy: .whitespaces).count
        if wordCount > 10 && wordCount < 30 {
            score += 0.1
        }

        return min(score, 1.0)
    }

    private func extractKeywords(from text: String) -> Set<String> {
        let stopWords: Set<String> = ["the", "a", "an", "and", "or", "but", "in", "on", "at",
                                      "to", "for", "of", "with", "by", "from", "is", "are",
                                      "was", "were", "what", "how", "why", "when", "where"]

        let words = text.lowercased()
            .components(separatedBy: .whitespaces)
            .filter { !stopWords.contains($0) && $0.count > 3 }

        return Set(words)
    }

    private func calculateRelevance(sentence: String, to keywords: Set<String>) -> Double {
        let sentenceWords = Set(sentence.lowercased().components(separatedBy: .whitespaces))
        let matches = keywords.intersection(sentenceWords)
        return Double(matches.count) / Double(max(keywords.count, 1))
    }

    private func reformulateSentence(_ sentence: String) -> String {
        var result = sentence.trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove redundant phrases
        let redundant = ["it is important to note that", "it should be noted that",
                        "as mentioned earlier", "as previously stated"]
        for phrase in redundant {
            result = result.replacingOccurrences(of: phrase, with: "", options: .caseInsensitive)
        }

        // Simplify complex structures
        result = result.replacingOccurrences(of: "in order to", with: "to")
        result = result.replacingOccurrences(of: "due to the fact that", with: "because")

        return capitalizeFirst(result.trimmingCharacters(in: .whitespaces))
    }

    private func reformulateAsDefinition(_ sentence: String) -> String {
        // Check if sentence already starts with subject
        if sentence.lowercased().starts(with: "it ") || sentence.lowercased().starts(with: "this ") {
            return capitalizeFirst(sentence)
        }
        return capitalizeFirst(sentence)
    }

    private func reformulateAsProcess(_ sentence: String) -> String {
        // Add process framing if not present
        let lower = sentence.lowercased()
        if !lower.contains("by") && !lower.contains("through") && !lower.contains("using") {
            return "This is done by \(sentence.prefix(1).lowercased() + sentence.dropFirst())"
        }
        return capitalizeFirst(sentence)
    }

    private func reformulateAsReason(_ sentence: String) -> String {
        // Add causal framing
        let lower = sentence.lowercased()
        if !lower.contains("because") && !lower.contains("due to") && !lower.contains("since") {
            return "This is because \(sentence.prefix(1).lowercased() + sentence.dropFirst())"
        }
        return capitalizeFirst(sentence)
    }

    private func capitalizeFirst(_ text: String) -> String {
        guard !text.isEmpty else { return text }
        return text.prefix(1).uppercased() + text.dropFirst()
    }
}

// MARK: - Document Picker Delegate

extension PersonalDataManager: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        print("📎 User selected \(urls.count) files")
        
        Task {
            await MainActor.run { self.isIndexing = true }
            
            for url in urls {
                print("📋 Processing: \(url.lastPathComponent)")
                
                guard url.startAccessingSecurityScopedResource() else {
                    print("❌ Could not access: \(url.lastPathComponent)")
                    continue
                }
                
                defer {
                    url.stopAccessingSecurityScopedResource()
                }
                
                // Process any document type
                if let content = await self.processDocument(at: url) {
                    await self.indexDocument(content: content, source: url.lastPathComponent)
                    print("✅ Successfully indexed: \(url.lastPathComponent)")
                } else {
                    print("⚠️ Could not extract text from: \(url.lastPathComponent)")
                }
            }
            
            await MainActor.run {
                self.isIndexing = false
                self.indexedDocuments = self.vectorDB.count
                print("📊 Total chunks indexed: \(self.indexedDocuments)")
            }
        }
    }
    
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        print("📎 Document picker cancelled")
    }
}
