//
//  DeviceDetailView.swift
//  PhoneGPT
//
//  Created by Claude on 11/3/25.
//

import SwiftUI

struct DeviceDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @State var device: ConnectedDevice
    @State private var isConnecting = false
    @State private var showingConnectionError = false
    @State private var connectionError: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    VStack(spacing: 16) {
                        Image(systemName: device.icon)
                            .font(.system(size: 80))
                            .foregroundColor(.blue)
                            .frame(width: 120, height: 120)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(20)

                        VStack(spacing: 8) {
                            Text(device.name)
                                .font(.title2)
                                .fontWeight(.semibold)

                            HStack(spacing: 8) {
                                Circle()
                                    .fill(device.isConnected ? Color.green : Color.gray)
                                    .frame(width: 10, height: 10)

                                Text(device.isConnected ? "Connected" : "Disconnected")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.top, 32)

                    if device.type == .evenRealities {
                        evenRealitiesContent
                    } else {
                        genericDeviceContent
                    }
                }
                .padding()
            }
            .navigationTitle("Device Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Connection Error", isPresented: $showingConnectionError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(connectionError ?? "Failed to connect to device")
            }
        }
    }


    private var evenRealitiesContent: some View {
        VStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 16) {
                SectionHeader(title: "About")

                Text("Even Realities G1 smart glasses provide a heads-up display for accessing AI assistance hands-free. Connect PhoneGPT to control your AI assistant through voice and gesture commands.")
                    .font(.body)
                    .foregroundColor(.secondary)

                Divider()

                SectionHeader(title: "Features")

                DeviceFeatureRow(icon: "text.bubble", title: "AI Chat", description: "Access PhoneGPT conversations")
                DeviceFeatureRow(icon: "message", title: "Slack & Teams", description: "Read and reply to messages")
                DeviceFeatureRow(icon: "house", title: "Smart Home", description: "Control connected devices")
                DeviceFeatureRow(icon: "mic", title: "Voice Control", description: "Hands-free interaction")
            }
            .padding(20)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)

            if device.isConnected {
                VStack(spacing: 12) {
                    Button(action: {
                        openMentraOSApp()
                    }) {
                        HStack {
                            Image(systemName: "arrow.up.forward.app")
                            Text("Open MentraOS")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.blue)
                        .cornerRadius(12)
                    }

                    Button(action: {
                        disconnectDevice()
                    }) {
                        Text("Disconnect")
                            .font(.headline)
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(12)
                    }
                }
            } else {
                VStack(spacing: 12) {
                    Button(action: {
                        device.isConnected = true
                    }) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("I've Installed & Paired MentraOS")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.green)
                        .cornerRadius(12)
                    }

                    Button(action: {
                        connectDevice()
                    }) {
                        HStack {
                            if isConnecting {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                            } else {
                                Image(systemName: "arrow.down.app")
                                Text("Install MentraOS")
                            }
                        }
                        .font(.headline)
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(12)
                    }
                    .disabled(isConnecting)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Setup Instructions")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 8) {
                    InstructionStep(number: 1, text: "Install MentraOS from the App Store")
                    InstructionStep(number: 2, text: "Open MentraOS and pair your Even Realities G1 glasses")
                    InstructionStep(number: 3, text: "Return to PhoneGPT and tap 'Connect'")
                    InstructionStep(number: 4, text: "PhoneGPT will verify your MentraOS connection")
                }
            }
            .padding(20)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
        }
    }

    private var genericDeviceContent: some View {
        VStack(spacing: 24) {
            Text("Device configuration coming soon")
                .font(.headline)
                .foregroundColor(.secondary)

            if !device.isConnected {
                Button(action: {
                    connectDevice()
                }) {
                    Text("Connect")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.blue)
                        .cornerRadius(12)
                }
            }
        }
    }

    private func connectDevice() {
        isConnecting = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isConnecting = false

            if let url = URL(string: "https://apps.apple.com/us/app/mentra-the-smart-glasses-app/id6747363193") {
                UIApplication.shared.open(url)
            }
        }
    }

    private func disconnectDevice() {
        device.isConnected = false
    }

    private func openMentraOSApp() {
        if let url = URL(string: "mentraos://"),
           UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else {
            connectionError = "MentraOS app not found. Please install it from the App Store."
            showingConnectionError = true
        }
    }
}

struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.headline)
            .foregroundColor(.primary)
    }
}

struct DeviceFeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }
}

struct InstructionStep: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Color.blue)
                .cornerRadius(12)

            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer()
        }
    }
}

#Preview {
    DeviceDetailView(device: ConnectedDevice(
        name: "Even Realities G1",
        type: .evenRealities,
        isConnected: false
    ))
}
