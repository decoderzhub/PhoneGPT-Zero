//
//  Message.swift
//  PhoneGPT
//
//  Created by Darin Manley on 11/2/25.
//

import Foundation

/// Unified message model compatible with MLXLMCommon
struct Message: Identifiable, Codable {
    /// Unique identifier
    let id: String = UUID().uuidString

    /// Message role (system, user, assistant)
    let role: Role

    /// Message content
    var content: String

    /// Attached images (for vision models)
    let images: [URL]

    /// Attached videos (for vision models)
    let videos: [URL]

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
        role: Role,
        content: String,
        images: [URL] = [],
        videos: [URL] = [],
        timestamp: Date = Date()
    ) {
        self.role = role
        self.content = content
        self.images = images
        self.videos = videos
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
