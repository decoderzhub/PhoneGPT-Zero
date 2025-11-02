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

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(sessions, id: \.id) { session in
                        SessionRow(
                            session: session,
                            isSelected: selectedSession?.id == session.id
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedSession = session
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                onDeleteSession(session)
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
    }
}

struct SessionRow: View {
    let session: ChatSession
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(session.title ?? "New Chat")
                .font(.system(size: 15, weight: .medium))
                .lineLimit(2)
                .foregroundColor(isSelected ? .white : .primary)

            Text(session.updatedAt?.formatted(date: .abbreviated, time: .shortened) ?? "")
                .font(.system(size: 12))
                .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isSelected ? Color.blue : Color(UIColor.systemBackground))
        .cornerRadius(8)
    }
}
