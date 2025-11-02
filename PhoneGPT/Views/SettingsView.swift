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
    let mlxService: MLXService
    @Environment(\.dismiss) private var dismiss

    @State private var showingDeleteConfirmation = false
    @State private var modelStorageSize: String = "Calculating..."

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
                        Text("Model Storage Size")
                        Spacer()
                        Text(modelStorageSize)
                            .foregroundColor(.secondary)
                    }

                    if mlxService.hasDownloadedModels() {
                        Button(role: .destructive) {
                            showingDeleteConfirmation = true
                        } label: {
                            HStack {
                                Image(systemName: "trash")
                                Text("Delete Downloaded Models")
                            }
                        }
                    }
                } header: {
                    Text("Model Storage")
                } footer: {
                    Text("Downloaded models are stored locally on your device. Deleting them will free up space but require re-downloading when needed.")
                        .font(.caption)
                }

                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Privacy")
                        Spacer()
                        Text("100% On-Device")
                            .foregroundColor(.green)
                    }
                } header: {
                    Text("About")
                } footer: {
                    Text("PhoneGPT runs entirely on your device. No data leaves your device.")
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
            .alert("Delete Downloaded Models?", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteModels()
                }
            } message: {
                Text("This will delete all downloaded models from your device. You'll need to download them again when needed.")
            }
            .onAppear {
                updateStorageSize()
            }
        }
    }

    private func deleteModels() {
        do {
            try mlxService.deleteDownloadedModels()
            updateStorageSize()
        } catch {
            print("Error deleting models: \(error)")
        }
    }

    private func updateStorageSize() {
        modelStorageSize = mlxService.getModelStorageSize()
    }
}
