//
//  SourcesView.swift
//  PhoneGPT
//
//  Created by Claude on 11/3/25.
//

import SwiftUI

struct SourcesView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var sources: [DataSource] = []
    @State private var showingAddSource = false
    @State private var selectedSource: DataSource?

    var body: some View {
        NavigationStack {
            ZStack {
                if sources.isEmpty {
                    VStack(spacing: 24) {
                        Image(systemName: "folder.badge.plus")
                            .font(.system(size: 64))
                            .foregroundColor(.secondary)

                        VStack(spacing: 8) {
                            Text("No Sources Connected")
                                .font(.title2)
                                .fontWeight(.semibold)

                            Text("Connect data sources to enhance AI responses")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }

                        Button(action: { showingAddSource = true }) {
                            Label("Add Source", systemImage: "plus.circle.fill")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(Color.blue)
                                .cornerRadius(10)
                        }
                    }
                    .padding()
                } else {
                    List {
                        ForEach(sources) { source in
                            Button(action: {
                                selectedSource = source
                            }) {
                                SourceRow(source: source)
                            }
                        }
                        .onDelete(perform: deleteSources)
                    }
                }
            }
            .navigationTitle("Sources")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddSource = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddSource) {
                AddSourceView { source in
                    sources.append(source)
                    showingAddSource = false
                }
            }
            .sheet(item: $selectedSource) { source in
                SourceDetailView(source: source)
            }
        }
    }

    private func deleteSources(at offsets: IndexSet) {
        sources.remove(atOffsets: offsets)
    }
}

struct SourceRow: View {
    let source: DataSource

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: source.icon)
                .font(.system(size: 32))
                .foregroundColor(source.color)
                .frame(width: 50, height: 50)
                .background(source.color.opacity(0.1))
                .cornerRadius(10)

            VStack(alignment: .leading, spacing: 4) {
                Text(source.name)
                    .font(.headline)
                    .foregroundColor(.primary)

                HStack(spacing: 8) {
                    Circle()
                        .fill(source.isConnected ? Color.green : Color.gray)
                        .frame(width: 8, height: 8)

                    Text(source.isConnected ? "Connected" : "Not Connected")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
    }
}

struct DataSource: Identifiable {
    let id = UUID()
    var name: String
    var type: SourceType
    var isConnected: Bool

    var icon: String {
        switch type {
        case .slack:
            return "message.fill"
        case .teams:
            return "person.3.fill"
        case .calendar:
            return "calendar"
        case .email:
            return "envelope.fill"
        case .notes:
            return "note.text"
        case .smartHome:
            return "house.fill"
        }
    }

    var color: Color {
        switch type {
        case .slack:
            return Color.purple
        case .teams:
            return Color.blue
        case .calendar:
            return Color.red
        case .email:
            return Color.orange
        case .notes:
            return Color.yellow
        case .smartHome:
            return Color.green
        }
    }

    enum SourceType {
        case slack
        case teams
        case calendar
        case email
        case notes
        case smartHome
    }
}

#Preview {
    SourcesView()
}
