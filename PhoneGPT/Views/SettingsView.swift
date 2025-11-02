//
//  SettingsView.swift
//  PhoneGPT
//
//  Created by Darin Manley on 11/2/25.
//

import SwiftUI

struct SettingsView: View {
    @Bindable var settings: AppSettings
    let importedDocuments: [ImportedDocument]
    let onClearDocuments: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Use My Documents", isOn: $settings.useDocuments)
                } header: {
                    Text("Document Settings")
                } footer: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("When enabled, PhoneGPT will use your imported documents to provide context-aware responses.")

                        if !importedDocuments.isEmpty {
                            Text("💡 Pro Tip: Documents are specific to each chat session. Import documents using the '+' button next to the message input.")
                                .font(.caption)
                                .foregroundColor(.blue)
                                .padding(.top, 4)
                        }
                    }
                }

                if !importedDocuments.isEmpty {
                    Section {
                        ForEach(importedDocuments, id: \.id) { document in
                            HStack {
                                Image(systemName: "doc.text.fill")
                                    .foregroundColor(.blue)
                                VStack(alignment: .leading) {
                                    Text(document.fileName ?? "Unknown")
                                        .font(.subheadline)
                                    Text(document.importedAt?.formatted(date: .abbreviated, time: .shortened) ?? "")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }

                        Button(role: .destructive, action: onClearDocuments) {
                            HStack {
                                Image(systemName: "trash")
                                Text("Clear All Documents")
                            }
                        }
                    } header: {
                        Text("Imported Documents (\(importedDocuments.count))")
                    } footer: {
                        Text("💡 Pro Tip: Clearing documents removes them from this chat session only. You can re-import them anytime.")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }

                Section {
                    HStack {
                        Text("Temperature")
                        Spacer()
                        Text(String(format: "%.1f", settings.temperature))
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $settings.temperature, in: 0...1, step: 0.1)

                    HStack {
                        Text("Max Tokens")
                        Spacer()
                        Text("\(settings.maxTokens)")
                            .foregroundColor(.secondary)
                    }
                    Slider(value: Binding(
                        get: { Double(settings.maxTokens) },
                        set: { settings.maxTokens = Int($0) }
                    ), in: 128...2048, step: 128)
                } header: {
                    Text("Generation Settings")
                } footer: {
                    Text("Temperature controls randomness (0 = focused, 1 = creative). Max tokens limits response length.")
                }

                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Model Storage")
                        Spacer()
                        Text("Local")
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("About")
                } footer: {
                    Text("PhoneGPT runs entirely on your device. Models are downloaded once and cached locally. No data leaves your device unless you explicitly enable cloud features in settings.")
                        .font(.caption)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
