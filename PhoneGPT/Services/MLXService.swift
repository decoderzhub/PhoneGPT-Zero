//
//  MLXService.swift
//  PhoneGPT
//
//  Created by Darin Manley on 11/2/25.
//

import Foundation
import MLX
import MLXLLM
import MLXLMCommon

/// Service for loading and running language models via MLX
/// Handles model caching, download progress, and text generation
@Observable
@MainActor
class MLXService {
    // MARK: - Available Models

    /// List of all supported models (LLM + VLM)
    static let availableModels: [LMModel] = [
        LMModel(
            name: "Qwen 2.5 (1.5B)",
            configuration: LLMRegistry.qwen2_5_1_5b,
            type: .llm,
            parameters: "1.5B"
        ),
        LMModel(
            name: "SmolLM (135M)",
            configuration: LLMRegistry.smolLM_135M_4bit,
            type: .llm,
            parameters: "135M"
        ),
        LMModel(
            name: "Llama 3.2 (1B)",
            configuration: LLMRegistry.llama3_2_1B_4bit,
            type: .llm,
            parameters: "1B"
        ),
    ]

    // MARK: - State

    /// Cache for loaded models (prevents reloading)
    private let modelCache = NSCache<NSString, ModelContainer>()

    /// Download progress for currently loading model
    private(set) var modelDownloadProgress: Progress?

    /// Performance info from last generation
    private(set) var lastGenerationInfo: GenerateCompletionInfo?

    /// Current error state
    private(set) var lastError: Error?

    // MARK: - Computed Properties

    /// Tokens per second from last generation
    var tokensPerSecond: Double {
        lastGenerationInfo?.tokensPerSecond ?? 0
    }

    /// Whether model is currently downloading
    var isDownloading: Bool {
        modelDownloadProgress != nil
    }

    // MARK: - Model Loading

    /// Load a model from cache or Hugging Face Hub
    /// - Parameters:
    ///   - model: The LMModel configuration to load
    /// - Returns: Loaded ModelContainer
    /// - Throws: Loading errors
    private func load(model: LMModel) async throws -> ModelContainer {
        MLX.GPU.set(cacheLimit: 20 * 1024 * 1024)

        if let cached = modelCache.object(forKey: model.name as NSString) {
            print("✅ Loaded \(model.name) from cache")
            return cached
        }

        print("📥 Loading \(model.name) from Hugging Face Hub...")

        let factory: ModelFactory = switch model.type {
        case .llm:
            LLMModelFactory.shared
        case .vlm:
            VLMModelFactory.shared
        }

        let container = try await factory.loadContainer(
            hub: .default,
            configuration: model.configuration
        ) { progress in
            Task { @MainActor in
                self.modelDownloadProgress = progress
                let percent = Int(progress.fractionCompleted * 100)
                print("📊 Download: \(percent)%")
            }
        }

        modelCache.setObject(container, forKey: model.name as NSString)
        modelDownloadProgress = nil

        print("✅ Loaded \(model.name)")
        return container
    }

    // MARK: - Generation

    /// Generate response for given messages
    /// - Parameters:
    ///   - messages: Conversation history
    ///   - model: Model to use for generation
    /// - Returns: AsyncStream of generation events
    /// - Throws: Loading or generation errors
    func generate(
        messages: [Message],
        model: LMModel
    ) async throws -> AsyncStream<Generation> {
        print("🔄 Loading model for generation...")
        let container = try await load(model: model)

        print("📝 Preparing input (\(messages.count) messages)...")

        let chatMessages = messages.map { message in
            let role: Chat.Message.Role = switch message.role {
            case .assistant:
                .assistant
            case .user:
                .user
            case .system:
                .system
            }

            let images: [UserInput.Image] = message.images.map { .url($0) }

            return Chat.Message(
                role: role,
                content: message.content,
                images: images,
                videos: []
            )
        }

        let userInput = UserInput(
            chat: chatMessages,
            processing: .init(
                resize: .init(width: 1024, height: 1024)
            )
        )

        return try await container.perform { context in
            print("⚙️ Processing input...")
            let lmInput = try await context.processor.prepare(input: userInput)

            let parameters = GenerateParameters(
                temperature: 0.7,
                maxTokens: 512
            )

            print("🤖 Generating response...")

            return try MLXLMCommon.generate(
                input: lmInput,
                parameters: parameters,
                context: context
            )
        }
    }

    // MARK: - Cache Management

    /// Clear model cache and free memory
    func clearCache() {
        modelCache.removeAllObjects()
        print("🗑️ Model cache cleared")
    }

    /// Get count of cached models
    var cachedModelCount: Int {
        0
    }
}

// MARK: - Generation Event

/// Event emitted during text generation
enum Generation {
    /// Generated text chunk
    case chunk(String)
    /// Generation metrics
    case info(GenerateCompletionInfo)
    /// Tool call (for future extension)
    case toolCall(String)
}
