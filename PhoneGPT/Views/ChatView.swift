//
//  ChatView.swift
//  PhoneGPT
//
//  Created by Darin Manley on 11/2/25.
//

import SwiftUI
import UniformTypeIdentifiers

struct ChatView: View {
    @State private var viewModel: ChatViewModel
    @State private var databaseService: DatabaseService
    @State private var settings: AppSettings

    @State private var sessions: [ChatSession] = []
    @State private var showingSidebar = false
    @State private var showingSettings = false
    @State private var showingDocumentPicker = false
    @State private var scrollProxy: ScrollViewProxy?
    @FocusState private var isInputFocused: Bool
    @State private var showingDownloadAlert = false
    @State private var downloadProgress: Double = 0.0
    @State private var downloadingModelName: String = ""
    @State private var hasModel = false

    init(viewModel: ChatViewModel, databaseService: DatabaseService, settings: AppSettings) {
        self._viewModel = State(initialValue: viewModel)
        self._databaseService = State(initialValue: databaseService)
        self._settings = State(initialValue: settings)
    }

    var body: some View {
        NavigationStack {
            HStack(spacing: 0) {
                if showingSidebar {
                    SidebarView(
                        selectedSession: Binding(
                            get: { viewModel.currentSession },
                            set: {
                                if let session = $0 {
                                    viewModel.loadSession(session)
                                    withAnimation {
                                        showingSidebar = false
                                    }
                                }
                            }
                        ),
                        showingSettings: $showingSettings,
                        sessions: sessions,
                        onNewChat: {
                            viewModel.createNewSession()
                            loadSessions()
                            withAnimation {
                                showingSidebar = false
                            }
                        },
                        onDeleteSession: { session in
                            databaseService.deleteSession(session)
                            loadSessions()
                            if viewModel.currentSession?.id == session.id {
                                viewModel.createNewSession()
                            }
                        }
                    )
                    .frame(width: 280)
                    .transition(.move(edge: .leading))
                }

                chatContent
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { withAnimation { showingSidebar.toggle() } }) {
                        Image(systemName: showingSidebar ? "sidebar.left.fill" : "sidebar.left")
                    }
                }

                ToolbarItem(placement: .principal) {
                    Text(viewModel.currentSession?.title ?? "PhoneGPT")
                        .font(.headline)
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView(
                    settings: settings,
                    importedDocuments: viewModel.getImportedDocuments(),
                    onClearDocuments: {
                        viewModel.clearDocuments()
                    },
                    mlxService: viewModel.getMLXService()
                )
            }
            .sheet(isPresented: $showingDocumentPicker) {
                DocumentPicker { urls in
                    Task {
                        for url in urls {
                            try? await viewModel.importDocument(url: url)
                        }
                    }
                }
            }
            .onAppear {
                loadSessions()
                if viewModel.currentSession == nil {
                    viewModel.createNewSession()
                    loadSessions()
                }
                startMonitoringDownloads()
            }
        }
    }

    private var chatContent: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    if !hasModel && viewModel.messages.isEmpty {
                        VStack(spacing: 20) {
                            Spacer()

                            Image(systemName: "cpu.fill")
                                .font(.system(size: 64))
                                .foregroundColor(.blue)

                            Text("No AI Model Installed")
                                .font(.title2)
                                .fontWeight(.bold)

                            Text("Download an AI model to start chatting with PhoneGPT")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)

                            Button(action: {
                                Task {
                                    await viewModel.send()
                                }
                            }) {
                                HStack {
                                    Image(systemName: "arrow.down.circle.fill")
                                    Text("Download Model")
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(Color.blue)
                                .cornerRadius(10)
                            }

                            Spacer()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        LazyVStack(spacing: 16) {
                            ForEach(Array(viewModel.messages.enumerated()), id: \.element.id) { index, message in
                                if message.role != .system {
                                    MessageBubble(message: message)
                                        .id(index)
                                }
                            }
                        }
                        .padding()
                    }
                }
                .onAppear {
                    scrollProxy = proxy
                }
                .onChange(of: viewModel.messages.count) { _, _ in
                    if let lastIndex = viewModel.messages.indices.last {
                        withAnimation {
                            proxy.scrollTo(lastIndex, anchor: .bottom)
                        }
                    }
                }
            }

            Divider()

            if showingDownloadAlert {
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundColor(.blue)
                        Text("⚠️ Downloading Model: \(downloadingModelName)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                        Text("\(Int(downloadProgress * 100))%")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 8)

                    ProgressView(value: downloadProgress)
                        .progressViewStyle(LinearProgressViewStyle())
                        .padding(.horizontal, 12)

                    Text("Please wait while the AI model downloads. Internet connection required.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 8)
                }
                .background(Color(UIColor.secondarySystemBackground))
            }

            HStack(spacing: 12) {
                Button(action: { showingDocumentPicker = true }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.blue)
                }
                .disabled(showingDownloadAlert)
                .opacity(showingDownloadAlert ? 0.5 : 1.0)

                InputBar(
                    prompt: $viewModel.prompt,
                    isInputFocused: _isInputFocused,
                    isLoading: viewModel.isGenerating,
                    onSend: {
                        Task {
                            await viewModel.send()
                        }
                    }
                )
                .disabled(showingDownloadAlert)
                .opacity(showingDownloadAlert ? 0.5 : 1.0)
            }
            .padding(.horizontal, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func loadSessions() {
        sessions = databaseService.fetchAllSessions()
    }

    private func startMonitoringDownloads() {
        Task {
            let mlxService = viewModel.getMLXService()
            hasModel = mlxService.hasDownloadedModels()

            while true {
                try? await Task.sleep(nanoseconds: 100_000_000)

                if mlxService.isDownloading {
                    showingDownloadAlert = true
                    downloadProgress = mlxService.downloadProgress
                    downloadingModelName = mlxService.downloadingModelName
                } else if showingDownloadAlert {
                    showingDownloadAlert = false
                    hasModel = mlxService.hasDownloadedModels()
                }
            }
        }
    }
}

struct DocumentPicker: UIViewControllerRepresentable {
    let onPick: ([URL]) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [
            .plainText,
            .pdf,
            .text,
            UTType(filenameExtension: "md")!,
            UTType(filenameExtension: "txt")!
        ], asCopy: true)
        picker.allowsMultipleSelection = true
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: ([URL]) -> Void

        init(onPick: @escaping ([URL]) -> Void) {
            self.onPick = onPick
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            onPick(urls)
        }
    }
}
