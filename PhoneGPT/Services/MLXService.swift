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
import Hub

// MARK: - HubApi Extension
// Add default HubApi instance for convenience (from MLXChatExample)
extension HubApi {
    #if os(iOS)
    static let `default` = HubApi(
        downloadBase: URL.cachesDirectory.appending(path: "huggingface")
    )
    #else
    static let `default` = HubApi(
        downloadBase: URL.downloadsDirectory.appending(path: "huggingface")
    )
    #endif
}

/// Service for loading and running language models via MLX
/// Handles model caching, download progress, and text generation
@Observable
@MainActor
class MLXService {
    // MARK: - Available Models

    /// List of all supported models (LLM only for now)
    static let availableModels: [LMModel] = [
        LMModel(
            name: "Qwen 2.5 (1.5B)",
            configuration: ModelConfiguration(id: "mlx-community/Qwen2.5-1.5B-Instruct-4bit"),
            type: .llm,
            parameters: "1.5B"
        ),
        LMModel(
            name: "SmolLM (135M)",
            configuration: ModelConfiguration(id: "mlx-community/SmolLM-135M-Instruct-4bit"),
            type: .llm,
            parameters: "135M"
        ),
        LMModel(
            name: "Llama 3.2 (1B)",
            configuration: ModelConfiguration(id: "mlx-community/Llama-3.2-1B-Instruct-4bit"),
            type: .llm,
            parameters: "1B"
        ),
    ]

    // MARK: - State

    /// Cache for loaded models (prevents reloading)
    private let modelCache = NSCache<NSString, ModelContainer>()

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

        // For now, only support LLM models
        let factory = LLMModelFactory.shared

        let container = try await factory.loadContainer(
            hub: HubApi.default,
            configuration: model.configuration
        ) { progress in
            let percent = Int(progress.fractionCompleted * 100)
            print("📊 Download: \(percent)%")
        }

        modelCache.setObject(container, forKey: model.name as NSString)

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
    ) async throws -> AsyncStream<MLXLMCommon.Generation> {
        print("🔄 Loading model for generation...")
        let container = try await load(model: model)

        print("📝 Preparing input (\(messages.count) messages)...")

        // Convert our Message type to Chat.Message
        let chatMessages = messages.map { message in
            let role: Chat.Message.Role = switch message.role {
            case .assistant:
                .assistant
            case .user:
                .user
            case .system:
                .system
            }

            return Chat.Message(
                role: role,
                content: message.content,
                images: [],  // No image support for now
                videos: []   // No video support for now
            )
        }

        // Create UserInput with chat messages
        let userInput = UserInput(prompt: .chat(chatMessages))

        return try await container.perform { context in
            print("⚙️ Processing input...")
            let lmInput = try await context.processor.prepare(input: userInput)

            let parameters = GenerateParameters(
                maxTokens: 512,
                temperature: 0.7
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

    /// Delete all downloaded model files from disk
    func deleteDownloadedModels() throws {
        let hubDirectory = HubApi.default.downloadBase

        guard FileManager.default.fileExists(atPath: hubDirectory.path) else {
            print("📁 No models directory found")
            return
        }

        try FileManager.default.removeItem(at: hubDirectory)
        modelCache.removeAllObjects()
        print("🗑️ Deleted all downloaded models from \(hubDirectory.path)")
    }

    /// Check if any models are downloaded
    func hasDownloadedModels() -> Bool {
        let hubDirectory = HubApi.default.downloadBase

        guard FileManager.default.fileExists(atPath: hubDirectory.path) else {
            return false
        }

        do {
            let contents = try FileManager.default.contentsOfDirectory(at: hubDirectory, includingPropertiesForKeys: [.isDirectoryKey])
            return !contents.isEmpty
        } catch {
            return false
        }
    }

    /// Get approximate size of downloaded models
    func getModelStorageSize() -> String {
        let hubDirectory = HubApi.default.downloadBase

        guard FileManager.default.fileExists(atPath: hubDirectory.path) else {
            return "0 MB"
        }

        do {
            let contents = try FileManager.default.contentsOfDirectory(at: hubDirectory, includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles])

            var totalSize: Int64 = 0
            for url in contents {
                let resourceValues = try url.resourceValues(forKeys: [.totalFileSizeKey, .fileSizeKey])
                totalSize += Int64(resourceValues.totalFileSize ?? resourceValues.fileSize ?? 0)
            }

            let formatter = ByteCountFormatter()
            formatter.countStyle = .file
            return formatter.string(fromByteCount: totalSize)
        } catch {
            return "Unknown"
        }
    }
}

