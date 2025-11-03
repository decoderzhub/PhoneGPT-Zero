//
//  MentraOSService.swift
//  PhoneGPT
//
//  Created by Darin Manley on 11/2/25.
//


//
//  MentraOSService.swift
//  PhoneGPT
//
//  MentraOS communication service for Even Realities G1 glasses
//

import Foundation
import Combine

/// Service for communicating with MentraOS app and Even Realities glasses
@MainActor
class MentraOSService: ObservableObject {
    @Published var isConnected = false
    @Published var glassesConnected = false
    @Published var displayText: String = ""
    
    private var cancellables = Set<AnyCancellable>()
    
    // URL scheme for MentraOS communication
    private let mentraOSScheme = "mentraos://"
    
    // Notification center for app-to-app communication
    private let notificationCenter = CFNotificationCenterGetDarwinNotifyCenter()
    
    init() {
        setupNotifications()
        checkMentraOSInstalled()
    }
    
    // MARK: - Setup
    
    private func setupNotifications() {
        // Listen for MentraOS status updates
        NotificationCenter.default.publisher(for: NSNotification.Name("MentraOSStatus"))
            .sink { [weak self] notification in
                guard let self = self,
                      let status = notification.userInfo?["status"] as? String else { return }
                
                self.handleStatusUpdate(status)
            }
            .store(in: &cancellables)
    }
    
    private func checkMentraOSInstalled() -> Bool {
        guard let url = URL(string: mentraOSScheme),
              UIApplication.shared.canOpenURL(url) else {
            print("❌ MentraOS not installed")
            return false
        }
        
        print("✅ MentraOS installed")
        return true
    }
    
    // MARK: - Connection
    
    func connect() async throws {
        guard checkMentraOSInstalled() else {
            throw MentraOSError.appNotInstalled
        }
        
        // Open MentraOS to initiate connection
        if let url = URL(string: "\(mentraOSScheme)connect") {
            await UIApplication.shared.open(url)
        }
        
        // Wait for connection confirmation
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        isConnected = true
        print("✅ Connected to MentraOS")
    }
    
    func disconnect() {
        isConnected = false
        glassesConnected = false
        print("🔌 Disconnected from MentraOS")
    }
    
    // MARK: - Text-to-Speech Display
    
    /// Send text to be displayed on Even Realities glasses
    /// - Parameters:
    ///   - text: The text to display
    ///   - duration: How long to display (in seconds, optional)
    func displayText(_ text: String, duration: TimeInterval? = nil) async throws {
        guard isConnected else {
            throw MentraOSError.notConnected
        }
        
        print("📱 Sending to glasses: \"\(text)\"")
        
        // Use shared app group for inter-app communication
        if let sharedDefaults = UserDefaults(suiteName: "group.com.codeofhonor.PhoneGPT") {
            sharedDefaults.set(text, forKey: "mentra_display_text")
            sharedDefaults.set(Date().timeIntervalSince1970, forKey: "mentra_timestamp")
            
            if let duration = duration {
                sharedDefaults.set(duration, forKey: "mentra_duration")
            }
            
            sharedDefaults.synchronize()
        }
        
        // Trigger MentraOS via URL scheme with encoded text
        let encodedText = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "\(mentraOSScheme)display?text=\(encodedText)"
        
        if let url = URL(string: urlString) {
            await UIApplication.shared.open(url)
        }
        
        displayText = text
    }
    
    /// Stream text chunks to glasses (for live AI responses)
    /// - Parameter chunk: Text chunk to append to current display
    func streamTextChunk(_ chunk: String) async throws {
        displayText += chunk
        try await displayText(displayText)
    }
    
    /// Clear the glasses display
    func clearDisplay() async throws {
        guard isConnected else {
            throw MentraOSError.notConnected
        }
        
        if let url = URL(string: "\(mentraOSScheme)clear") {
            await UIApplication.shared.open(url)
        }
        
        displayText = ""
    }
    
    // MARK: - Voice Input
    
    /// Request voice input from glasses microphone
    /// - Returns: Transcribed text from user
    func captureVoiceInput() async throws -> String {
        guard isConnected else {
            throw MentraOSError.notConnected
        }
        
        print("🎤 Requesting voice input from glasses...")
        
        // Trigger voice capture in MentraOS
        if let url = URL(string: "\(mentraOSScheme)voice-capture") {
            await UIApplication.shared.open(url)
        }
        
        // Wait for voice input result
        return try await withCheckedThrowingContinuation { continuation in
            // Listen for voice input result from shared app group
            Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
                if let sharedDefaults = UserDefaults(suiteName: "group.com.codeofhonor.PhoneGPT"),
                   let voiceText = sharedDefaults.string(forKey: "mentra_voice_result"),
                   let timestamp = sharedDefaults.double(forKey: "mentra_voice_timestamp"),
                   Date().timeIntervalSince1970 - timestamp < 5 { // Result within last 5 seconds
                    
                    timer.invalidate()
                    
                    // Clear the result
                    sharedDefaults.removeObject(forKey: "mentra_voice_result")
                    sharedDefaults.synchronize()
                    
                    continuation.resume(returning: voiceText)
                }
            }
            
            // Timeout after 30 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
                continuation.resume(throwing: MentraOSError.voiceInputTimeout)
            }
        }
    }
    
    // MARK: - Status Handling
    
    private func handleStatusUpdate(_ status: String) {
        switch status {
        case "glasses_connected":
            glassesConnected = true
            print("👓 Glasses connected")
            
        case "glasses_disconnected":
            glassesConnected = false
            print("👓 Glasses disconnected")
            
        case "mentra_disconnected":
            isConnected = false
            glassesConnected = false
            print("🔌 MentraOS disconnected")
            
        default:
            break
        }
    }
    
    // MARK: - Gesture Commands
    
    /// Send a command triggered by glasses gesture
    func handleGestureCommand(_ gesture: GlassesGesture) async throws {
        switch gesture {
        case .tapOnce:
            print("👆 Single tap - Could trigger 'repeat last response'")
            
        case .tapTwice:
            print("👆👆 Double tap - Could trigger 'new query'")
            
        case .swipeUp:
            print("👆⬆️ Swipe up - Could trigger 'next item'")
            
        case .swipeDown:
            print("👆⬇️ Swipe down - Could trigger 'previous item'")
            
        case .swipeLeft:
            print("👆⬅️ Swipe left - Could trigger 'cancel'")
            
        case .swipeRight:
            print("👆➡️ Swipe right - Could trigger 'confirm'")
        }
    }
}

// MARK: - Enums

enum GlassesGesture: String {
    case tapOnce
    case tapTwice
    case swipeUp
    case swipeDown
    case swipeLeft
    case swipeRight
}

enum MentraOSError: LocalizedError {
    case appNotInstalled
    case notConnected
    case glassesNotConnected
    case voiceInputTimeout
    case displayFailed
    
    var errorDescription: String? {
        switch self {
        case .appNotInstalled:
            return "MentraOS app is not installed. Please install it from the App Store."
        case .notConnected:
            return "Not connected to MentraOS. Please connect first."
        case .glassesNotConnected:
            return "Even Realities glasses are not connected to MentraOS."
        case .voiceInputTimeout:
            return "Voice input timed out. Please try again."
        case .displayFailed:
            return "Failed to display text on glasses."
        }
    }
}