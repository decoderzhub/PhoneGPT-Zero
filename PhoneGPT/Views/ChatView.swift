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
            .alert("Downloading Model", isPresented: $showingDownloadAlert) {
                EmptyView()
            } message: {
                VStack {
                    Text("⚠️ Connecting to Internet")
                        .font(.headline)
                    Text("\nDownloading \(downloadingModelName)")
                    Text("\nProgress: \(Int(downloadProgress * 100))%")
                }
            }
        }
    }

    private var chatContent: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
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

            HStack(spacing: 12) {
                Button(action: { showingDocumentPicker = true }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.blue)
                }

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
            while true {
                try? await Task.sleep(nanoseconds: 100_000_000)

                if mlxService.isDownloading {
                    showingDownloadAlert = true
                    downloadProgress = mlxService.downloadProgress
                    downloadingModelName = mlxService.downloadingModelName
                } else if showingDownloadAlert {
                    showingDownloadAlert = false
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
