//
//  ChatView.swift
//  PhoneGPT
//
//  Created by Darin Manley on 11/2/25.
//

import SwiftUI

struct ChatView: View {
    @State private var viewModel = ChatViewModel()
    @StateObject private var dataManager = PersonalDataManager()
    @State private var usePersonalData = false
    @FocusState private var isInputFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HeaderView(
                    viewModel: viewModel,
                    onModelChange: { }
                )

                if let progress = viewModel.downloadProgress {
                    DownloadProgressView(progress: progress)
                }

                DocumentControlsView(
                    dataManager: dataManager,
                    usePersonalData: $usePersonalData
                )

                ZStack {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 12) {
                                if viewModel.messages.count <= 1 {
                                    WelcomeMessageView()
                                        .padding()
                                }

                                ForEach(viewModel.messages) { message in
                                    if message.role != .system {
                                        MessageBubble(message: message)
                                            .id(message.id)
                                    }
                                }

                                if viewModel.isGenerating {
                                    GeneratingIndicator(
                                        tokensPerSecond: viewModel.tokensPerSecond
                                    )
                                    .id("generating")
                                }
                            }
                            .padding()
                        }
                        .onChange(of: viewModel.messages.count) { _, _ in
                            withAnimation {
                                proxy.scrollTo("generating", anchor: .bottom)
                            }
                        }
                    }

                    if let error = viewModel.errorMessage {
                        VStack {
                            Spacer()

                            ErrorBannerView(message: error) {
                                viewModel.errorMessage = nil
                            }
                            .padding()
                        }
                    }
                }

                InputBar(
                    prompt: $viewModel.prompt,
                    isInputFocused: _isInputFocused,
                    isLoading: viewModel.isGenerating || viewModel.isDownloading,
                    onSend: {
                        Task {
                            await viewModel.send()
                        }
                    }
                )
            }
        }
        .navigationBarHidden(true)
        .preferredColorScheme(.dark)
    }
}

// MARK: - Header

struct HeaderView: View {
    let viewModel: ChatViewModel
    let onModelChange: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                Text("PhoneGPT-Zero")
                    .font(.title2)
                    .fontWeight(.bold)

                HStack(spacing: 12) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)

                    Text("Neural Engine")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    if viewModel.isGenerating {
                        Text("\(Int(viewModel.tokensPerSecond)) tok/s")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                if viewModel.isDownloading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .frame(height: 20)
                }
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

// MARK: - Download Progress

struct DownloadProgressView: View {
    let progress: Progress

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Downloading model...")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Text("\(Int(progress.fractionCompleted * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            ProgressView(value: progress.fractionCompleted)
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
    }
}

// MARK: - Document Controls

struct DocumentControlsView: View {
    let dataManager: PersonalDataManager
    @Binding var usePersonalData: Bool

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Toggle("Use My Documents", isOn: $usePersonalData)
                    .toggleStyle(.switch)

                Spacer()

                if dataManager.isIndexing {
                    ProgressView()
                        .scaleEffect(0.75)
                } else {
                    Text("\(dataManager.indexedDocuments) chunks")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            HStack(spacing: 8) {
                Button(action: { dataManager.pickDocuments() }) {
                    Label("Import", systemImage: "doc.badge.plus")
                        .font(.caption)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                Button(action: { dataManager.resetAll() }) {
                    Label("Reset", systemImage: "arrow.clockwise")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
    }
}

// MARK: - Welcome Message

struct WelcomeMessageView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Welcome to PhoneGPT! 👋")
                .font(.headline)

            Text("I'm running on your device using the Neural Engine. Everything stays private and works offline.")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Divider()
                .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)

                    Text("No internet required")
                        .font(.caption)
                }

                HStack(spacing: 8) {
                    Image(systemName: "lock.fill")
                        .foregroundColor(.green)
                        .font(.caption)

                    Text("Your data stays on device")
                        .font(.caption)
                }

                HStack(spacing: 8) {
                    Image(systemName: "bolt.fill")
                        .foregroundColor(.green)
                        .font(.caption)

                    Text("Instant responses")
                        .font(.caption)
                }
            }

            Divider()
                .padding(.vertical, 4)

            Text("Just start typing or ask me anything!")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Generating Indicator

struct GeneratingIndicator: View {
    let tokensPerSecond: Double

    var body: some View {
        HStack(spacing: 12) {
            ProgressView()
                .scaleEffect(0.8)

            Text("Generating...")
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()

            if tokensPerSecond > 0 {
                Text("\(Int(tokensPerSecond)) tok/s")
                    .font(.caption2)
                    .foregroundColor(.blue)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Error Banner

struct ErrorBannerView: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundColor(.red)

                Text(message)
                    .font(.caption)
                    .lineLimit(3)

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(UIColor.systemRed).opacity(0.1))
        .cornerRadius(8)
    }
}

#Preview {
    ChatView()
}
