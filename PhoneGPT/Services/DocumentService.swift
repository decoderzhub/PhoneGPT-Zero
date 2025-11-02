//
//  DocumentService.swift
//  PhoneGPT
//
//  Created by Darin Manley on 11/2/25.
//

import Foundation
import NaturalLanguage
import UniformTypeIdentifiers

@MainActor
class DocumentService: ObservableObject {
    private let databaseService: DatabaseService

    nonisolated init(databaseService: DatabaseService) {
        self.databaseService = databaseService
    }

    func importDocument(url: URL, to session: ChatSession) async throws -> ImportedDocument {
        guard url.startAccessingSecurityScopedResource() else {
            throw DocumentError.accessDenied
        }
        defer { url.stopAccessingSecurityScopedResource() }

        let content = try String(contentsOf: url, encoding: .utf8)
        let fileName = url.lastPathComponent

        let document = databaseService.importDocument(to: session, fileName: fileName, content: content)

        try await generateEmbeddings(for: document)

        return document
    }

    private func generateEmbeddings(for document: ImportedDocument) async throws {
        guard let content = document.content else { return }

        let chunks = chunkText(content, maxChunkSize: 500)

        if #available(iOS 17.0, *) {
            let embedding = NLEmbedding.sentenceEmbedding(for: .english)

            for (index, chunk) in chunks.enumerated() {
                if let vector = embedding?.vector(for: chunk) {
                    _ = databaseService.addEmbedding(
                        to: document,
                        chunkText: chunk,
                        embedding: vector,
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

        guard !documents.isEmpty else { return [] }

        var allChunks: [(chunk: String, similarity: Float)] = []

        if #available(iOS 17.0, *) {
            guard let embedding = NLEmbedding.sentenceEmbedding(for: .english),
                  let queryVector = embedding.vector(for: query) else {
                return []
            }

            for document in documents {
                let embeddings = databaseService.fetchEmbeddings(for: document)

                for embeddingEntity in embeddings {
                    guard let storedVector = embeddingEntity.embedding as? [Float],
                          let chunkText = embeddingEntity.chunkText else { continue }

                    let similarity = cosineSimilarity(queryVector, storedVector)
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
        return sortedChunks.prefix(topK).map { $0.chunk }
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
}
