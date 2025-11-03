//
//  SidebarView.swift
//  PhoneGPT
//
//  Created by Darin Manley on 11/2/25.
//

import SwiftUI

struct SidebarView: View {
    @Binding var selectedSession: ChatSession?
    @Binding var showingSettings: Bool
    let sessions: [ChatSession]
    let onNewChat: () -> Void
    let onDeleteSession: (ChatSession) -> Void

    @State private var sessionToDelete: ChatSession?
    @State private var showingDeleteConfirmation = false
    @State private var showingDevices = false
    @State private var showingSources = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Button(action: onNewChat) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("New Chat")
                    }
                    .font(.headline)
                    .foregroundColor(.blue)
                }
                .padding()

                Spacer()

                Button(action: { showingSettings = true }) {
                    Image(systemName: "gearshape.fill")
                        .font(.title3)
                        .foregroundColor(.blue)
                }
                .padding()
            }
            .background(Color(UIColor.systemBackground))

            Divider()

            VStack(spacing: 0) {
                Button(action: { showingDevices = true }) {
                    HStack {
                        Image(systemName: "display")
                        Text("Devices")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .background(Color(UIColor.systemBackground))

                Divider()
                    .padding(.leading, 16)

                Button(action: { showingSources = true }) {
                    HStack {
                        Image(systemName: "doc.text")
                        Text("Sources")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .background(Color(UIColor.systemBackground))
            }

            Divider()

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(sessions, id: \.id) { session in
                        SessionRow(
                            session: session,
                            isSelected: selectedSession?.id == session.id,
                            onDelete: {
                                sessionToDelete = session
                                showingDeleteConfirmation = true
                            }
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedSession = session
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                sessionToDelete = session
                                showingDeleteConfirmation = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.secondarySystemBackground))
        .alert("Delete Chat?", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                sessionToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let session = sessionToDelete {
                    onDeleteSession(session)
                }
                sessionToDelete = nil
            }
        } message: {
            Text("This will permanently delete this chat session and all its messages.")
        }
        .sheet(isPresented: $showingDevices) {
            DevicesView()
        }
        .sheet(isPresented: $showingSources) {
            SourcesView()
        }
    }
}

struct SessionRow: View {
    let session: ChatSession
    let isSelected: Bool
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text(session.title ?? "New Chat")
                    .font(.system(size: 15, weight: .medium))
                    .lineLimit(2)
                    .foregroundColor(isSelected ? .white : .primary)

                Text(session.updatedAt?.formatted(date: .abbreviated, time: .shortened) ?? "")
                    .font(.system(size: 12))
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: onDelete) {
                Image(systemName: "trash.fill")
                    .font(.system(size: 14))
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .red)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(isSelected ? Color.blue : Color(UIColor.systemBackground))
        .cornerRadius(8)
    }
}
