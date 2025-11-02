//
//  ChatViewModel.swift
//  PhoneGPT
//
//  Created by Darin Manley on 11/2/25.
//

import Foundation

/// ViewModel managing chat interface and message generation
@Observable
@MainActor
class ChatViewModel {
    // MARK: - Dependencies

    private let mlxService: MLXService

    // MARK: - Chat State

    /// Current user input
    var prompt: String = ""

    /// Conversation history
    var messages: [Message] = [
        .system("You are PhoneGPT, a helpful AI assistant running entirely on the user's device. You're knowledgeable, conversational, and personable.")
    ]

    /// Selected model for generation
    var selectedModel: LMModel = MLXService.availableModels.first ?? {
        fatalError("No models available")
    }()

    // MARK: - Generation State

    /// Whether generation is in progress
    var isGenerating = false

    /// Current error message
    var errorMessage: String?

    /// Task for current generation (used for cancellation)
    private var generateTask: Task<Void, any Error>?

    // MARK: - Metrics

    /// Download progress for model
    var downloadProgress: Progress? {
        mlxService.modelDownloadProgress
    }

    /// Tokens generated per second
    var tokensPerSecond: Double {
        mlxService.tokensPerSecond
    }

    /// Whether currently downloading model
    var isDownloading: Bool {
        mlxService.isDownloading
    }

    // MARK: - Initializer

    init(mlxService: MLXService = MLXService()) {
        self.mlxService = mlxService
    }

    // MARK: - Actions

    /// Send message and generate response
    func send() async {
        if let existingTask = generateTask {
            existingTask.cancel()
            generateTask = nil
        }

        guard !prompt.isEmpty else { return }

        isGenerating = true
        errorMessage = nil

        let userMessage = Message.user(prompt)
        messages.append(userMessage)

        let assistantMessage = Message.assistant("")
        messages.append(assistantMessage)

        let currentPrompt = prompt
        prompt = ""

        print("📤 Sending message: \(currentPrompt)")

        generateTask = Task {
            do {
                let stream = try await mlxService.generate(
                    messages: messages,
                    model: selectedModel
                )

                print("📥 Receiving response...")

                for try await generation in stream {
                    switch generation {
                    case .chunk(let token):
                        if var lastMessage = messages.last, lastMessage.role == .assistant {
                            lastMessage.content += token
                            messages[messages.count - 1] = lastMessage
                        }

                    case .info(let info):
                        print("📊 Metrics: \(info.tokensPerSecond) tok/s")

                    case .toolCall:
                        break
                    }
                }

                print("✅ Generation complete")

            } catch is CancellationError {
                print("❌ Generation cancelled")
                if var lastMessage = messages.last, lastMessage.role == .assistant {
                    if !lastMessage.content.isEmpty {
                        lastMessage.content += "\n[Cancelled]"
                    } else {
                        lastMessage.content = "[Cancelled]"
                    }
                    messages[messages.count - 1] = lastMessage
                }

            } catch {
                print("❌ Generation error: \(error)")
                errorMessage = error.localizedDescription

                if var lastMessage = messages.last, lastMessage.role == .assistant {
                    lastMessage.content = "[Error: \(error.localizedDescription)]"
                    messages[messages.count - 1] = lastMessage
                }
            }
        }

        do {
            try await withTaskCancellationHandler {
                try await generateTask?.value
            } onCancel: {
                Task { @MainActor in
                    generateTask?.cancel()
                }
            }
        } catch is CancellationError {
            break
        } catch {
            break
        }

        isGenerating = false
        generateTask = nil
    }

    /// Clear conversation and start fresh
    func clearConversation() {
        messages = [
            .system("You are PhoneGPT, a helpful AI assistant running on the user's device.")
        ]
        prompt = ""
        generateTask?.cancel()
        errorMessage = nil
    }

    /// Remove message at index
    func removeMessage(at index: Int) {
        if index >= 0 && index < messages.count {
            messages.remove(at: index)
        }
    }

    /// Get last user message
    var lastUserMessage: String? {
        messages.last(where: { $0.role == .user })?.content
    }

    /// Get conversation summary (e.g., for sharing)
    var conversationSummary: String {
        messages
            .filter { $0.role != .system }
            .map { "\($0.role.rawValue.uppercased()): \($0.content)" }
            .joined(separator: "\n\n")
    }
}
