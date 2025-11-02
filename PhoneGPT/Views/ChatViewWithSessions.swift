import SwiftUI

struct ChatViewWithSessions: View {
    @EnvironmentObject var modelManager: ModelManager
    @StateObject private var dataManager = PersonalDataManager()
    @StateObject private var sessionManager = ChatSessionManager()

    @State private var prompt = ""
    @State private var usePersonalData = true
    @State private var showSidebar = false
    @FocusState private var isInputFocused: Bool

    var body: some View {
        let _ = modelManager.dataManager = dataManager

        NavigationStack {
            ZStack {
                HStack(spacing: 0) {
                    if showSidebar {
                        SessionSidebar(
                            sessionManager: sessionManager,
                            showSidebar: $showSidebar
                        )
                        .frame(width: 280)
                        .transition(.move(edge: .leading))
                    }

                    MainChatView(
                        modelManager: modelManager,
                        dataManager: dataManager,
                        sessionManager: sessionManager,
                        prompt: $prompt,
                        usePersonalData: $usePersonalData,
                        isInputFocused: $isInputFocused,
                        showSidebar: $showSidebar
                    )
                }
            }
            .animation(.easeInOut(duration: 0.3), value: showSidebar)
        }
    }
}

struct SessionSidebar: View {
    @ObservedObject var sessionManager: ChatSessionManager
    @Binding var showSidebar: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Chat History")
                    .font(.headline)
                    .foregroundColor(.primary)

                Spacer()

                Button(action: {
                    Task {
                        await sessionManager.createNewSession()
                        showSidebar = false
                    }
                }) {
                    Image(systemName: "square.and.pencil")
                        .font(.title3)
                }
            }
            .padding()
            .background(Color(.systemBackground))

            Divider()

            if sessionManager.isLoading {
                ProgressView()
                    .padding()
                Spacer()
            } else if sessionManager.sessions.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)

                    Text("No conversations yet")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    Text("Start a new chat to begin")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(sessionManager.sessions) { session in
                            SessionRow(
                                session: session,
                                isSelected: sessionManager.currentSession?.id == session.id,
                                onSelect: {
                                    Task {
                                        await sessionManager.selectSession(session)
                                        showSidebar = false
                                    }
                                },
                                onDelete: {
                                    Task {
                                        await sessionManager.deleteSession(session)
                                    }
                                }
                            )
                        }
                    }
                }
            }
        }
        .background(Color(.systemGroupedBackground))
    }
}

struct SessionRow: View {
    let session: ChatSession
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void

    @State private var showDeleteConfirmation = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Image(systemName: "bubble.left")
                    .font(.title3)
                    .foregroundColor(isSelected ? .white : .secondary)

                VStack(alignment: .leading, spacing: 4) {
                    Text(session.title)
                        .font(.subheadline)
                        .fontWeight(isSelected ? .semibold : .regular)
                        .foregroundColor(isSelected ? .white : .primary)
                        .lineLimit(2)

                    HStack {
                        Text("\(session.messageCount) messages")
                            .font(.caption)
                            .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)

                        Spacer()

                        Text(session.updatedAt, style: .relative)
                            .font(.caption)
                            .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(isSelected ? Color.blue : Color.clear)
            .cornerRadius(8)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive, action: {
                showDeleteConfirmation = true
            }) {
                Label("Delete", systemImage: "trash")
            }
        }
        .confirmationDialog(
            "Delete this conversation?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                onDelete()
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}

struct MainChatView: View {
    @ObservedObject var modelManager: ModelManager
    @ObservedObject var dataManager: PersonalDataManager
    @ObservedObject var sessionManager: ChatSessionManager

    @Binding var prompt: String
    @Binding var usePersonalData: Bool
    @FocusState.Binding var isInputFocused: Bool
    @Binding var showSidebar: Bool

    var body: some View {
        VStack(spacing: 0) {
            ChatHeaderView(
                sessionManager: sessionManager,
                dataManager: dataManager,
                usePersonalData: $usePersonalData,
                showSidebar: $showSidebar
            )

            Divider()

            if sessionManager.currentMessages.isEmpty {
                EmptyStateView()
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(sessionManager.currentMessages) { message in
                                MessageBubbleView(message: message)
                                    .id(message.id)
                            }
                        }
                        .padding()
                    }
                    .onChange(of: sessionManager.currentMessages.count) { _ in
                        if let lastMessage = sessionManager.currentMessages.last {
                            withAnimation {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }
            }

            Divider()

            InputBarView(
                prompt: $prompt,
                isInputFocused: $isInputFocused,
                isGenerating: modelManager.isGenerating,
                onSend: {
                    sendMessage()
                }
            )
        }
        .background(Color(.systemBackground))
    }

    private func sendMessage() {
        guard !prompt.isEmpty else { return }

        let currentPrompt = prompt
        prompt = ""
        isInputFocused = false

        Task {
            await sessionManager.addMessage(role: .user, content: currentPrompt)

            let response: String

            if usePersonalData && dataManager.indexedDocuments > 0 {
                print("🚀 Using full RAG pipeline with conversation history")
                let conversationHistory = sessionManager.getConversationHistory(limit: 10)
                response = await modelManager.generateRAGResponse(
                    for: currentPrompt,
                    conversationHistory: conversationHistory
                )
            } else {
                print("💬 Using simple response (no documents)")
                response = await modelManager.generate(
                    prompt: currentPrompt,
                    maxTokens: 150
                )
            }

            await sessionManager.addMessage(
                role: .assistant,
                content: response,
                metadata: ["tokens_per_sec": "\(modelManager.tokensPerSecond)"]
            )
        }
    }
}

struct ChatHeaderView: View {
    @ObservedObject var sessionManager: ChatSessionManager
    @ObservedObject var dataManager: PersonalDataManager
    @Binding var usePersonalData: Bool
    @Binding var showSidebar: Bool

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Button(action: {
                    withAnimation {
                        showSidebar.toggle()
                    }
                }) {
                    Image(systemName: showSidebar ? "sidebar.left.fill" : "sidebar.left")
                        .font(.title2)
                        .foregroundColor(.blue)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(sessionManager.currentSession?.title ?? "PhoneGPT")
                        .font(.headline)

                    if let session = sessionManager.currentSession {
                        Text("\(session.messageCount) messages")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                Button(action: {
                    Task {
                        await sessionManager.createNewSession()
                    }
                }) {
                    Image(systemName: "square.and.pencil")
                        .font(.title3)
                        .foregroundColor(.blue)
                }
            }

            HStack {
                Toggle("Use My Documents", isOn: $usePersonalData)
                    .toggleStyle(.switch)
                    .controlSize(.small)

                Spacer()

                if dataManager.isIndexing {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Text("\(dataManager.indexedDocuments) chunks")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            HStack(spacing: 12) {
                Button(action: {
                    dataManager.pickDocuments()
                }) {
                    Label("Import", systemImage: "doc.badge.plus")
                        .font(.subheadline)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button(action: {
                    dataManager.resetAll()
                }) {
                    Label("Reset", systemImage: "arrow.clockwise")
                        .font(.subheadline)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding()
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "brain.head.profile")
                .font(.system(size: 64))
                .foregroundColor(.blue)

            Text("PhoneGPT")
                .font(.title)
                .fontWeight(.bold)

            Text("Your private, on-device AI assistant")
                .font(.subheadline)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                Label("Fully local - no cloud required", systemImage: "checkmark.circle.fill")
                Label("RAG-powered with your documents", systemImage: "checkmark.circle.fill")
                Label("Context-aware conversations", systemImage: "checkmark.circle.fill")
            }
            .font(.caption)
            .foregroundColor(.secondary)

            Spacer()
        }
        .padding()
    }
}

struct MessageBubbleView: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .assistant {
                Image(systemName: "brain")
                    .font(.title3)
                    .foregroundColor(.blue)
                    .frame(width: 32, height: 32)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(Circle())
            } else {
                Spacer()
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .padding(12)
                    .background(message.role == .user ? Color.blue : Color(.systemGray5))
                    .foregroundColor(message.role == .user ? .white : .primary)
                    .cornerRadius(16)

                Text(message.createdAt, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            if message.role == .user {
                Image(systemName: "person.circle.fill")
                    .font(.title3)
                    .foregroundColor(.gray)
            } else {
                Spacer()
            }
        }
    }
}

struct InputBarView: View {
    @Binding var prompt: String
    @FocusState.Binding var isInputFocused: Bool
    let isGenerating: Bool
    let onSend: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            TextField("Ask anything...", text: $prompt, axis: .vertical)
                .textFieldStyle(.plain)
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(20)
                .focused($isInputFocused)
                .lineLimit(1...5)
                .onSubmit {
                    if !isGenerating {
                        onSend()
                    }
                }

            Button(action: onSend) {
                Image(systemName: isGenerating ? "stop.circle.fill" : "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(prompt.isEmpty ? .gray : .blue)
            }
            .disabled(prompt.isEmpty || isGenerating)
        }
        .padding()
    }
}
