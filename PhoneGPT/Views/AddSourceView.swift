//
//  AddSourceView.swift
//  PhoneGPT
//
//  Created by Claude on 11/3/25.
//

import SwiftUI

struct AddSourceView: View {
    @Environment(\.dismiss) private var dismiss
    let onAdd: (DataSource) -> Void

    let availableSources = [
        ("Slack", "message.fill", DataSource.SourceType.slack, "Team communication & messaging"),
        ("Microsoft Teams", "person.3.fill", DataSource.SourceType.teams, "Collaboration platform"),
        ("Calendar", "calendar", DataSource.SourceType.calendar, "Events and scheduling"),
        ("Email", "envelope.fill", DataSource.SourceType.email, "Email integration"),
        ("Notes", "note.text", DataSource.SourceType.notes, "Apple Notes access"),
        ("Smart Home", "house.fill", DataSource.SourceType.smartHome, "HomeKit devices")
    ]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(availableSources, id: \.0) { source in
                        Button(action: {
                            let newSource = DataSource(
                                name: source.0,
                                type: source.2,
                                isConnected: false
                            )
                            onAdd(newSource)
                        }) {
                            HStack(spacing: 16) {
                                Image(systemName: source.1)
                                    .font(.system(size: 28))
                                    .foregroundColor(colorForType(source.2))
                                    .frame(width: 44, height: 44)
                                    .background(colorForType(source.2).opacity(0.1))
                                    .cornerRadius(8)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(source.0)
                                        .font(.headline)
                                        .foregroundColor(.primary)

                                    Text(source.3)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(.blue)
                                    .font(.title3)
                            }
                            .padding(.vertical, 8)
                        }
                    }
                } header: {
                    Text("Available Sources")
                } footer: {
                    Text("Connect data sources to give PhoneGPT context about your work and personal life. All data stays on your device.")
                }
            }
            .navigationTitle("Add Source")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func colorForType(_ type: DataSource.SourceType) -> Color {
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
}

#Preview {
    AddSourceView { _ in }
}
