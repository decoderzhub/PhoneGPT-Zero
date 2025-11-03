//
//  SourceDetailView.swift
//  PhoneGPT
//
//  Created by Claude on 11/3/25.
//

import SwiftUI

struct SourceDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @State var source: DataSource
    @State private var isConnecting = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    VStack(spacing: 16) {
                        Image(systemName: source.icon)
                            .font(.system(size: 80))
                            .foregroundColor(source.color)
                            .frame(width: 120, height: 120)
                            .background(source.color.opacity(0.1))
                            .cornerRadius(20)

                        VStack(spacing: 8) {
                            Text(source.name)
                                .font(.title2)
                                .fontWeight(.semibold)

                            HStack(spacing: 8) {
                                Circle()
                                    .fill(source.isConnected ? Color.green : Color.gray)
                                    .frame(width: 10, height: 10)

                                Text(source.isConnected ? "Connected" : "Not Connected")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.top, 32)

                    VStack(alignment: .leading, spacing: 16) {
                        SectionHeader(title: "About")

                        Text(descriptionForSource(source.type))
                            .font(.body)
                            .foregroundColor(.secondary)

                        Divider()

                        SectionHeader(title: "Privacy")

                        HStack(spacing: 12) {
                            Image(systemName: "lock.shield.fill")
                                .font(.title2)
                                .foregroundColor(.green)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("100% Private")
                                    .font(.subheadline)
                                    .fontWeight(.medium)

                                Text("All data stays on your device")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                    }
                    .padding(20)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)

                    if source.isConnected {
                        Button(action: {
                            source.isConnected = false
                        }) {
                            Text("Disconnect")
                                .font(.headline)
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color(UIColor.secondarySystemBackground))
                                .cornerRadius(12)
                        }
                    } else {
                        Button(action: {
                            connectSource()
                        }) {
                            HStack {
                                if isConnecting {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Image(systemName: "link")
                                    Text("Connect \(source.name)")
                                }
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(isConnecting ? Color.gray : source.color)
                            .cornerRadius(12)
                        }
                        .disabled(isConnecting)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("What PhoneGPT Can Access")
                            .font(.headline)

                        VStack(spacing: 8) {
                            ForEach(permissionsForSource(source.type), id: \.self) { permission in
                                HStack(spacing: 12) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)

                                    Text(permission)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)

                                    Spacer()
                                }
                            }
                        }
                    }
                    .padding(20)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
                }
                .padding()
            }
            .navigationTitle("Source Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func connectSource() {
        isConnecting = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isConnecting = false
            source.isConnected = true
        }
    }

    private func descriptionForSource(_ type: DataSource.SourceType) -> String {
        switch type {
        case .slack:
            return "Connect your Slack workspace to read and respond to messages through PhoneGPT. Use AI to draft replies and summarize conversations."
        case .teams:
            return "Integrate Microsoft Teams for seamless communication. Let PhoneGPT help manage your Teams messages and meetings."
        case .calendar:
            return "Access your calendar to let PhoneGPT provide context-aware responses based on your schedule and upcoming events."
        case .email:
            return "Connect your email to enable PhoneGPT to help draft responses, summarize threads, and manage your inbox."
        case .notes:
            return "Give PhoneGPT access to your Apple Notes for enhanced context and the ability to create and update notes."
        case .smartHome:
            return "Connect HomeKit devices to control your smart home through natural language commands via PhoneGPT."
        }
    }

    private func permissionsForSource(_ type: DataSource.SourceType) -> [String] {
        switch type {
        case .slack:
            return ["Read messages", "Send messages", "View channels", "Access workspace info"]
        case .teams:
            return ["Read chats", "Send messages", "View meetings", "Access calendar"]
        case .calendar:
            return ["Read events", "Create events", "Modify events", "View attendees"]
        case .email:
            return ["Read emails", "Send emails", "View folders", "Search inbox"]
        case .notes:
            return ["Read notes", "Create notes", "Edit notes", "Search notes"]
        case .smartHome:
            return ["View devices", "Control devices", "View scenes", "Access automations"]
        }
    }
}

#Preview {
    SourceDetailView(source: DataSource(
        name: "Slack",
        type: .slack,
        isConnected: false
    ))
}
