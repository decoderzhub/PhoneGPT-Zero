//
//  DatabaseService.swift
//  PhoneGPT
//
//  Created by Darin Manley on 11/2/25.
//

import Foundation
import CoreData

@MainActor
class DatabaseService: ObservableObject {
    private let persistenceController: PersistenceController
    private var viewContext: NSManagedObjectContext {
        persistenceController.container.viewContext
    }

    nonisolated init(persistenceController: PersistenceController = .shared) {
        self.persistenceController = persistenceController
    }

    // MARK: - Chat Sessions

    func createSession(title: String) -> ChatSession {
        let session = ChatSession(context: viewContext)
        session.id = UUID()
        session.title = title
        session.createdAt = Date()
        session.updatedAt = Date()
        saveContext()
        return session
    }

    func fetchAllSessions() -> [ChatSession] {
        let request = ChatSession.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ChatSession.updatedAt, ascending: false)]

        do {
            return try viewContext.fetch(request)
        } catch {
            print("Error fetching sessions: \(error)")
            return []
        }
    }

    func deleteSession(_ session: ChatSession) {
        viewContext.delete(session)
        saveContext()
    }

    func updateSessionTitle(_ session: ChatSession, title: String) {
        session.title = title
        session.updatedAt = Date()
        saveContext()
    }

    // MARK: - Messages

    func addMessage(to session: ChatSession, content: String, role: String) -> ChatMessage {
        let message = ChatMessage(context: viewContext)
        message.id = UUID()
        message.content = content
        message.role = role
        message.timestamp = Date()
        message.session = session

        session.updatedAt = Date()
        saveContext()

        print("💾 DB: Saved \(role) message to session '\(session.title ?? "Untitled")' (ID: \(session.objectID))")
        return message
    }

    func fetchMessages(for session: ChatSession) -> [ChatMessage] {
        let request = ChatMessage.fetchRequest()
        request.predicate = NSPredicate(format: "session == %@", session)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ChatMessage.timestamp, ascending: true)]

        do {
            let messages = try viewContext.fetch(request)
            print("🔍 DB: Fetched \(messages.count) messages for session '\(session.title ?? "Untitled")' (ID: \(session.objectID))")
            return messages
        } catch {
            print("❌ DB: Error fetching messages: \(error)")
            return []
        }
    }

    // MARK: - Documents

    func importDocument(to session: ChatSession, fileName: String, content: String) -> ImportedDocument {
        let document = ImportedDocument(context: viewContext)
        document.id = UUID()
        document.fileName = fileName
        document.content = content
        document.importedAt = Date()
        document.session = session

        saveContext()
        return document
    }

    func fetchDocuments(for session: ChatSession) -> [ImportedDocument] {
        let request = ImportedDocument.fetchRequest()
        request.predicate = NSPredicate(format: "session == %@", session)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ImportedDocument.importedAt, ascending: true)]

        do {
            let documents = try viewContext.fetch(request)
            print("🔍 DB: Fetched \(documents.count) documents for session '\(session.title ?? "Untitled")' (ID: \(session.objectID))")
            return documents
        } catch {
            print("❌ DB: Error fetching documents: \(error)")
            return []
        }
    }

    func deleteDocument(_ document: ImportedDocument) {
        viewContext.delete(document)
        saveContext()
    }

    func clearDocuments(for session: ChatSession) {
        let documents = fetchDocuments(for: session)
        documents.forEach { viewContext.delete($0) }
        saveContext()
    }

    // MARK: - Document Embeddings

    func addEmbedding(to document: ImportedDocument, chunkText: String, embedding: [Float], chunkIndex: Int) -> DocumentEmbedding {
        let embeddingEntity = DocumentEmbedding(context: viewContext)
        embeddingEntity.id = UUID()
        embeddingEntity.chunkText = chunkText
        embeddingEntity.embedding = embedding
        embeddingEntity.chunkIndex = Int32(chunkIndex)
        embeddingEntity.document = document

        saveContext()
        return embeddingEntity
    }

    func fetchEmbeddings(for document: ImportedDocument) -> [DocumentEmbedding] {
        let request = DocumentEmbedding.fetchRequest()
        request.predicate = NSPredicate(format: "document == %@", document)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \DocumentEmbedding.chunkIndex, ascending: true)]

        do {
            return try viewContext.fetch(request)
        } catch {
            print("Error fetching embeddings: \(error)")
            return []
        }
    }

    // MARK: - Helpers

    private func saveContext() {
        guard viewContext.hasChanges else { return }

        do {
            try viewContext.save()
        } catch {
            print("Error saving context: \(error)")
        }
    }
}
