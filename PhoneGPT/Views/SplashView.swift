//
//  SplashView.swift
//  PhoneGPT
//
//  Created by Darin Manley on 11/2/25.
//

import SwiftUI

struct SplashView: View {
    @State private var isAnimating = false
    @State private var showContent = false

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [Color.blue.opacity(0.8), Color.blue]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 80))
                    .foregroundColor(.white)
                    .scaleEffect(isAnimating ? 1.1 : 1.0)
                    .opacity(isAnimating ? 1.0 : 0.8)
                    .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isAnimating)

                Text("PhoneGPT")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(.white)
                    .opacity(showContent ? 1.0 : 0.0)

                Text("AI in Your Pocket")
                    .font(.title3)
                    .foregroundColor(.white.opacity(0.9))
                    .opacity(showContent ? 1.0 : 0.0)
            }
        }
        .onAppear {
            isAnimating = true
            withAnimation(.easeIn(duration: 0.5).delay(0.2)) {
                showContent = true
            }
        }
    }
}
