// MARK: - Fixed ChatView.swift for PhoneGPT-Zero
// ✅ Compatible with updated PersonalDataManager & ModelManager

import SwiftUI

struct ChatView: View {
    @EnvironmentObject var modelManager: ModelManager
    @StateObject private var dataManager = PersonalDataManager()
    @State private var prompt = ""
    @State private var messages: [ChatMessage] = []
    @State private var usePersonalData = true
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                HeaderView()
                    .environmentObject(modelManager)
                
                // Document Controls
                VStack(spacing: 10) {
                    // Toggle and status
                    HStack {
                        Toggle("Use My Documents", isOn: $usePersonalData)
                            .toggleStyle(.switch)
                        
                        Spacer()
                        
                        if dataManager.isIndexing {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Text("\(dataManager.indexedDocuments) chunks indexed")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Action buttons
                    HStack(spacing: 12) {
                        Button(action: {
                            dataManager.pickDocuments()
                        }) {
                            Label("Import Files", systemImage: "doc.badge.plus")
                                .font(.subheadline)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        
                        Button(action: {
                            dataManager.resetAll()
                        }) {
                            Label("Reset", systemImage: "arrow.clockwise")
                                .font(.subheadline)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .tint(.orange)
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 8)
                .background(Color(UIColor.secondarySystemBackground))
                
                // Chat messages
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            // Welcome message
                            if messages.isEmpty {
                                WelcomeMessage()
                                    .padding()
                            }
                            
                            ForEach(messages) { message in
                                MessageBubble(message: message)
                                    .id(message.id)
                            }
                            
                            if modelManager.isGenerating {
                                GeneratingView(
                                    progress: modelManager.generationProgress,
                                    currentOutput: modelManager.currentOutput
                                )
                            }
                        }
                        .padding()
                    }
                    .onChange(of: messages.count) { _, _ in
                        withAnimation {
                            proxy.scrollTo(messages.last?.id, anchor: .bottom)
                        }
                    }
                }
                
                // Input bar
                InputBar(
                    prompt: $prompt,
                    isInputFocused: _isInputFocused,
                    onSend: sendMessage
                )
            }
            .navigationBarHidden(true)
        }
    }
    
    private func sendMessage() {
        guard !prompt.isEmpty else { return }
        
        let userMessage = ChatMessage(
            role: .user,
            content: prompt
        )
        messages.append(userMessage)
        
        let currentPrompt = prompt
        prompt = ""
        isInputFocused = false
        
        Task {
            var finalPrompt = currentPrompt
            
            // Add document context if enabled
            if usePersonalData && dataManager.indexedDocuments > 0 {
                let context = dataManager.buildContext(for: currentPrompt)
                if !context.isEmpty {
                    finalPrompt = """
                    Context from documents:
                    \(context)
                    
                    Question: \(currentPrompt)
                    
                    Please answer based on the context above if relevant, otherwise answer generally.
                    """
                    print("📝 Using document context for response")
                }
            }
            
            // Get response from model
            let response = await modelManager.generate(
                prompt: finalPrompt,
                maxTokens: 150
            )
            
            let assistantMessage = ChatMessage(
                role: .assistant,
                content: response
            )
            
            await MainActor.run {
                messages.append(assistantMessage)
            }
        }
    }
}

// MARK: - Supporting Views

struct HeaderView: View {
    @EnvironmentObject var modelManager: ModelManager
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("PhoneGPT-Zero")
                    .font(.title2)
                    .fontWeight(.bold)
                
                HStack(spacing: 4) {
                    Circle()
                        .fill(modelManager.isModelLoaded ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    
                    Text(modelManager.isModelLoaded ? "Neural Engine Active" : "Loading...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                Text("\(Int(modelManager.tokensPerSecond)) tok/s")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .overlay(
            Divider(),
            alignment: .bottom
        )
    }
}

struct WelcomeMessage: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Welcome to PhoneGPT! 👋")
                .font(.headline)
            
            Text("I'm running entirely on your device using the Neural Engine. Your conversations and documents stay completely private.")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 8) {
                Label("Tap 'Import Files' to add PDFs, Word docs, or text files", systemImage: "doc.text")
                Label("Toggle 'Use My Documents' to search them", systemImage: "magnifyingglass")
                Label("Everything works offline", systemImage: "lock.shield")
            }
            .font(.caption)
            .foregroundColor(.secondary)
            
            Text("Try asking me something!")
                .font(.subheadline)
                .padding(.top, 8)
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
}

struct GeneratingView: View {
    let progress: Float
    let currentOutput: String
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                ProgressView()
                    .scaleEffect(0.7)
                
                Text("Generating...")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("\(Int(progress * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if !currentOutput.isEmpty {
                Text(currentOutput)
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(16)
            }
        }
    }
}

struct ChatMessage: Identifiable {
    let id = UUID()
    let role: Role
    let content: String
    
    enum Role {
        case user
        case assistant
    }
}
