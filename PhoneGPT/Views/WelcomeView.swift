//
//  WelcomeView.swift
//  PhoneGPT
//
//  Created by Darin Manley on 11/2/25.
//

import SwiftUI

struct WelcomeView: View {
    let onDownload: () -> Void
    @State private var isDownloading = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 80))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Text("Welcome to PhoneGPT")
                    .font(.system(size: 32, weight: .bold))

                Text("Your Personal AI Assistant")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 16) {
                FeatureRow(
                    icon: "lock.shield.fill",
                    title: "100% Private",
                    description: "Everything runs on your device"
                )

                FeatureRow(
                    icon: "bolt.fill",
                    title: "Fast & Efficient",
                    description: "Optimized for Apple Silicon"
                )

                FeatureRow(
                    icon: "doc.text.fill",
                    title: "Document Support",
                    description: "Chat with your documents"
                )

                FeatureRow(
                    icon: "wifi.slash",
                    title: "Works Offline",
                    description: "After initial model download"
                )
            }
            .padding(.horizontal, 32)

            Spacer()

            VStack(spacing: 16) {
                Button(action: {
                    isDownloading = true
                    onDownload()
                }) {
                    HStack {
                        if isDownloading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Image(systemName: "arrow.down.circle.fill")
                        }
                        Text(isDownloading ? "Downloading Model..." : "Download AI Model")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
                }
                .disabled(isDownloading)

                Text("This is the only time PhoneGPT will reach out to the internet, unless you enable cloud features in settings later.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
}
