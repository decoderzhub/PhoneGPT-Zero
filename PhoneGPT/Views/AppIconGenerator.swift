//
//  AppIconGenerator.swift
//  PhoneGPT
//
//  Creates the app icon design matching the splash screen
//

import SwiftUI

struct AppIconView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.4, green: 0.6, blue: 1.0),
                    Color(red: 0.2, green: 0.4, blue: 0.9)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Image(systemName: "brain.head.profile")
                .font(.system(size: 600, weight: .medium))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
        }
        .frame(width: 1024, height: 1024)
    }
}

#Preview {
    AppIconView()
}
