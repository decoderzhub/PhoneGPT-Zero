//
//  GlassesAssistantViewModel.swift
//  PhoneGPT
//
//  Created by Darin Manley on 11/2/25.
//


//
//  GlassesAssistantViewModel.swift
//  PhoneGPT
//
//  Connects PhoneGPT's AI to Even Realities glasses via MentraOS
//

import Foundation
import MLXLMCommon

@Observable
@MainActor
class GlassesAssistantViewModel {
    private let mentraOS: MentraOSService
    private let mlxService: MLXService
    private let chatViewModel: ChatViewModel
    
    var isListening = false
    var isProcessing = false
    var currentResponse = ""
    var conversationHistory: [Message] = []
    
    // Settings
    var streamingEnabled = true
    var maxDisplayLength = 100 // Characters per display frame
    var autoScrollEnabled = true
    
    init(mentraOS: MentraOSService, mlxService: MLXService, chatViewModel: ChatViewModel) {
        self.mentraOS = mentraOS
        self.mlxService = mlxService
        self.chatViewModel = chatViewModel
        
        // Initialize with system prompt for glasses context
        conversationHistory = [
            Message.system("""
            You are PhoneGPT Glasses Assistant. Provide concise, clear responses optimized for heads-up display.
            
            Guidelines:
            - Keep responses brief (2-3 sentences max)
            - Use simple language
            - Avoid technical jargon unless asked
            - Be conversational and friendly
            - If topic requires detail, offer to provide more info
            
            The user is viewing your responses on smart glasses while multitasking.
            """)
        ]
    }
    
    // MARK: - Main Voice Assistant Flow
    
    /// Start voice-activated assistant session
    func startVoiceSession() async throws {
        guard mentraOS.isConnected && mentraOS.glassesConnected else {
            throw GlassesAssistantError.notConnected
        }
        
        isListening = true
        print("🎤 Starting voice session...")
        
        // Show listening indicator on glasses
        try await mentraOS.displayText("🎤 Listening...")
        
        // Capture voice input
        let userQuery = try await mentraOS.captureVoiceInput()
        isListening = false
        
        guard !userQuery.isEmpty else {
            try await mentraOS.displayText("❌ No input detected")
            return
        }
        
        print("📝 User said: \"\(userQuery)\"")
        
        // Show processing indicator
        try await mentraOS.displayText("🤔 Thinking...")
        
        // Process with AI
        try await processQuery(userQuery)
    }
    
    /// Process user query with PhoneGPT AI
    private func processQuery(_ query: String) async throws {
        isProcessing = true
        currentResponse = ""
        
        // Add user message to history
        let userMessage = Message.user(query)
        conversationHistory.append(userMessage)
        
        // Generate AI response
        let model = chatViewModel.selectedModel
        
        let stream = try await mlxService.generate(
            messages: conversationHistory,
            model: model
        )
        
        var fullResponse = ""
        var displayBuffer = ""
        var wordCount = 0
        
        for try await generation in stream {
            switch generation {
            case .chunk(let chunk):
                fullResponse += chunk
                displayBuffer += chunk
                
                // Stream to glasses if enabled
                if streamingEnabled {
                    // Update every few words for smooth display
                    wordCount += chunk.split(separator: " ").count
                    
                    if wordCount >= 3 || displayBuffer.count >= maxDisplayLength {
                        try await updateGlassesDisplay(displayBuffer)
                        displayBuffer = ""
                        wordCount = 0
                    }
                }
                
            case .info(let info):
                print("📊 Generation: \(info.tokensPerSecond) tokens/sec")
                
            case .toolCall:
                break
            }
        }
        
        // Display any remaining buffer
        if !displayBuffer.isEmpty {
            try await updateGlassesDisplay(displayBuffer)
        }
        
        // Add assistant response to history
        let assistantMessage = Message.assistant(fullResponse)
        conversationHistory.append(assistantMessage)
        
        currentResponse = fullResponse
        isProcessing = false
        
        print("✅ Response complete: \"\(fullResponse)\"")
    }
    
    // MARK: - Display Management
    
    private func updateGlassesDisplay(_ text: String) async throws {
        if streamingEnabled {
            // Append to current display
            try await mentraOS.streamTextChunk(text)
        } else {
            // Replace entire display
            try await mentraOS.displayText(text)
        }
        
        // Brief delay for readability
        try await Task.sleep(nanoseconds: 200_000_000) // 200ms
    }
    
    /// Display paginated response for long answers
    func paginateResponse(_ response: String, pageSize: Int = 100) -> [String] {
        let sentences = response.components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        var pages: [String] = []
        var currentPage = ""
        
        for sentence in sentences {
            let sentenceWithPunctuation = sentence + ". "
            
            if currentPage.count + sentenceWithPunctuation.count > pageSize {
                if !currentPage.isEmpty {
                    pages.append(currentPage.trimmingCharacters(in: .whitespaces))
                }
                currentPage = sentenceWithPunctuation
            } else {
                currentPage += sentenceWithPunctuation
            }
        }
        
        if !currentPage.isEmpty {
            pages.append(currentPage.trimmingCharacters(in: .whitespaces))
        }
        
        return pages
    }
    
    /// Show paginated response with navigation
    func showPaginatedResponse(_ response: String) async throws {
        let pages = paginateResponse(response, pageSize: maxDisplayLength)
        
        for (index, page) in pages.enumerated() {
            let pageIndicator = pages.count > 1 ? " (\(index + 1)/\(pages.count))" : ""
            try await mentraOS.displayText(page + pageIndicator, duration: 5.0)
            
            // Wait for user to read (or skip with gesture)
            try await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
        }
    }
    
    // MARK: - Quick Commands
    
    /// Predefined quick commands for common tasks
    func executeQuickCommand(_ command: QuickCommand) async throws {
        switch command {
        case .whatTime:
            let time = Date().formatted(date: .omitted, time: .shortened)
            try await mentraOS.displayText("It's \(time)")
            
        case .weather:
            try await processQuery("What's the weather like today?")
            
        case .schedule:
            try await processQuery("What's on my schedule today?")
            
        case .reminders:
            try await processQuery("What are my reminders?")
            
        case .messages:
            try await processQuery("Do I have any new messages?")
            
        case .repeatLast:
            if let lastResponse = conversationHistory.last(where: { $0.role == .assistant }) {
                try await mentraOS.displayText(lastResponse.content)
            }
            
        case .clearHistory:
            conversationHistory.removeAll()
            conversationHistory.append(Message.system("Ready for new conversation."))
            try await mentraOS.displayText("✓ History cleared")
        }
    }
    
    // MARK: - Context Management
    
    /// Add document context to conversation
    func addDocumentContext(from documents: [ImportedDocument]) {
        guard !documents.isEmpty else { return }
        
        let contextMessage = Message.system("""
        Available documents for reference:
        \(documents.map { "• \($0.fileName ?? "Document")" }.joined(separator: "\n"))
        
        Use these if relevant to user queries.
        """)
        
        conversationHistory.insert(contextMessage, at: 1)
    }
    
    /// Summarize conversation for glasses display
    func summarizeConversation() async throws -> String {
        let userMessages = conversationHistory.filter { $0.role == .user }
        let assistantMessages = conversationHistory.filter { $0.role == .assistant }
        
        let summary = """
        📊 Session Summary:
        Questions asked: \(userMessages.count)
        Responses given: \(assistantMessages.count)
        
        Recent topics:
        \(userMessages.suffix(3).map { "• " + String($0.content.prefix(40)) + "..." }.joined(separator: "\n"))
        """
        
        return summary
    }
    
    // MARK: - Gesture Handling
    
    func handleGesture(_ gesture: GlassesGesture) async throws {
        switch gesture {
        case .tapOnce:
            // Repeat last response
            try await executeQuickCommand(.repeatLast)
            
        case .tapTwice:
            // Start new voice session
            try await startVoiceSession()
            
        case .swipeUp:
            // Next page (if paginated)
            print("📄 Next page")
            
        case .swipeDown:
            // Previous page (if paginated)
            print("📄 Previous page")
            
        case .swipeLeft:
            // Cancel current operation
            try await mentraOS.clearDisplay()
            print("❌ Cancelled")
            
        case .swipeRight:
            // Show summary
            let summary = try await summarizeConversation()
            try await mentraOS.displayText(summary)
        }
    }
}

// MARK: - Enums

enum QuickCommand {
    case whatTime
    case weather
    case schedule
    case reminders
    case messages
    case repeatLast
    case clearHistory
}

enum GlassesAssistantError: LocalizedError {
    case notConnected
    case generationFailed
    case displayFailed
    
    var errorDescription: String? {
        switch self {
        case .notConnected:
            return "Glasses not connected. Please connect via MentraOS."
        case .generationFailed:
            return "Failed to generate AI response."
        case .displayFailed:
            return "Failed to display on glasses."
        }
    }
}