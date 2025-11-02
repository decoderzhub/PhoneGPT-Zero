//
//  ChatViewModel.swift
//  PhoneGPT
//
//  Created by Darin Manley on 11/2/25.
//

import Foundation
import MLXLMCommon

@Observable
@MainActor
class ChatViewModel {
    private let mlxService: MLXService
    private let databaseService: DatabaseService
    private let documentService: DocumentService
    private let settings: AppSettings

    var currentSession: ChatSession?
    var prompt: String = ""
    var messages: [Message] = []
    var selectedModel: LMModel = MLXService.availableModels.first!

    var isGenerating = false
    var errorMessage: String?
    private var generateTask: Task<Void, Never>?
    var generateCompletionInfo: GenerateCompletionInfo?

    var tokensPerSecond: Double {
        generateCompletionInfo?.tokensPerSecond ?? 0
    }

    nonisolated init(
        mlxService: MLXService,
        databaseService: DatabaseService,
        documentService: DocumentService,
        settings: AppSettings
    ) {
        self.mlxService = mlxService
        self.databaseService = databaseService
        self.documentService = documentService
        self.settings = settings
    }

    convenience init(settings: AppSettings) {
        let databaseService = DatabaseService()
        self.init(
            mlxService: MLXService(),
            databaseService: databaseService,
            documentService: DocumentService(databaseService: databaseService),
            settings: settings
        )
    }

    func loadSession(_ session: ChatSession) {
        self.currentSession = session
        let savedMessages = databaseService.fetchMessages(for: session)

        self.messages = savedMessages.map { msg in
            let role: Message.Role = msg.role == "user" ? .user : (msg.role == "assistant" ? .assistant : .system)
            return Message(role: role, content: msg.content ?? "")
        }

        if messages.isEmpty || messages.first?.role != .system {
            messages.insert(.system("You are PhoneGPT, a helpful AI assistant running entirely on the user's device. You're knowledgeable, conversational, and personable."), at: 0)
        }
    }

    func createNewSession() {
        let session = databaseService.createSession(title: "New Chat")
        loadSession(session)

        let welcomeMessage = """
        Welcome to **PhoneGPT**! 👋

        I'm your personal AI assistant running entirely on your device. Here's what makes me special:

        - **100% Private**: All processing happens locally on your iPhone
        - **No Internet Required**: Chat offline after model download
        - **Fast & Secure**: Your data never leaves your device

        **What I can help with:**
        - Answer questions and have conversations
        - Help with writing and brainstorming
        - Explain concepts and solve problems
        - Work with documents you upload

        Ask me anything to get started!
        """

        messages.append(Message.assistant(welcomeMessage))
        _ = databaseService.addMessage(to: session, content: welcomeMessage, role: "assistant")
    }

    func send() async {
        generateTask?.cancel()

        guard !prompt.isEmpty, let session = currentSession else { return }

        isGenerating = true
        errorMessage = nil

        let userPrompt = prompt
        prompt = ""

        let userMessage = Message.user(userPrompt)
        messages.append(userMessage)
        _ = databaseService.addMessage(to: session, content: userPrompt, role: "user")

        var relevantContext = ""
        if settings.useDocuments {
            let contextChunks = documentService.searchDocuments(query: userPrompt, session: session, topK: 3)
            if !contextChunks.isEmpty {
                relevantContext = "Relevant context from documents:\n" + contextChunks.joined(separator: "\n\n") + "\n\n"
            }
        }

        var contextMessages = messages
        if !relevantContext.isEmpty, let lastUserIndex = contextMessages.lastIndex(where: { $0.role == .user }) {
            contextMessages[lastUserIndex] = Message.user(relevantContext + userPrompt)
        }

        let assistantMessage = Message.assistant("")
        messages.append(assistantMessage)

        generateTask = Task {
            do {
                let stream = try await mlxService.generate(
                    messages: contextMessages,
                    model: selectedModel
                )

                var fullResponse = ""

                for try await generation in stream {
                    guard !Task.isCancelled else { break }

                    switch generation {
                    case .chunk(let chunk):
                        fullResponse += chunk
                        if var lastMessage = messages.last, lastMessage.role == .assistant {
                            lastMessage.content = fullResponse
                            messages[messages.count - 1] = lastMessage
                        }

                    case .info(let info):
                        generateCompletionInfo = info

                    case .toolCall:
                        break
                    }
                }

                _ = databaseService.addMessage(to: session, content: fullResponse, role: "assistant")

                if session.messages?.count == 2 {
                    let title = String(userPrompt.prefix(50))
                    databaseService.updateSessionTitle(session, title: title)
                }

            } catch is CancellationError {
                if var lastMessage = messages.last, lastMessage.role == .assistant {
                    lastMessage.content = lastMessage.content.isEmpty ? "[Cancelled]" : lastMessage.content + "\n[Cancelled]"
                    messages[messages.count - 1] = lastMessage
                }
            } catch {
                errorMessage = error.localizedDescription
                if var lastMessage = messages.last, lastMessage.role == .assistant {
                    lastMessage.content = "[Error: \(error.localizedDescription)]"
                    messages[messages.count - 1] = lastMessage
                }
            }

            isGenerating = false
        }

        await generateTask?.value
    }

    func clearConversation() {
        guard let session = currentSession else { return }
        databaseService.deleteSession(session)
        createNewSession()
    }

    func importDocument(url: URL) async throws {
        guard let session = currentSession else { return }
        _ = try await documentService.importDocument(url: url, to: session)
    }

    func clearDocuments() {
        guard let session = currentSession else { return }
        databaseService.clearDocuments(for: session)
    }

    func getImportedDocuments() -> [ImportedDocument] {
        guard let session = currentSession else { return [] }
        return databaseService.fetchDocuments(for: session)
    }

    func getMLXService() -> MLXService {
        return mlxService
    }
}
