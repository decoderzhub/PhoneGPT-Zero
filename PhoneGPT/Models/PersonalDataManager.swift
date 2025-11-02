import Foundation
import SwiftUI
import UniformTypeIdentifiers
import NaturalLanguage
import PDFKit
import CoreGraphics

class PersonalDataManager: NSObject, ObservableObject {
    @Published var indexedDocuments: Int = 0
    @Published var isIndexing = false
    
    private var vectorDB: [DocumentEmbedding] = []
    // Use sentence embeddings for better semantic understanding
    private let embedder = NLEmbedding.sentenceEmbedding(for: .english)
    private let embeddingDimension = 768 // Apple's sentence embedding dimension

    // Grammar Arithmetic Layer for fluent summaries
    private let grammarRefiner = GrammarRefiner()
    
    struct DocumentEmbedding {
        let content: String
        let source: String
        let embedding: [Float]
        let metadata: [String: Any] = [:]
    }

    // Type alias for better semantic naming
    typealias VectorDocument = DocumentEmbedding
    
    override init() {
        super.init()

        // Verify semantic embedding availability
        if embedder != nil {
            print("✅ Semantic embeddings initialized (NLEmbedding)")
            // Test embedding to get actual dimension
            if let testVec = embedder?.vector(for: "test") {
                print("   📊 Embedding dimension: \(testVec.count)")
            }
        } else {
            print("⚠️ Semantic embeddings unavailable - using hash-based fallback")
        }

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
    
    // MARK: - DOCX Text Extraction

    private func extractTextFromDOCX(at url: URL) -> String? {
        guard let data = try? Data(contentsOf: url) else {
            print("❌ Could not read DOCX file")
            return nil
        }

        // Try NSAttributedString first (works for some DOCX files)
        if let attributedString = try? NSAttributedString(
            data: data,
            options: [.documentType: NSAttributedString.DocumentType.rtf],
            documentAttributes: nil
        ) {
            let text = attributedString.string
            if !text.isEmpty && !text.contains("�") {
                print("✅ Extracted text using NSAttributedString")
                return text
            }
        }

        // Fallback: Manual ZIP extraction
        return extractTextFromDOCXManually(data: data)
    }

    private func extractTextFromDOCXManually(data: Data) -> String? {
        print("⚠️ DOCX extraction unavailable - iOS doesn't support native ZIP extraction")
        print("   Suggestion: Convert DOCX to PDF or TXT for better compatibility")
        return nil
    }

    private func parseTextFromDocumentXML(_ xml: String) -> String {
        // Extract text from <w:t> tags
        var text = ""
        var insideTextTag = false
        var currentText = ""

        let scanner = Scanner(string: xml)

        while !scanner.isAtEnd {
            if scanner.scanUpToString("<w:t") != nil {
                if scanner.scanString("<w:t") != nil {
                    // Skip attributes
                    _ = scanner.scanUpToString(">")
                    _ = scanner.scanString(">")

                    // Get text content
                    if let content = scanner.scanUpToString("</w:t>") {
                        text += content
                    }
                    _ = scanner.scanString("</w:t>")
                }
            }
        }

        // Clean up the text
        let cleanedText = text
            .replacingOccurrences(of: "\n+", with: "\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return cleanedText
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
            return nil
            
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
    
    // MARK: - Semantic Embeddings with NLEmbedding

    private func createEmbedding(for text: String) -> [Float] {
        // Try to use Apple's semantic sentence embeddings
        if let semanticEmbedder = embedder,
           let vector = semanticEmbedder.vector(for: text) {
            // NLEmbedding returns normalized vectors already
            print("🧠 Using semantic embedding (dim: \(vector.count))")
            return vector.map { Float($0) }
        }

        // Fallback to hash-based embeddings if NLEmbedding unavailable
        print("⚠️ Falling back to hash-based embedding")
        return createHashBasedEmbedding(for: text)
    }

    // Legacy hash-based embedding (fallback)
    private func createHashBasedEmbedding(for text: String) -> [Float] {
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
    
    // MARK: - Semantic Search

    func search(query: String, topK: Int = 3) -> [DocumentEmbedding] {
        guard !vectorDB.isEmpty else { return [] }

        let queryEmbedding = createEmbedding(for: query)

        print("🔍 Searching \(vectorDB.count) documents with semantic similarity")
        print("   Query: \"\(query.prefix(50))...\"")
        print("   Embedding dim: \(queryEmbedding.count)")

        let scores = vectorDB.map { doc in
            (doc, cosineSimilarity(queryEmbedding, doc.embedding))
        }

        let topResults = scores.sorted { $0.1 > $1.1 }
            .prefix(topK)

        // Log top matches for debugging
        for (idx, result) in topResults.enumerated() {
            let preview = result.0.content.prefix(60)
            print("   [\(idx+1)] Score: \(String(format: "%.3f", result.1)) - \"\(preview)...\"")
        }

        return topResults.map { $0.0 }
    }
    
    private func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count else {
            print("⚠️ Embedding dimension mismatch: \(a.count) vs \(b.count)")
            return 0
        }
        
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

        var context = ""
        for doc in relevantDocs {
            context += "From \(doc.source):\n\(doc.content)\n\n"
        }

        return context
    }

    /// Summarizes documents naturally using extractive + reformulation techniques
    func summarizeDocuments(_ docs: [VectorDocument], for query: String) -> String {
        let queryLower = query.lowercased()

        guard !docs.isEmpty else {
            return "No relevant documents found."
        }

        // Extract query keywords for relevance scoring
        let queryWords = Set(queryLower.components(separatedBy: .whitespacesAndNewlines)
            .filter { $0.count > 3 })

        // Score and rank sentences from documents
        var scoredSentences: [(sentence: String, score: Float, source: String)] = []

        for doc in docs {
            let sentences = doc.content.components(separatedBy: CharacterSet(charactersIn: ".!?"))
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { $0.count > 20 }

            for sentence in sentences {
                let sentenceLower = sentence.lowercased()
                let sentenceWords = Set(sentenceLower.components(separatedBy: .whitespacesAndNewlines))

                // Calculate relevance score based on query word overlap
                let overlap = queryWords.intersection(sentenceWords)
                let score = Float(overlap.count) / Float(max(queryWords.count, 1))

                // Also consider position (earlier sentences often more important)
                let positionBonus: Float = sentences.firstIndex(of: sentence) == 0 ? 0.2 : 0.0

                scoredSentences.append((
                    sentence: sentence,
                    score: score + positionBonus,
                    source: doc.source
                ))
            }
        }

        // Sort by relevance and take top sentences
        let topSentences = scoredSentences
            .sorted { $0.score > $1.score }
            .prefix(3)

        // Build natural summary
        var summary = ""
        var currentSource = ""

        for item in topSentences where item.score > 0 {
            if item.source != currentSource {
                if !summary.isEmpty {
                    summary += "\n\n"
                }
                summary += "From \(item.source):\n"
                currentSource = item.source
            }
            summary += "• \(item.sentence).\n"
        }

        let rawSummary = summary.isEmpty ? "I couldn't find specific information matching your query." : summary

        // Apply grammar arithmetic for fluent output
        let refinedSummary = grammarRefiner.refineForContext(rawSummary, query: query)

        print("📝 Summary refined for query: \"\(query.prefix(40))...\"")
        print("   Fluency score: \(grammarRefiner.fluencyScore(refinedSummary))")

        return refinedSummary
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
