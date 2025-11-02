//
//  ChatViewModel.swift (FIXED)
//  PhoneGPT
//
//  Key Changes:
//  1. Title update logic fixed - counts user messages correctly
//  2. Session isolation ensured - fresh fetch from database
//  3. Better debugging output
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
        print("📂 Loading session: \(session.title ?? "Untitled")")
        self.currentSession = session

        // ✅ FIX: Fetch fresh messages from database
        let savedMessages = databaseService.fetchMessages(for: session)

        print("   Found \(savedMessages.count) messages in database")

        self.messages = savedMessages.map { msg in
            let role: Message.Role = msg.role == "user" ? .user : (msg.role == "assistant" ? .assistant : .system)
            return Message(role: role, content: msg.content ?? "")
        }

        // Ensure system message exists
        if messages.isEmpty || messages.first?.role != .system {
            let systemMessage = Message.system("You are PhoneGPT, a helpful AI assistant running entirely on the user's device. You're knowledgeable, conversational, and personable.")
            messages.insert(systemMessage, at: 0)
            print("   Added system message")
        }
    }

    func createNewSession() {
        let session = databaseService.createSession(title: "New Chat")
        print("✨ Created new session")
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
        print("   Added welcome message")
    }

    func send() async {
        generateTask?.cancel()

        guard !prompt.isEmpty, let session = currentSession else {
            print("❌ No prompt or no active session")
            return
        }

        print("💬 Sending message to session: \(session.title ?? "Untitled")")

        isGenerating = true
        errorMessage = nil

        let userPrompt = prompt
        prompt = ""

        let userMessage = Message.user(userPrompt)
        messages.append(userMessage)
        _ = databaseService.addMessage(to: session, content: userPrompt, role: "user")

        var relevantContext = ""
        if settings.useDocuments {
            print("📚 Document search enabled")
            let contextChunks = documentService.searchDocuments(query: userPrompt, session: session, topK: 3)
            if !contextChunks.isEmpty {
                print("✅ Found \(contextChunks.count) relevant document chunks")
                relevantContext = "Here is relevant information from the user's documents:\n\n" + contextChunks.joined(separator: "\n\n") + "\n\nBased on this information and your knowledge, please answer: "
            } else {
                print("⚠️ No relevant document chunks found")
            }
        } else {
            print("📚 Document search disabled in settings")
        }

        var contextMessages = messages
        if !relevantContext.isEmpty, let lastUserIndex = contextMessages.lastIndex(where: { $0.role == .user }) {
            print("🔄 Adding document context to user message")
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

                // ✅ FIX: Properly detect first user message
                // Fetch all messages to get accurate count
                let allMessages = databaseService.fetchMessages(for: session)
                let userMessages = allMessages.filter { $0.role == "user" }

                if userMessages.count == 1 {
                    // First user message - extract title from first line
                    let titleLines = userPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
                        .components(separatedBy: "\n")
                    let title = titleLines.first ?? userPrompt
                    let truncatedTitle = String(title.prefix(50))

                    databaseService.updateSessionTitle(session, title: truncatedTitle)
                    print("✅ Session titled: '\(truncatedTitle)'")
                }

            } catch is CancellationError {
                print("⚠️ Generation cancelled")
                if var lastMessage = messages.last, lastMessage.role == .assistant {
                    lastMessage.content = lastMessage.content.isEmpty ? "[Cancelled]" : lastMessage.content + "\n[Cancelled]"
                    messages[messages.count - 1] = lastMessage
                }
            } catch {
                errorMessage = error.localizedDescription
                print("❌ Error: \(error.localizedDescription)")
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
        print("🗑️ Clearing conversation: \(session.title ?? "Untitled")")
        databaseService.deleteSession(session)
        createNewSession()
    }

    func importDocument(url: URL) async throws {
        guard let session = currentSession else {
            print("❌ No active session for document import")
            return
        }
        print("📄 Importing to session: \(session.title ?? "Untitled")")
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
