//
//  LMModel.swift
//  PhoneGPT
//
//  Created by Darin Manley on 11/2/25.
//

import Foundation
import MLXLMCommon

/// Language model configuration
struct LMModel {
    /// Display name (e.g., "Phi-3-mini")
    let name: String

    /// MLX framework configuration
    let configuration: ModelConfiguration

    /// Model type: LLM only for now
    let type: ModelType

    /// Parameter count for reference
    let parameters: String?

    /// Model type enum
    enum ModelType {
        /// Large Language Model (text-only)
        case llm
    }

    init(
        name: String,
        configuration: ModelConfiguration,
        type: ModelType,
        parameters: String? = nil
    ) {
        self.name = name
        self.configuration = configuration
        self.type = type
        self.parameters = parameters
    }
}

// MARK: - Identifiable & Hashable

extension LMModel: Identifiable, Hashable {
    var id: String { name }

    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }

    static func == (lhs: LMModel, rhs: LMModel) -> Bool {
        lhs.name == rhs.name
    }
}

// MARK: - Display Helpers

extension LMModel {
    /// Display name
    var displayName: String {
        name
    }

    /// Whether this is a language model
    var isLanguageModel: Bool {
        type == .llm
    }

    /// Parameter count display (e.g., "1.5B", "3.8B")
    var parameterDisplay: String {
        parameters ?? "Unknown"
    }
}
