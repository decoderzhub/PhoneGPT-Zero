import Foundation
import Supabase

struct ChatSession: Identifiable, Codable {
    let id: UUID
    var title: String
    let createdAt: Date
    var updatedAt: Date
    let deviceId: String
    var messageCount: Int

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deviceId = "device_id"
        case messageCount = "message_count"
    }
}

struct ChatMessage: Identifiable, Codable {
    let id: UUID
    let sessionId: UUID
    let role: MessageRole
    let content: String
    let createdAt: Date
    var metadata: [String: String]

    enum CodingKeys: String, CodingKey {
        case id
        case sessionId = "session_id"
        case role
        case content
        case createdAt = "created_at"
        case metadata
    }

    enum MessageRole: String, Codable {
        case user
        case assistant
    }

    init(id: UUID = UUID(), sessionId: UUID, role: MessageRole, content: String, metadata: [String: String] = [:]) {
        self.id = id
        self.sessionId = sessionId
        self.role = role
        self.content = content
        self.createdAt = Date()
        self.metadata = metadata
    }
}

@MainActor
class ChatSessionManager: ObservableObject {
    @Published var sessions: [ChatSession] = []
    @Published var currentSession: ChatSession?
    @Published var currentMessages: [ChatMessage] = []
    @Published var isLoading = false

    private let supabase: SupabaseClient
    private let deviceId: String

    init() {
        guard let supabaseURL = Bundle.main.object(forInfoDictionaryKey: "VITE_SUPABASE_URL") as? String,
              let supabaseKey = Bundle.main.object(forInfoDictionaryKey: "VITE_SUPABASE_SUPABASE_ANON_KEY") as? String,
              let url = URL(string: supabaseURL) else {
            fatalError("Supabase configuration missing in Info.plist")
        }

        self.supabase = SupabaseClient(supabaseURL: url, supabaseKey: supabaseKey)
        self.deviceId = UIDevice.current.identifierForVendor?.uuidString ?? "unknown"

        Task {
            await loadSessions()
        }
    }

    func loadSessions() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let response: [ChatSession] = try await supabase
                .from("chat_sessions")
                .select()
                .eq("device_id", value: deviceId)
                .order("updated_at", ascending: false)
                .execute()
                .value

            sessions = response

            if currentSession == nil, let firstSession = sessions.first {
                await selectSession(firstSession)
            }

            print("✅ Loaded \(sessions.count) chat sessions")
        } catch {
            print("❌ Error loading sessions: \(error)")
            sessions = []
        }
    }

    func createNewSession(title: String = "New Chat") async {
        isLoading = true
        defer { isLoading = false }

        do {
            let newSession = ChatSession(
                id: UUID(),
                title: title,
                createdAt: Date(),
                updatedAt: Date(),
                deviceId: deviceId,
                messageCount: 0
            )

            let response: ChatSession = try await supabase
                .from("chat_sessions")
                .insert(newSession)
                .select()
                .single()
                .execute()
                .value

            sessions.insert(response, at: 0)
            currentSession = response
            currentMessages = []

            print("✅ Created new session: \(response.title)")
        } catch {
            print("❌ Error creating session: \(error)")
        }
    }

    func selectSession(_ session: ChatSession) async {
        currentSession = session
        await loadMessages(for: session.id)
    }

    func loadMessages(for sessionId: UUID) async {
        isLoading = true
        defer { isLoading = false }

        do {
            let response: [ChatMessage] = try await supabase
                .from("chat_messages")
                .select()
                .eq("session_id", value: sessionId.uuidString)
                .order("created_at", ascending: true)
                .execute()
                .value

            currentMessages = response

            print("✅ Loaded \(response.count) messages for session")
        } catch {
            print("❌ Error loading messages: \(error)")
            currentMessages = []
        }
    }

    func addMessage(role: ChatMessage.MessageRole, content: String, metadata: [String: String] = [:]) async {
        guard let session = currentSession else {
            print("⚠️ No current session - creating new one")
            await createNewSession()
            guard let session = currentSession else { return }
            await addMessage(role: role, content: content, metadata: metadata)
            return
        }

        do {
            let message = ChatMessage(
                sessionId: session.id,
                role: role,
                content: content,
                metadata: metadata
            )

            let response: ChatMessage = try await supabase
                .from("chat_messages")
                .insert(message)
                .select()
                .single()
                .execute()
                .value

            currentMessages.append(response)

            if currentMessages.count == 1 {
                await updateSessionTitle(generateTitle(from: content))
            }

            print("✅ Added \(role.rawValue) message to session")
        } catch {
            print("❌ Error adding message: \(error)")
        }
    }

    func updateSessionTitle(_ newTitle: String) async {
        guard let session = currentSession else { return }

        do {
            let updatedSession = ChatSession(
                id: session.id,
                title: newTitle,
                createdAt: session.createdAt,
                updatedAt: Date(),
                deviceId: session.deviceId,
                messageCount: session.messageCount
            )

            try await supabase
                .from("chat_sessions")
                .update(updatedSession)
                .eq("id", value: session.id.uuidString)
                .execute()

            if let index = sessions.firstIndex(where: { $0.id == session.id }) {
                sessions[index].title = newTitle
            }
            currentSession = updatedSession

            print("✅ Updated session title: \(newTitle)")
        } catch {
            print("❌ Error updating session title: \(error)")
        }
    }

    func deleteSession(_ session: ChatSession) async {
        do {
            try await supabase
                .from("chat_sessions")
                .delete()
                .eq("id", value: session.id.uuidString)
                .execute()

            sessions.removeAll { $0.id == session.id }

            if currentSession?.id == session.id {
                currentSession = sessions.first
                if let firstSession = sessions.first {
                    await loadMessages(for: firstSession.id)
                } else {
                    currentMessages = []
                }
            }

            print("✅ Deleted session: \(session.title)")
        } catch {
            print("❌ Error deleting session: \(error)")
        }
    }

    func getConversationHistory(limit: Int = 10) -> String {
        let recentMessages = currentMessages.suffix(limit)

        var history = ""
        for message in recentMessages {
            let role = message.role == .user ? "User" : "Assistant"
            history += "\(role): \(message.content)\n\n"
        }

        return history
    }

    private func generateTitle(from content: String) -> String {
        let words = content.split(separator: " ").prefix(6)
        let title = words.joined(separator: " ")
        return title.count > 50 ? String(title.prefix(50)) + "..." : String(title)
    }
}
