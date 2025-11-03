//
//  GlassesAssistantView.swift
//  PhoneGPT
//
//  Created by Darin Manley on 11/2/25.
//


//
//  GlassesAssistantView.swift
//  PhoneGPT
//
//  UI for controlling Even Realities glasses AI assistant
//

import SwiftUI

struct GlassesAssistantView: View {
    @StateObject private var mentraOS = MentraOSService()
    @State private var glassesVM: GlassesAssistantViewModel?
    
    let chatViewModel: ChatViewModel
    let mlxService: MLXService
    
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var isConnecting = false
    @State private var showingQuickCommands = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                if !mentraOS.isConnected {
                    connectionView
                } else {
                    assistantView
                }
            }
            .navigationTitle("Glasses Assistant")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .task {
                if glassesVM == nil {
                    glassesVM = GlassesAssistantViewModel(
                        mentraOS: mentraOS,
                        mlxService: mlxService,
                        chatViewModel: chatViewModel
                    )
                }
            }
        }
    }
    
    // MARK: - Connection View
    
    private var connectionView: some View {
        VStack(spacing: 32) {
            Spacer()
            
            VStack(spacing: 16) {
                Image(systemName: "eyeglasses")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                    .frame(width: 120, height: 120)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(20)
                
                VStack(spacing: 8) {
                    Text("Even Realities G1")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Smart Glasses Assistant")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            VStack(alignment: .leading, spacing: 16) {
                ConnectionStep(
                    number: 1,
                    title: "Install MentraOS",
                    description: "Download from App Store if not installed",
                    isComplete: mentraOS.isConnected
                )
                
                ConnectionStep(
                    number: 2,
                    title: "Pair Your Glasses",
                    description: "Connect G1 glasses in MentraOS app",
                    isComplete: mentraOS.glassesConnected
                )
                
                ConnectionStep(
                    number: 3,
                    title: "Connect PhoneGPT",
                    description: "Tap Connect to enable AI assistant",
                    isComplete: false
                )
            }
            .padding(.horizontal, 24)
            
            Spacer()
            
            VStack(spacing: 12) {
                Button(action: {
                    connectToMentraOS()
                }) {
                    HStack {
                        if isConnecting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Image(systemName: "link.circle.fill")
                            Text("Connect to MentraOS")
                        }
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(isConnecting ? Color.gray : Color.blue)
                    .cornerRadius(12)
                }
                .disabled(isConnecting)
                
                Button(action: {
                    openMentraOSApp()
                }) {
                    HStack {
                        Image(systemName: "arrow.up.forward.app")
                        Text("Open MentraOS")
                    }
                    .font(.headline)
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }
    
    // MARK: - Assistant View
    
    private var assistantView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Status Card
                statusCard
                
                // Main Actions
                VStack(spacing: 16) {
                    // Voice Session Button
                    Button(action: {
                        startVoiceSession()
                    }) {
                        HStack {
                            Image(systemName: glassesVM?.isListening == true ? "waveform" : "mic.circle.fill")
                                .font(.title)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(glassesVM?.isListening == true ? "Listening..." : "Start Voice Session")
                                    .font(.headline)
                                
                                Text(glassesVM?.isListening == true ? "Speak now" : "Tap to activate voice assistant")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                    }
                    .disabled(glassesVM?.isProcessing == true)
                    
                    // Quick Commands
                    Button(action: {
                        showingQuickCommands.toggle()
                    }) {
                        HStack {
                            Image(systemName: "bolt.circle.fill")
                                .font(.title)
                                .foregroundColor(.orange)
                            
                            Text("Quick Commands")
                                .font(.headline)
                            
                            Spacer()
                            
                            Image(systemName: showingQuickCommands ? "chevron.up" : "chevron.down")
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal)
                
                // Quick Commands List
                if showingQuickCommands {
                    quickCommandsList
                }
                
                // Current Response
                if let vm = glassesVM, !vm.currentResponse.isEmpty {
                    currentResponseCard
                }
                
                // Conversation History
                conversationHistorySection
            }
            .padding(.vertical)
        }
    }
    
    private var statusCard: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                // MentraOS Status
                StatusIndicator(
                    icon: "app.badge.checkmark",
                    label: "MentraOS",
                    isActive: mentraOS.isConnected,
                    color: .blue
                )
                
                Divider()
                    .frame(height: 40)
                
                // Glasses Status
                StatusIndicator(
                    icon: "eyeglasses",
                    label: "Glasses",
                    isActive: mentraOS.glassesConnected,
                    color: .green
                )
                
                Divider()
                    .frame(height: 40)
                
                // AI Status
                StatusIndicator(
                    icon: "brain",
                    label: "AI",
                    isActive: glassesVM?.isProcessing == false,
                    color: .purple
                )
            }
            .padding()
            
            if let vm = glassesVM, vm.isProcessing {
                ProgressView("Processing query...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
        .padding(.horizontal)
    }
    
    private var quickCommandsList: some View {
        VStack(spacing: 12) {
            QuickCommandRow(
                icon: "clock.fill",
                title: "What time is it?",
                command: .whatTime,
                onTap: { command in
                    executeQuickCommand(command)
                }
            )
            
            QuickCommandRow(
                icon: "cloud.sun.fill",
                title: "Weather",
                command: .weather,
                onTap: { command in
                    executeQuickCommand(command)
                }
            )
            
            QuickCommandRow(
                icon: "calendar",
                title: "My Schedule",
                command: .schedule,
                onTap: { command in
                    executeQuickCommand(command)
                }
            )
            
            QuickCommandRow(
                icon: "bell.fill",
                title: "Reminders",
                command: .reminders,
                onTap: { command in
                    executeQuickCommand(command)
                }
            )
            
            QuickCommandRow(
                icon: "message.fill",
                title: "Messages",
                command: .messages,
                onTap: { command in
                    executeQuickCommand(command)
                }
            )
            
            QuickCommandRow(
                icon: "arrow.counterclockwise",
                title: "Repeat Last",
                command: .repeatLast,
                onTap: { command in
                    executeQuickCommand(command)
                }
            )
        }
        .padding(.horizontal)
    }
    
    private var currentResponseCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Current Display")
                    .font(.headline)
                
                Spacer()
                
                Button(action: {
                    Task {
                        try? await mentraOS.clearDisplay()
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                }
            }
            
            Text(glassesVM?.currentResponse ?? "")
                .font(.body)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    private var conversationHistorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Conversation History")
                    .font(.headline)
                
                Spacer()
                
                Button(action: {
                    Task {
                        try? await glassesVM?.executeQuickCommand(.clearHistory)
                    }
                }) {
                    Text("Clear")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            .padding(.horizontal)
            
            if let vm = glassesVM {
                ForEach(vm.conversationHistory.filter { $0.role != .system }) { message in
                    ConversationBubble(message: message)
                }
            }
        }
        .padding(.vertical)
    }
    
    // MARK: - Actions
    
    private func connectToMentraOS() {
        isConnecting = true
        
        Task {
            do {
                try await mentraOS.connect()
                isConnecting = false
            } catch {
                isConnecting = false
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }
    
    private func openMentraOSApp() {
        if let url = URL(string: "mentraos://"),
           UIApplication.shared.canOpenURL(url) {
            Task {
                await UIApplication.shared.open(url)
            }
        } else {
            errorMessage = "MentraOS not installed. Please download from App Store."
            showingError = true
        }
    }
    
    private func startVoiceSession() {
        Task {
            do {
                try await glassesVM?.startVoiceSession()
            } catch {
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }
    
    private func executeQuickCommand(_ command: QuickCommand) {
        Task {
            do {
                try await glassesVM?.executeQuickCommand(command)
            } catch {
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }
}

// MARK: - Supporting Views

struct ConnectionStep: View {
    let number: Int
    let title: String
    let description: String
    let isComplete: Bool
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle()
                    .fill(isComplete ? Color.green : Color.blue.opacity(0.2))
                    .frame(width: 32, height: 32)
                
                if isComplete {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                } else {
                    Text("\(number)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.blue)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

struct StatusIndicator: View {
    let icon: String
    let label: String
    let isActive: Bool
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(isActive ? color : .gray)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Circle()
                .fill(isActive ? color : .gray)
                .frame(width: 8, height: 8)
        }
        .frame(maxWidth: .infinity)
    }
}

struct QuickCommandRow: View {
    let icon: String
    let title: String
    let command: QuickCommand
    let onTap: (QuickCommand) -> Void
    
    var body: some View {
        Button(action: {
            onTap(command)
        }) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(.blue)
                    .frame(width: 32)
                
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(UIColor.tertiarySystemBackground))
            .cornerRadius(8)
        }
    }
}

struct ConversationBubble: View {
    let message: Message
    
    var body: some View {
        HStack {
            if message.role == .user {
                Spacer()
            }
            
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(.subheadline)
                    .padding(12)
                    .background(message.role == .user ? Color.blue : Color(UIColor.tertiarySystemBackground))
                    .foregroundColor(message.role == .user ? .white : .primary)
                    .cornerRadius(12)
                
                Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            if message.role == .assistant {
                Spacer()
            }
        }
        .padding(.horizontal)
    }
}

#Preview {
    GlassesAssistantView(
        chatViewModel: ChatViewModel(settings: AppSettings()),
        mlxService: MLXService()
    )
}