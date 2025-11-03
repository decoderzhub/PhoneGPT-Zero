//
//  DeviceService.swift
//  PhoneGPT
//
//  Created by Claude on 11/3/25.
//

import Foundation

struct DeviceDTO: Codable {
    let id: String?
    let device_id: String
    let name: String
    let type: String
    let is_connected: Bool
    let created_at: String?
    let updated_at: String?
}

@MainActor
class DeviceService: ObservableObject {
    private let supabaseURL: String
    private let supabaseKey: String

    init() {
        guard let url = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
              let key = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String else {
            fatalError("Supabase credentials not found in Info.plist")
        }
        self.supabaseURL = url
        self.supabaseKey = key
    }

    func fetchAllDevices() async throws -> [ConnectedDevice] {
        let url = URL(string: "\(supabaseURL)/rest/v1/connected_devices")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, _) = try await URLSession.shared.data(for: request)
        let devices = try JSONDecoder().decode([DeviceDTO].self, from: data)

        return devices.map { dto in
            ConnectedDevice(
                id: UUID(uuidString: dto.id ?? "") ?? UUID(),
                name: dto.name,
                type: ConnectedDevice.DeviceType(rawValue: dto.type) ?? .wearable,
                isConnected: dto.is_connected,
                deviceId: dto.device_id
            )
        }
    }

    func saveDevice(_ device: ConnectedDevice) async throws {
        let dto = DeviceDTO(
            id: nil,
            device_id: device.deviceId,
            name: device.name,
            type: device.type.rawValue,
            is_connected: device.isConnected,
            created_at: nil,
            updated_at: nil
        )

        let url = URL(string: "\(supabaseURL)/rest/v1/connected_devices")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")

        request.httpBody = try JSONEncoder().encode(dto)

        let (_, _) = try await URLSession.shared.data(for: request)
    }

    func updateDevice(_ device: ConnectedDevice) async throws {
        let dto = DeviceDTO(
            id: nil,
            device_id: device.deviceId,
            name: device.name,
            type: device.type.rawValue,
            is_connected: device.isConnected,
            created_at: nil,
            updated_at: nil
        )

        let url = URL(string: "\(supabaseURL)/rest/v1/connected_devices?device_id=eq.\(device.deviceId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")

        request.httpBody = try JSONEncoder().encode(dto)

        let (_, _) = try await URLSession.shared.data(for: request)
    }

    func deleteDevice(_ device: ConnectedDevice) async throws {
        let url = URL(string: "\(supabaseURL)/rest/v1/connected_devices?device_id=eq.\(device.deviceId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")

        let (_, _) = try await URLSession.shared.data(for: request)
    }
}
