//
//  ChatViewModel.swift
//  PhoneGPT
//
//  Created by Darin Manley on 11/2/25.
//

import Foundation
import MLXLMCommon

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
    private var generateTask: Task<Void, Never>?

    /// Generation completion info (metrics)
    var generateCompletionInfo: GenerateCompletionInfo?

    // MARK: - Metrics

    /// Download progress for model
    var downloadProgress: Progress? {
        mlxService.modelDownloadProgress
    }

    /// Tokens generated per second
    var tokensPerSecond: Double {
        generateCompletionInfo?.tokensPerSecond ?? 0
    }

    /// Whether currently downloading model
    var isDownloading: Bool {
        mlxService.isDownloading
    }

    // MARK: - Initializer
    
    // Default initializer that creates MLXService on MainActor
    init() {
        self.mlxService = MLXService()
    }

    // Initializer for dependency injection (for testing)
    init(mlxService: MLXService) {
        self.mlxService = mlxService
    }

    // MARK: - Actions

    /// Send message and generate response
    func send() async {
        // Cancel any existing generation
        generateTask?.cancel()

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
                // Process generation chunks and update UI
                for try await generation in try await mlxService.generate(
                    messages: messages, model: selectedModel)
                {
                    if Task.isCancelled {
                        break
                    }
                    
                    switch generation {
                    case .chunk(let chunk):
                        // Append new text to the current assistant message
                        if messages.count > 0 && messages[messages.count - 1].role == .assistant {
                            messages[messages.count - 1].content += chunk
                        }
                        
                    case .info(let info):
                        // Update performance metrics
                        generateCompletionInfo = info
                        print("📊 Metrics: \(info.tokensPerSecond) tok/s")
                        
                    case .toolCall(let call):
                        // Tool calls not implemented yet
                        print("🔧 Tool call: \(call)")
                        break
                    }
                }

                print("✅ Generation complete")

            } catch {
                print("❌ Generation error: \(error)")
                errorMessage = error.localizedDescription

                // Mark message as error
                if messages.count > 0 && messages[messages.count - 1].role == .assistant {
                    if messages[messages.count - 1].content.isEmpty {
                        messages[messages.count - 1].content = "[Error: \(error.localizedDescription)]"
                    }
                }
            }
            
            isGenerating = false
        }

        await generateTask?.value
    }

    /// Clear conversation and start fresh
    func clearConversation() {
        messages = [
            .system("You are PhoneGPT, a helpful AI assistant running on the user's device.")
        ]
        prompt = ""
        generateTask?.cancel()
        errorMessage = nil
        generateCompletionInfo = nil
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
