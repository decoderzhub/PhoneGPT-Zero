//
//  Message.swift
//  PhoneGPT
//
//  Created by Darin Manley on 11/2/25.
//

import Foundation

/// Unified message model compatible with MLXLMCommon
struct Message: Identifiable, Codable {
    /// Unique identifier - Generated per instance
    let id: String

    /// Message role (system, user, assistant)
    let role: Role

    /// Message content
    var content: String

    /// When the message was created
    let timestamp: Date

    /// Message role enum
    enum Role: String, Codable {
        case user
        case assistant
        case system
    }

    // MARK: - Initializers

    init(
        id: String = UUID().uuidString,
        role: Role,
        content: String,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
    }

    /// Create a system message
    static func system(_ content: String) -> Self {
        .init(role: .system, content: content)
    }

    /// Create a user message
    static func user(_ content: String) -> Self {
        .init(role: .user, content: content)
    }

    /// Create an assistant message
    static func assistant(_ content: String) -> Self {
        .init(role: .assistant, content: content)
    }
}
