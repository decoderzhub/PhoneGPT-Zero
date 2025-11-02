//
//  DocumentService.swift
//  PhoneGPT
//
//  Created by Darin Manley on 11/2/25.
//

import Foundation
import NaturalLanguage
import UniformTypeIdentifiers
import PDFKit
import ZIPFoundation

@MainActor
class DocumentService: ObservableObject {
    private let databaseService: DatabaseService

    nonisolated init(databaseService: DatabaseService) {
        self.databaseService = databaseService
    }

    func importDocument(url: URL, to session: ChatSession) async throws -> ImportedDocument {
        // When using UIDocumentPickerViewController with asCopy: true,
        // the file is already in our app's Inbox and doesn't need
        // security-scoped resource access
        let needsSecurityScope = !url.path.contains("/tmp/") && !url.path.contains("/Inbox/")
        
        if needsSecurityScope {
            guard url.startAccessingSecurityScopedResource() else {
                print("❌ Failed to access security-scoped resource: \(url.lastPathComponent)")
                throw DocumentError.accessDenied
            }
            defer { url.stopAccessingSecurityScopedResource() }
        } else {
            print("✅ File is in app container, no security scope needed")
        }

        let fileName = url.lastPathComponent
        let fileExtension = url.pathExtension.lowercased()
        
        print("📄 Importing \(fileExtension) file: \(fileName)")
        print("   Path: \(url.path)")
        
        // Extract text based on file type
        let content: String
        switch fileExtension {
        case "pdf":
            content = try extractTextFromPDF(at: url)
        case "docx":
            content = try extractTextFromDOCX(at: url)
        case "doc":
            content = try extractTextFromDOC(at: url)
        case "txt", "text", "md":
            content = try String(contentsOf: url, encoding: .utf8)
        case "rtf", "rtfd":
            content = try extractTextFromRTF(at: url)
        case "html", "htm":
            content = try extractTextFromHTML(at: url)
        default:
            // Try to read as plain text
            content = try String(contentsOf: url, encoding: .utf8)
        }
        
        guard !content.isEmpty else {
            throw DocumentError.emptyDocument
        }
        
        print("✅ Extracted \(content.count) characters from \(fileName)")

        let document = databaseService.importDocument(to: session, fileName: fileName, content: content)

        try await generateEmbeddings(for: document)

        return document
    }
    
    // MARK: - PDF Extraction
    
    private func extractTextFromPDF(at url: URL) throws -> String {
        guard let pdf = PDFDocument(url: url) else {
            throw DocumentError.invalidFormat
        }
        
        var fullText = ""
        for pageNum in 0..<pdf.pageCount {
            if let page = pdf.page(at: pageNum),
               let pageContent = page.string {
                fullText += pageContent + "\n"
            }
        }
        
        guard !fullText.isEmpty else {
            throw DocumentError.emptyDocument
        }
        
        return fullText
    }
    
    // MARK: - DOCX Extraction
    
    private func extractTextFromDOCX(at url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        
        // Try NSAttributedString first (works for some DOCX files)
        if let attributedString = try? NSAttributedString(
            data: data,
            options: [.documentType: NSAttributedString.DocumentType.rtf],
            documentAttributes: nil
        ) {
            let text = attributedString.string
            if !text.isEmpty && !text.contains("�") {
                return text
            }
        }
        
        // Fallback: Manual ZIP extraction
        return try extractTextFromDOCXManually(data: data)
    }
    
    private func extractTextFromDOCXManually(data: Data) throws -> String {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("zip")
        
        let unzipDestination = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        
        defer {
            try? FileManager.default.removeItem(at: tempURL)
            try? FileManager.default.removeItem(at: unzipDestination)
        }
        
        try data.write(to: tempURL)
        try FileManager.default.createDirectory(at: unzipDestination, withIntermediateDirectories: true)
        try FileManager.default.unzipItem(at: tempURL, to: unzipDestination)
        
        let documentXMLPath = unzipDestination.appendingPathComponent("word/document.xml")
        
        guard let xmlString = try? String(contentsOf: documentXMLPath, encoding: .utf8) else {
            throw DocumentError.invalidFormat
        }
        
        let extractedText = parseTextFromDocumentXML(xmlString)
        
        guard !extractedText.isEmpty else {
            throw DocumentError.emptyDocument
        }
        
        return extractedText
    }
    
    private func parseTextFromDocumentXML(_ xml: String) -> String {
        var text = ""
        let scanner = Scanner(string: xml)
        
        while !scanner.isAtEnd {
            if scanner.scanUpToString("<w:t") != nil {
                if scanner.scanString("<w:t") != nil {
                    _ = scanner.scanUpToString(">")
                    _ = scanner.scanString(">")
                    
                    if let content = scanner.scanUpToString("</w:t>") {
                        text += content
                    }
                    _ = scanner.scanString("</w:t>")
                }
            }
        }
        
        return text
            .replacingOccurrences(of: "\n+", with: "\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - DOC Extraction
    
    private func extractTextFromDOC(at url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        
        guard let attributedString = try? NSAttributedString(
            data: data,
            options: [.documentType: NSAttributedString.DocumentType.rtf],
            documentAttributes: nil
        ) else {
            throw DocumentError.invalidFormat
        }
        
        return attributedString.string
    }
    
    // MARK: - RTF Extraction
    
    private func extractTextFromRTF(at url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        
        guard let attributedString = try? NSAttributedString(
            data: data,
            options: [.documentType: NSAttributedString.DocumentType.rtf],
            documentAttributes: nil
        ) else {
            throw DocumentError.invalidFormat
        }
        
        return attributedString.string
    }
    
    // MARK: - HTML Extraction
    
    private func extractTextFromHTML(at url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        
        guard let attributedString = try? NSAttributedString(
            data: data,
            options: [
                .documentType: NSAttributedString.DocumentType.html,
                .characterEncoding: String.Encoding.utf8.rawValue
            ],
            documentAttributes: nil
        ) else {
            throw DocumentError.invalidFormat
        }
        
        return attributedString.string
    }

    private func generateEmbeddings(for document: ImportedDocument) async throws {
        guard let content = document.content else { return }

        let chunks = chunkText(content, maxChunkSize: 500)

        if #available(iOS 17.0, *) {
            let embedding = NLEmbedding.sentenceEmbedding(for: .english)

            for (index, chunk) in chunks.enumerated() {
                if let vector = embedding?.vector(for: chunk) {
                    let floatVector = vector.map { Float($0) }
                    _ = databaseService.addEmbedding(
                        to: document,
                        chunkText: chunk,
                        embedding: floatVector,
                        chunkIndex: index
                    )
                }
            }
        } else {
            for (index, chunk) in chunks.enumerated() {
                let pseudoEmbedding = chunk.utf8.prefix(384).map { Float($0) / 255.0 }
                _ = databaseService.addEmbedding(
                    to: document,
                    chunkText: chunk,
                    embedding: Array(pseudoEmbedding),
                    chunkIndex: index
                )
            }
        }
    }

    func searchDocuments(query: String, session: ChatSession, topK: Int = 3) -> [String] {
        let documents = databaseService.fetchDocuments(for: session)

        guard !documents.isEmpty else {
            print("⚠️ No documents found for session")
            return []
        }
        
        print("🔍 Searching \(documents.count) documents for: \"\(query)\"")

        var allChunks: [(chunk: String, similarity: Float)] = []

        if #available(iOS 17.0, *) {
            guard let embedding = NLEmbedding.sentenceEmbedding(for: .english),
                  let queryVector = embedding.vector(for: query) else {
                print("⚠️ Failed to create query embedding")
                return []
            }

            let floatQueryVector = queryVector.map { Float($0) }

            for document in documents {
                let embeddings = databaseService.fetchEmbeddings(for: document)
                print("   📄 \(document.fileName ?? "Unknown"): \(embeddings.count) chunks")

                for embeddingEntity in embeddings {
                    guard let storedVector = embeddingEntity.embedding as? [Float],
                          let chunkText = embeddingEntity.chunkText else { continue }

                    let similarity = cosineSimilarity(floatQueryVector, storedVector)
                    allChunks.append((chunkText, similarity))
                }
            }
        } else {
            for document in documents {
                guard let content = document.content else { continue }
                let chunks = chunkText(content, maxChunkSize: 500)

                for chunk in chunks {
                    let similarity = simpleSimilarity(query: query, text: chunk)
                    allChunks.append((chunk, similarity))
                }
            }
        }

        let sortedChunks = allChunks.sorted { $0.similarity > $1.similarity }
        let topResults = sortedChunks.prefix(topK)
        
        print("   ✅ Found \(topResults.count) relevant chunks")
        for (idx, result) in topResults.enumerated() {
            print("      [\(idx+1)] Score: \(String(format: "%.3f", result.similarity))")
        }
        
        return topResults.map { $0.chunk }
    }

    private func chunkText(_ text: String, maxChunkSize: Int) -> [String] {
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var chunks: [String] = []
        var currentChunk = ""

        for sentence in sentences {
            if currentChunk.count + sentence.count > maxChunkSize, !currentChunk.isEmpty {
                chunks.append(currentChunk)
                currentChunk = sentence
            } else {
                if !currentChunk.isEmpty {
                    currentChunk += ". "
                }
                currentChunk += sentence
            }
        }

        if !currentChunk.isEmpty {
            chunks.append(currentChunk)
        }

        return chunks
    }

    private func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count else { return 0 }

        let dotProduct = zip(a, b).map(*).reduce(0, +)
        let magnitudeA = sqrt(a.map { $0 * $0 }.reduce(0, +))
        let magnitudeB = sqrt(b.map { $0 * $0 }.reduce(0, +))

        guard magnitudeA > 0, magnitudeB > 0 else { return 0 }
        return dotProduct / (magnitudeA * magnitudeB)
    }

    private func simpleSimilarity(query: String, text: String) -> Float {
        let queryWords = Set(query.lowercased().components(separatedBy: .whitespacesAndNewlines))
        let textWords = Set(text.lowercased().components(separatedBy: .whitespacesAndNewlines))

        let intersection = queryWords.intersection(textWords)
        let union = queryWords.union(textWords)

        guard !union.isEmpty else { return 0 }
        return Float(intersection.count) / Float(union.count)
    }
}

enum DocumentError: Error {
    case accessDenied
    case invalidFormat
    case encodingError
    case emptyDocument
}
