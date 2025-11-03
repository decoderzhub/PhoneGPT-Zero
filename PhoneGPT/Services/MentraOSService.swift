//
//  MentraOSService.swift
//  PhoneGPT
//
//  MentraOS communication service for Even Realities G1 glasses
//

import Foundation
import Combine
import UIKit

struct WebhookEvent: Codable {
    let type: String
    let data: [String: AnyCodable]
    let timestamp: String?
    let device_id: String?
}

struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            value = string
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else {
            value = ""
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let string = value as? String {
            try container.encode(string)
        } else if let int = value as? Int {
            try container.encode(int)
        } else if let double = value as? Double {
            try container.encode(double)
        } else if let bool = value as? Bool {
            try container.encode(bool)
        }
    }
}

struct EventsResponse: Codable {
    let events: [WebhookEvent]
    let count: Int
    let last_index: Int
}

@MainActor
class MentraOSService: ObservableObject {
    @Published var isConnected = false
    @Published var glassesConnected = false
    @Published var displayText: String = ""

    private var cancellables = Set<AnyCancellable>()
    private var pollingTimer: Timer?
    private var lastEventIndex = 0

    private let mentraOSScheme = "mentraos://"
    private let webhookURL = "https://phonegpt-webhook.systemd.diskstation.me"

    var onVoiceInput: ((String) -> Void)?
    var onGesture: ((GlassesGesture) -> Void)?
    var onAppActivated: (() -> Void)?
    var onAppDeactivated: (() -> Void)?

    init() {
        checkMentraOSInstalled()
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

    func connect() async throws {
        guard checkMentraOSInstalled() else {
            throw MentraOSError.appNotInstalled
        }

        if let url = URL(string: "\(mentraOSScheme)connect") {
            await UIApplication.shared.open(url)
        }

        try await Task.sleep(nanoseconds: 1_000_000_000)

        isConnected = true
        startPolling()
        print("✅ Connected to MentraOS - started polling webhook")
    }

    func disconnect() {
        stopPolling()
        isConnected = false
        glassesConnected = false
        print("🔌 Disconnected from MentraOS")
    }

    private func startPolling() {
        stopPolling()

        pollingTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.checkForEvents()
            }
        }

        RunLoop.main.add(pollingTimer!, forMode: .common)
        print("🔄 Started polling webhook every 2 seconds")
    }

    private func stopPolling() {
        pollingTimer?.invalidate()
        pollingTimer = nil
    }

    private func checkForEvents() async {
        guard let url = URL(string: "\(webhookURL)/events?since=\(lastEventIndex)") else { return }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(EventsResponse.self, from: data)

            for event in response.events {
                await handleWebhookEvent(event)
            }

            if response.last_index > lastEventIndex {
                lastEventIndex = response.last_index
            }
        } catch {
            print("❌ Polling error: \(error)")
        }
    }

    private func handleWebhookEvent(_ event: WebhookEvent) async {
        print("📨 Received event: \(event.type)")

        switch event.type {
        case "app_activated":
            glassesConnected = true
            onAppActivated?()
            print("👓 App activated on glasses")

        case "app_deactivated":
            glassesConnected = false
            onAppDeactivated?()
            print("👓 App deactivated on glasses")

        case "voice_input":
            if let transcript = event.data["transcript"]?.value as? String {
                print("🎤 Voice input: \"\(transcript)\"")
                onVoiceInput?(transcript)
            }

        case "gesture":
            if let gestureType = event.data["gesture_type"]?.value as? String,
               let gesture = GlassesGesture(rawValue: gestureType) {
                print("👆 Gesture: \(gestureType)")
                onGesture?(gesture)
            }

        case "connection_status":
            if let connected = event.data["connected"]?.value as? Bool {
                glassesConnected = connected
                print("👓 Glasses \(connected ? "connected" : "disconnected")")
            }

        default:
            print("❓ Unknown event type: \(event.type)")
        }
    }

    func displayText(_ text: String, duration: TimeInterval? = nil) async throws {
        guard isConnected else {
            throw MentraOSError.notConnected
        }

        print("📱 Sending to glasses: \"\(text)\"")

        let encodedText = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "\(mentraOSScheme)display?text=\(encodedText)"

        if let url = URL(string: urlString) {
            await UIApplication.shared.open(url)
        }

        displayText = text
    }

    func streamTextChunk(_ chunk: String) async throws {
        displayText += chunk
        try await displayText(displayText)
    }

    func clearDisplay() async throws {
        guard isConnected else {
            throw MentraOSError.notConnected
        }

        if let url = URL(string: "\(mentraOSScheme)clear") {
            await UIApplication.shared.open(url)
        }

        displayText = ""
    }

    func captureVoiceInput() async throws -> String {
        guard isConnected else {
            throw MentraOSError.notConnected
        }

        print("🎤 Requesting voice input from glasses...")

        if let url = URL(string: "\(mentraOSScheme)voice-capture") {
            await UIApplication.shared.open(url)
        }

        return try await withCheckedThrowingContinuation { continuation in
            var resumed = false

            let handler: (String) -> Void = { text in
                guard !resumed else { return }
                resumed = true
                continuation.resume(returning: text)
            }

            onVoiceInput = handler

            DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
                guard !resumed else { return }
                resumed = true
                continuation.resume(throwing: MentraOSError.voiceInputTimeout)
            }
        }
    }

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

enum GlassesGesture: String, Codable {
    case tapOnce = "tap_once"
    case tapTwice = "tap_twice"
    case swipeUp = "swipe_up"
    case swipeDown = "swipe_down"
    case swipeLeft = "swipe_left"
    case swipeRight = "swipe_right"
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
