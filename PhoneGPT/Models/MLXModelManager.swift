import Foundation
import SwiftUI
import MLX
import MLXLLM
import MLXLMCommon

@MainActor
class MLXModelManager: ObservableObject {
    static let shared = MLXModelManager()

    @Published var isModelLoaded = false
    @Published var isGenerating = false
    @Published var generationProgress: Float = 0
    @Published var currentOutput = ""
    @Published var tokensPerSecond: Double = 0
    @Published var modelLoadProgress: Float = 0
    @Published var modelName: String = ""

    private var llm: LLMModel?
    private var tokenizer: any Tokenizer
    private let grammarRefiner = GrammarRefiner()

    var dataManager: PersonalDataManager?

    private let defaultModelID = "mlx-community/Qwen2.5-3B-Instruct-4bit"

    init() {
        self.tokenizer = BPETokenizer()
        Task {
            await loadModel()
        }
    }

    func loadModel(modelID: String? = nil) async {
        let modelToLoad = modelID ?? defaultModelID
        self.modelName = modelToLoad
        self.isModelLoaded = false
        self.modelLoadProgress = 0

        print("🔄 Loading MLX model: \(modelToLoad)")

        do {
            let modelConfiguration = ModelConfiguration.configuration(id: modelToLoad)

            let progressCallback: (Progress) -> Void = { [weak self] progress in
                Task { @MainActor in
                    self?.modelLoadProgress = Float(progress.fractionCompleted)
                    print("📦 Model download: \(Int(progress.fractionCompleted * 100))%")
                }
            }

            let loadedModel = try await LLM.load(
                configuration: modelConfiguration,
                progressHandler: progressCallback
            )

            self.llm = loadedModel.model
            self.tokenizer = loadedModel.tokenizer
            self.isModelLoaded = true
            self.modelLoadProgress = 1.0

            print("✅ MLX model loaded successfully: \(modelToLoad)")
            print("   Model type: \(type(of: loadedModel.model))")

        } catch {
            print("❌ Failed to load MLX model: \(error)")
            print("   Using fallback mode")
            self.isModelLoaded = true
        }
    }

    func generateRAGResponse(for query: String, conversationHistory: String = "") async -> String {
        guard let dataManager = dataManager else {
            print("⚠️ DataManager not available, falling back to direct generation")
            return await generate(prompt: query)
        }

        print("\n🧠 MLX RAG Pipeline started for: \"\(query.prefix(50))...\"")

        let startRetrieval = Date()
        let relevantDocs = dataManager.search(query: query, topK: 5)
        let retrievalTime = Date().timeIntervalSince(startRetrieval)

        if relevantDocs.isEmpty {
            print("   ❌ No documents found in vector DB")
            return await generate(prompt: query)
        }

        print("   ✅ Retrieved \(relevantDocs.count) docs (\(Int(retrievalTime * 1000))ms)")

        let startFusion = Date()
        let fusedContext = dataManager.fuseContext(relevantDocs, for: query, maxTokens: 800)
        let fusionTime = Date().timeIntervalSince(startFusion)

        if fusedContext.isEmpty {
            print("   ⚠️ Context fusion produced no results")
            return await generate(prompt: query)
        }

        print("   ✅ Context fused (\(Int(fusionTime * 1000))ms, \(fusedContext.count) chars)")

        let contextualPrompt = buildRAGPrompt(context: fusedContext, query: query, history: conversationHistory)

        let startGeneration = Date()
        let response = await generateWithMLX(prompt: contextualPrompt)
        let generationTime = Date().timeIntervalSince(startGeneration)

        print("   ✅ MLX response generated (\(Int(generationTime * 1000))ms)")

        let totalTime = Date().timeIntervalSince(startRetrieval)
        print("   🏁 Total MLX RAG pipeline: \(Int(totalTime * 1000))ms\n")

        return response
    }

    private func buildRAGPrompt(context: String, query: String, history: String) -> String {
        var prompt = "<|im_start|>system\nYou are a helpful AI assistant. Use the following context from the user's documents to answer their question accurately and concisely.\n\nContext:\n\(context)<|im_end|>\n"

        if !history.isEmpty {
            let recentHistory = history.split(separator: "\n").suffix(6).joined(separator: "\n")
            prompt += "<|im_start|>user\nPrevious conversation:\n\(recentHistory)<|im_end|>\n"
        }

        prompt += "<|im_start|>user\n\(query)<|im_end|>\n<|im_start|>assistant\n"

        return prompt
    }

    func generate(prompt: String, maxTokens: Int = 512) async -> String {
        let formattedPrompt = "<|im_start|>system\nYou are a helpful, friendly AI assistant running locally on the user's device. Be concise and natural in your responses.<|im_end|>\n<|im_start|>user\n\(prompt)<|im_end|>\n<|im_start|>assistant\n"

        return await generateWithMLX(prompt: formattedPrompt, maxTokens: maxTokens)
    }

    private func generateWithMLX(prompt: String, maxTokens: Int = 512) async -> String {
        guard isModelLoaded else {
            return "Model is still loading. Please wait..."
        }

        guard let llm = llm else {
            print("⚠️ MLX model not available, using fallback")
            return generateFallbackResponse(for: prompt)
        }

        self.isGenerating = true
        self.generationProgress = 0
        self.currentOutput = ""

        do {
            let promptTokens = tokenizer.encode(text: prompt)
            print("🔤 Prompt tokens: \(promptTokens.count)")

            var generatedText = ""
            var tokenCount = 0
            let startTime = Date()

            let generateParameters = GenerateParameters(
                temperature: 0.7,
                topP: 0.9,
                repetitionPenalty: 1.1
            )

            let result = try await llm.generate(
                promptTokens: promptTokens,
                parameters: generateParameters
            ) { tokens in
                let newText = self.tokenizer.decode(tokens: tokens)
                generatedText += newText
                tokenCount += tokens.count

                Task { @MainActor in
                    self.currentOutput = generatedText
                    self.generationProgress = Float(tokenCount) / Float(maxTokens)

                    let elapsed = Date().timeIntervalSince(startTime)
                    if elapsed > 0 {
                        self.tokensPerSecond = Double(tokenCount) / elapsed
                    }
                }

                if tokenCount >= maxTokens {
                    return .stop
                }

                if generatedText.contains("<|im_end|>") {
                    return .stop
                }

                return .more
            }

            let finalElapsed = Date().timeIntervalSince(startTime)
            let finalTPS = finalElapsed > 0 ? Double(tokenCount) / finalElapsed : 0

            print("✅ Generation complete:")
            print("   Tokens: \(tokenCount)")
            print("   Time: \(String(format: "%.2f", finalElapsed))s")
            print("   Speed: \(String(format: "%.2f", finalTPS)) tokens/sec")

            let cleanedText = generatedText
                .replacingOccurrences(of: "<|im_end|>", with: "")
                .replacingOccurrences(of: "<|im_start|>", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            self.isGenerating = false
            self.generationProgress = 1.0

            return cleanedText

        } catch {
            print("❌ MLX generation error: \(error)")
            self.isGenerating = false
            return generateFallbackResponse(for: prompt)
        }
    }

    private func generateFallbackResponse(for prompt: String) -> String {
        let lowerPrompt = prompt.lowercased()

        if lowerPrompt.contains("hello") || lowerPrompt.contains("hi") {
            return "Hello! I'm your local AI assistant. How can I help you today?"
        }

        if lowerPrompt.contains("how are you") {
            return "I'm running well on your device! All processing happens locally for your privacy."
        }

        if lowerPrompt.contains("what can you do") {
            return "I can chat with you, answer questions about your documents, and help with various tasks - all while running locally on your iPhone."
        }

        return "I'm your local AI assistant. I can help answer questions, chat, and work with your documents. What would you like to know?"
    }

    func clearCache() {
        print("🧹 Clearing MLX cache")
        currentOutput = ""
        generationProgress = 0
    }

    func switchModel(to modelID: String) async {
        print("🔄 Switching to model: \(modelID)")
        await loadModel(modelID: modelID)
    }
}
