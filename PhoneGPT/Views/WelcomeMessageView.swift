//
//  WelcomeMessageView.swift
//  PhoneGPT
//
//  Created by Darin Manley on 11/2/25.
//

import SwiftUI

struct WelcomeMessageView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 12) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 40))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text("Welcome to PhoneGPT")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("AI in Your Pocket")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 16) {
                FeatureRow(
                    icon: "lock.shield.fill",
                    title: "100% Private",
                    description: "All processing happens locally on your iPhone",
                    color: .green
                )

                FeatureRow(
                    icon: "wifi.slash",
                    title: "No Internet Required",
                    description: "Chat offline after model download",
                    color: .orange
                )

                FeatureRow(
                    icon: "bolt.fill",
                    title: "Fast & Secure",
                    description: "Your data never leaves your device",
                    color: .blue
                )
            }

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                Text("What I can help with:")
                    .font(.headline)
                    .fontWeight(.semibold)

                VStack(alignment: .leading, spacing: 8) {
                    BulletPoint(text: "Answer questions and have conversations")
                    BulletPoint(text: "Help with writing and brainstorming")
                    BulletPoint(text: "Explain concepts and solve problems")
                    BulletPoint(text: "Work with documents you upload")
                }
            }

            Divider()

            HStack {
                Spacer()
                Text("Ask me anything to get started!")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .italic()
                Spacer()
            }
        }
        .padding(20)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(20)
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    let color: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct BulletPoint: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .font(.body)
                .foregroundColor(.blue)

            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)
        }
    }
}
