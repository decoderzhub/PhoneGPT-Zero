//
//  DevicesView.swift
//  PhoneGPT
//
//  Created by Claude on 11/3/25.
//

import SwiftUI

struct DevicesView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var deviceService = DeviceService()
    @State private var devices: [ConnectedDevice] = []
    @State private var showingAddDevice = false
    @State private var selectedDevice: ConnectedDevice?
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            ZStack {
                if isLoading {
                    ProgressView("Loading devices...")
                } else if devices.isEmpty {
                    VStack(spacing: 24) {
                        Image(systemName: "display.trianglebadge.exclamationmark")
                            .font(.system(size: 64))
                            .foregroundColor(.secondary)

                        VStack(spacing: 8) {
                            Text("No Devices Connected")
                                .font(.title2)
                                .fontWeight(.semibold)

                            Text("Add a device to extend PhoneGPT's capabilities")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }

                        Button(action: { showingAddDevice = true }) {
                            Label("Add Device", systemImage: "plus.circle.fill")
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
                        ForEach(devices) { device in
                            Button(action: {
                                selectedDevice = device
                            }) {
                                DeviceRow(device: device)
                            }
                        }
                        .onDelete(perform: deleteDevices)
                    }
                }
            }
            .navigationTitle("Devices")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddDevice = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddDevice) {
                AddDeviceView { device in
                    devices.append(device)
                    showingAddDevice = false
                    Task {
                        try? await deviceService.saveDevice(device)
                    }
                }
            }
            .sheet(item: $selectedDevice) { device in
                DeviceDetailView(device: device, onUpdate: { updatedDevice in
                    if let index = devices.firstIndex(where: { $0.id == updatedDevice.id }) {
                        devices[index] = updatedDevice
                        Task {
                            try? await deviceService.updateDevice(updatedDevice)
                        }
                    }
                })
            }
            .task {
                await loadDevices()
            }
        }
    }

    private func loadDevices() async {
        isLoading = true
        do {
            devices = try await deviceService.fetchAllDevices()
        } catch {
            print("Error loading devices: \(error)")
            devices = []
        }
        isLoading = false
    }

    private func deleteDevices(at offsets: IndexSet) {
        for index in offsets {
            let device = devices[index]
            Task {
                try? await deviceService.deleteDevice(device)
            }
        }
        devices.remove(atOffsets: offsets)
    }
}

struct DeviceRow: View {
    let device: ConnectedDevice

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: device.icon)
                .font(.system(size: 32))
                .foregroundColor(.blue)
                .frame(width: 50, height: 50)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(10)

            VStack(alignment: .leading, spacing: 4) {
                Text(device.name)
                    .font(.headline)
                    .foregroundColor(.primary)

                HStack(spacing: 8) {
                    Circle()
                        .fill(device.isConnected ? Color.green : Color.gray)
                        .frame(width: 8, height: 8)

                    Text(device.isConnected ? "Connected" : "Disconnected")
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

struct ConnectedDevice: Identifiable, Equatable {
    var id: UUID
    var name: String
    var type: DeviceType
    var isConnected: Bool
    var deviceId: String

    init(id: UUID = UUID(), name: String, type: DeviceType, isConnected: Bool, deviceId: String? = nil) {
        self.id = id
        self.name = name
        self.type = type
        self.isConnected = isConnected
        self.deviceId = deviceId ?? "\(type.rawValue)_\(id.uuidString)"
    }

    static func == (lhs: ConnectedDevice, rhs: ConnectedDevice) -> Bool {
        lhs.id == rhs.id
    }

    var icon: String {
        switch type {
        case .evenRealities:
            return "eyeglasses"
        case .smartHome:
            return "house.fill"
        case .wearable:
            return "applewatch"
        }
    }

    enum DeviceType: String, Codable {
        case evenRealities = "even_realities"
        case smartHome = "smart_home"
        case wearable = "wearable"
    }
}

#Preview {
    DevicesView()
}
