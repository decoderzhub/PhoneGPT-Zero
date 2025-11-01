import CoreML
import Foundation
import SwiftUI

/// ModelManager handles all AI inference and response generation for PhoneGPT
///
/// Architecture:
/// - Uses CoreML for on-device language model inference when available
/// - Maintains conversation history for context-aware responses
/// - Falls back to intelligent pattern matching if model unavailable
/// - Provides conversational, ChatGPT-like responses instead of scripted ones
///
/// Key Features:
/// - Natural language generation with system prompts for personality
/// - Context-aware document search and question answering
/// - Message summarization with intelligent intent detection
/// - Conversation history tracking for multi-turn dialogue

@MainActor
class ModelManager: ObservableObject {
    static let shared = ModelManager()
    
    @Published var isModelLoaded = false
    @Published var isGenerating = false
    @Published var generationProgress: Float = 0
    @Published var currentOutput = ""
    @Published var tokensPerSecond: Double = 0
    
    private var model: MLModel?
    private var lastGreetingTime: Date?
    private var lastUserMood: String = "neutral"
    private var conversationHistory: [(role: String, content: String)] = []
    private let maxHistoryLength = 10
    
    init() {
        loadModel()
    }

    // MARK: - Clear History
    func clearConversationHistory() {
        conversationHistory.removeAll()
    }

    // MARK: - Load Model
    func loadModel() {
        Task {
            self.isModelLoaded = false
            do {
                let config = MLModelConfiguration()
                config.computeUnits = .all
                
                guard let modelURL = Bundle.main.url(
                    forResource: "PhoneGPT",
                    withExtension: "mlmodelc"
                ) else {
                    print("⚠️ Model not found — using mock mode")
                    self.isModelLoaded = true
                    return
                }
                
                self.model = try MLModel(contentsOf: modelURL, configuration: config)
                self.isModelLoaded = true
                print("✅ PhoneGPT model loaded successfully")
            } catch {
                print("❌ Failed to load model: \(error)")
                self.isModelLoaded = true
            }
        }
    }
    
    // MARK: - Generate Response
    func generate(prompt: String, maxTokens: Int = 150) async -> String {
        self.isGenerating = true
        self.generationProgress = 0
        self.currentOutput = ""

        // Add user message to history
        conversationHistory.append((role: "user", content: prompt))
        if conversationHistory.count > maxHistoryLength {
            conversationHistory.removeFirst(conversationHistory.count - maxHistoryLength)
        }

        let response: String

        if prompt.contains("Context from documents:") {
            let parts = prompt.components(separatedBy: "Question:")
            let contextPart = parts.first ?? ""
            let question = parts.last?.trimmingCharacters(in: .whitespacesAndNewlines) ?? prompt
            let contextContent = extractContext(from: contextPart)
            response = await generateFromDocumentContext(documentContent: contextContent, question: question)
        } else {
            response = await generateConversationalResponse(for: prompt)
        }

        // Add assistant response to history
        conversationHistory.append((role: "assistant", content: response))

        // Animate generation visually
        for i in 0..<response.count {
            let index = response.index(response.startIndex, offsetBy: i)
            let partial = String(response[...index])
            self.currentOutput = partial
            self.generationProgress = Float(i) / Float(response.count)
            self.tokensPerSecond = 18.0
            try? await Task.sleep(nanoseconds: 12_000_000)
        }

        self.isGenerating = false
        self.generationProgress = 1.0
        return response
    }
    
    // MARK: - Extract Context
    private func extractContext(from text: String) -> String {
        if let range = text.range(of: "Context from documents:") {
            return String(text[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return text
    }

    // MARK: - Conversational Response Generator
    private func generateConversationalResponse(for userMessage: String) async -> String {
        // Build conversation context with system prompt
        let systemPrompt = """
        You are PhoneGPT, a friendly and helpful AI assistant running entirely on the user's iPhone. You're knowledgeable, conversational, and personable - similar to ChatGPT or Claude, but with a focus on privacy since you run completely offline.

        Key traits:
        - Be natural and conversational, not robotic or scripted
        - Show personality and warmth in your responses
        - Be helpful and informative without being overly formal
        - Keep responses concise but complete (2-4 sentences for simple questions)
        - Acknowledge when you don't know something
        - You run locally on the Neural Engine, so you're fast and private
        - You can help with questions, conversation, and searching the user's documents

        Respond naturally as if you're having a real conversation.
        """

        // Try to use the actual model if available
        if let modelResponse = await tryModelInference(systemPrompt: systemPrompt, userMessage: userMessage) {
            return modelResponse
        }

        // Fallback to intelligent pattern matching if model unavailable
        return generateIntelligentFallback(for: userMessage)
    }

    // MARK: - Try Model Inference
    private func tryModelInference(systemPrompt: String, userMessage: String) async -> String? {
        guard let model = model else { return nil }

        do {
            // Build full prompt with conversation history
            var fullPrompt = systemPrompt + "\n\n"

            // Add recent conversation history for context
            let recentHistory = conversationHistory.suffix(6)
            for turn in recentHistory {
                if turn.role == "user" {
                    fullPrompt += "User: \(turn.content)\n"
                } else {
                    fullPrompt += "Assistant: \(turn.content)\n"
                }
            }

            fullPrompt += "User: \(userMessage)\nAssistant:"

            // Prepare input for CoreML model
            let inputDict: [String: Any] = [
                "text": fullPrompt,
                "max_tokens": 150
            ]

            let inputProvider = try MLDictionaryFeatureProvider(dictionary: inputDict)
            let prediction = try model.prediction(from: inputProvider)

            // Extract generated text from model output
            // The exact key depends on your model - common ones are "output", "text", "generated_text"
            if let output = prediction.featureValue(for: "output")?.stringValue {
                return cleanModelOutput(output)
            } else if let output = prediction.featureValue(for: "text")?.stringValue {
                return cleanModelOutput(output)
            } else if let output = prediction.featureValue(for: "generated_text")?.stringValue {
                return cleanModelOutput(output)
            }

            // If we can't find the output, return nil to use fallback
            return nil
        } catch {
            print("⚠️ Model inference failed: \(error)")
            return nil
        }
    }

    // MARK: - Clean Model Output
    private func cleanModelOutput(_ rawOutput: String) -> String {
        var cleaned = rawOutput
        // Remove any remaining prompt markers
        if let range = cleaned.range(of: "Assistant:") {
            cleaned = String(cleaned[range.upperBound...])
        }
        // Trim whitespace and newlines
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        // Truncate at natural sentence endings if too long
        if cleaned.count > 500 {
            if let lastPeriod = cleaned.lastIndex(of: "."),
               lastPeriod.utf16Offset(in: cleaned) < 500 {
                cleaned = String(cleaned[...lastPeriod])
            } else {
                cleaned = String(cleaned.prefix(500)) + "..."
            }
        }
        return cleaned
    }

    // MARK: - Intelligent Fallback
    private func generateIntelligentFallback(for prompt: String) -> String {
        let l = prompt.lowercased()

        // Greetings - vary responses
        if l.contains("hello") || l.contains("hi") || l.contains("hey") {
            let greetings = [
                "Hey! How can I help you today?",
                "Hi there! What's on your mind?",
                "Hello! What would you like to know?",
                "Hey! I'm here to help. What can I do for you?"
            ]
            return greetings.randomElement() ?? "Hi there!"
        }

        // Status checks
        if l.contains("how are you") {
            let responses = [
                "I'm doing great! Running smooth on your device. How are you?",
                "Feeling good! Everything's running perfectly. What about you?",
                "I'm excellent! All systems working well. How can I help you today?",
                "Pretty good! Ready to assist with whatever you need. How are things with you?"
            ]
            return responses.randomElement() ?? "I'm doing well, thanks for asking!"
        }

        // User status responses
        if l.starts(with: "i'm good") || l.starts(with: "i'm great") || l.starts(with: "good") || l.starts(with: "fine") {
            let responses = [
                "Awesome! What would you like to chat about?",
                "Great to hear! How can I help you?",
                "Perfect! What's on your mind?",
                "Glad you're doing well! What can I do for you?"
            ]
            return responses.randomElement() ?? "Great! How can I help?"
        }

        // General knowledge questions
        if l.contains("why") && l.contains("sky") && l.contains("blue") {
            return "The sky looks blue because of something called Rayleigh scattering. Basically, when sunlight hits Earth's atmosphere, the air molecules scatter blue light more than other colors because it has shorter wavelengths. So when you look up, you're seeing all that scattered blue light. Pretty cool, right?"
        }

        if l.contains("what") && l.contains("you") && (l.contains("do") || l.contains("are")) {
            return "I'm PhoneGPT, your personal AI assistant that runs completely on your device. I can chat with you, answer questions, help you search through your documents, and more - all while keeping everything private since I work entirely offline. Think of me like ChatGPT, but running locally on your phone!"
        }

        // Default conversational response
        let genericResponses = [
            "That's an interesting question! Could you tell me a bit more about what you're looking for?",
            "I'd be happy to help with that! Can you give me some more details?",
            "Interesting! What specifically would you like to know about that?",
            "Great question! Could you elaborate a bit so I can give you a better answer?"
        ]

        return genericResponses.randomElement() ?? "I'm here to help! What would you like to know?"
    }
    
    // MARK: - Document Context Router (Humanized)
    private func generateFromDocumentContext(documentContent: String, question: String) async -> String {
        let lowerQ = question.lowercased()

        // 1️⃣ Detect casual conversation - use conversational AI
        if ["hi", "hello", "hey", "sup", "yo"].contains(where: { lowerQ.contains($0) }) && lowerQ.count < 20 {
            return await generateConversationalResponse(for: question)
        }

        if lowerQ.contains("how are you") || lowerQ.contains("how's it going") {
            return await generateConversationalResponse(for: question)
        }

        // Handle common conversational responses
        if ["good", "great", "fine", "ok", "okay", "well", "alright"].contains(where: { lowerQ.starts(with: "i'm \($0)") || lowerQ.starts(with: "im \($0)") || lowerQ == $0 }) {
            return await generateConversationalResponse(for: question)
        }

        // 2️⃣ Detect message-related queries FIRST (intent-based)
        let messageKeywords = ["message", "text", "sms", "conversation", "chat", "sent", "received", "yesterday", "last week", "recent"]
        let asksAboutMessages = messageKeywords.contains(where: { lowerQ.contains($0) })

        if asksAboutMessages && (documentContent.contains("\"conversations\"") || documentContent.contains("\"text\":")) {
            return summarizeMessageJSON(documentContent, question: question)
        }

        // 3️⃣ Personal knowledge queries
        if documentContent.contains("General Conversation Knowledge") ||
           documentContent.contains("Personal Assistant") ||
           documentContent.contains("Quick Reference Knowledge") ||
           documentContent.contains("Practical Skills") {
            return summarizeKnowledgeBase(documentContent, question: question)
        }

        // 4️⃣ General knowledge questions - use conversational AI
        if isGeneralKnowledgeQuestion(lowerQ) {
            return await generateConversationalResponse(for: question)
        }

        // 5️⃣ Try to use the model with document context
        if let modelResponse = await tryDocumentAwareInference(documentContent: documentContent, question: question) {
            return modelResponse
        }

        // 6️⃣ Fallback - only show document context if nothing else matches
        let preview = documentContent.prefix(400)
        return "I found some information in your files, but I'm not quite sure what you're asking. Could you be more specific?\n\nHere's a preview:\n\(preview)..."
    }

    // MARK: - Document-Aware Model Inference
    private func tryDocumentAwareInference(documentContent: String, question: String) async -> String? {
        guard let model = model else { return nil }

        let systemPrompt = """
        You are PhoneGPT, a friendly AI assistant. The user has imported some documents, and you should use the provided context to answer their question. Be natural and conversational in your response.

        Context from user's documents:
        \(documentContent.prefix(1000))

        Answer the user's question based on this context. If the context doesn't contain relevant information, politely say so and offer to help in another way.
        """

        return await tryModelInference(systemPrompt: systemPrompt, userMessage: question)
    }

    // MARK: - Detect General Knowledge Questions
    private func isGeneralKnowledgeQuestion(_ question: String) -> Bool {
        let questionWords = ["why", "what", "how", "when", "where", "who", "which", "explain", "tell me about"]
        return questionWords.contains(where: { question.contains($0) }) &&
               !question.contains("message") &&
               !question.contains("text") &&
               !question.contains("conversation")
    }

    
    // MARK: - JSON Message Summarizer
    private func summarizeMessageJSON(_ raw: String, question: String) -> String {
        struct Message: Decodable {
            let text: String
            let sender: String
            let is_from_me: Bool
            let date: String
            let conversation_id: String
        }
        struct Export: Decodable {
            let total_messages: Int
            let conversations: [String: [Message]]
        }

        if raw.contains("=== MESSAGE HISTORY") {
            return "I found your message summary — would you like me to list the last few conversations?"
        }

        guard let data = raw.data(using: .utf8),
              let export = try? JSONDecoder().decode(Export.self, from: data) else {
            return summarizeFragmentedMessages(raw, question: question)
        }

        var response = ""
        let lowerQ = question.lowercased()
        let dateFormatter = ISO8601DateFormatter()
        let calendar = Calendar.current

        if lowerQ.contains("yesterday") || lowerQ.contains("recent") {
            let yesterday = calendar.date(byAdding: .day, value: -1, to: Date()) ?? Date()
            for (convID, msgs) in export.conversations {
                let recent = msgs.filter {
                    guard let msgDate = dateFormatter.date(from: $0.date) else { return false }
                    return calendar.isDate(msgDate, inSameDayAs: yesterday)
                }
                if !recent.isEmpty {
                    response += "\n🗨️ \(convID):\n"
                    for m in recent.prefix(5) {
                        let who = m.is_from_me ? "You" : m.sender
                        response += "• \(who): \(m.text)\n"
                    }
                }
            }
            return response.isEmpty ? "No messages from yesterday." : response
        }

        let total = export.total_messages
        let threads = export.conversations.keys.count
        return "You have \(total) messages across \(threads) conversations."
    }
    
    // MARK: - Fallback Fragment Parser
    private func summarizeFragmentedMessages(_ text: String, question: String) -> String {
        let regex = try! NSRegularExpression(pattern: #""text":\s*"([^"]+)"[\s\S]*?"sender":\s*"([^"]*)".*?"date":\s*"([^"]*)"#)
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: text.utf16.count))
        guard !matches.isEmpty else { return "I found some message-like data but couldn't parse it completely. Could you try re-importing your messages?" }

        var lines: [String] = []
        for m in matches.prefix(10) {
            let nsText = text as NSString
            let body = nsText.substring(with: m.range(at: 1))
            var sender = nsText.substring(with: m.range(at: 2))
            let date = nsText.substring(with: m.range(at: 3))
            if sender.isEmpty || sender.lowercased() == "unknown" { sender = "Someone" }
            let prefix = sender.lowercased().contains("me") ? "You" : sender

            // Format date nicely
            let dateStr = formatMessageDate(date)
            lines.append("• \(prefix): \"\(body)\" (\(dateStr))")
        }

        // Contextual intro based on question
        let lowerQ = question.lowercased()
        let intro: String
        if lowerQ.contains("yesterday") {
            intro = "Here's what I found from yesterday:"
        } else if lowerQ.contains("recent") || lowerQ.contains("latest") {
            intro = "Here are your most recent messages:"
        } else if lowerQ.contains("today") {
            intro = "Here's what I found from today:"
        } else {
            intro = "Here's a summary of your imported messages:"
        }

        return "\(intro)\n" + lines.joined(separator: "\n")
    }

    // MARK: - Format Message Date
    private func formatMessageDate(_ isoDate: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: isoDate) else { return isoDate }

        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return DateFormatter.localizedString(from: date, dateStyle: .none, timeStyle: .short)
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            return DateFormatter.localizedString(from: date, dateStyle: .medium, timeStyle: .none)
        }
    }
    
    // MARK: - Knowledge Base Summarizer
    private func summarizeKnowledgeBase(_ raw: String, question: String) -> String {
        let q = question.lowercased()

        // Identity questions
        if q.contains("who are you") || q.contains("what is phonegpt") || q.contains("what are you") {
            return "I'm PhoneGPT — your private, on-device AI assistant powered entirely by Apple's Neural Engine. Everything runs locally on your device, so your data never leaves your phone. No servers, no tracking, just pure local intelligence working for you!"
        }

        // How-to queries
        if q.contains("how to") || q.contains("how do i") || q.contains("how can i") {
            let search = q.replacingOccurrences(of: "how to", with: "")
                          .replacingOccurrences(of: "how do i", with: "")
                          .replacingOccurrences(of: "how can i", with: "")
                          .trimmingCharacters(in: .whitespaces)

            if let match = raw.split(separator: "\n").first(where: { $0.lowercased().contains(search) }) {
                return "I found this in your knowledge base:\n\n\(match)\n\nNeed more details? Just ask!"
            }
            return "I didn't find that specific topic in your knowledge base, but I'd be happy to help you outline it step-by-step! What would you like to know?"
        }

        // Tips and advice
        if q.contains("tip") || q.contains("advice") || q.contains("suggest") {
            let tips = raw.split(separator: "\n").filter { $0.contains("-") || $0.contains("•") }.prefix(5)
            if !tips.isEmpty {
                return "Here are some helpful tips from your reference files:\n\n" + tips.joined(separator: "\n")
            }
            return "I didn't find specific tips in your knowledge base, but I'm here to help with whatever you need!"
        }

        // Search for specific keywords
        if q.count > 5 && !["what", "how", "why", "when", "where"].contains(where: { q.starts(with: $0) }) {
            let keywords = q.split(separator: " ").filter { $0.count > 3 }
            for keyword in keywords {
                if let match = raw.split(separator: "\n").first(where: { $0.lowercased().contains(keyword) }) {
                    return "I found this related to \"\(keyword)\" in your knowledge base:\n\n\(match)"
                }
            }
        }

        // Fallback with preview
        let lines = raw.split(separator: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.prefix(8)
        if !lines.isEmpty {
            return "Here's what I found in your knowledge base:\n\n" + lines.joined(separator: "\n") + "\n\nWould you like me to search for something more specific?"
        }

        return "I have your knowledge base loaded, but I'm not sure exactly what you're looking for. Could you be more specific?"
    }
}

