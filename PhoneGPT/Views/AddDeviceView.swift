//
//  AddDeviceView.swift
//  PhoneGPT
//
//  Created by Claude on 11/3/25.
//

import SwiftUI

struct AddDeviceView: View {
    @Environment(\.dismiss) private var dismiss
    let onAdd: (ConnectedDevice) -> Void

    let availableDevices = [
        ("Even Realities G1", "eyeglasses", ConnectedDevice.DeviceType.evenRealities),
        ("Smart Home Hub", "house.fill", ConnectedDevice.DeviceType.smartHome),
        ("Apple Watch", "applewatch", ConnectedDevice.DeviceType.wearable)
    ]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(availableDevices, id: \.0) { device in
                        Button(action: {
                            let newDevice = ConnectedDevice(
                                name: device.0,
                                type: device.2,
                                isConnected: false
                            )
                            onAdd(newDevice)
                        }) {
                            HStack(spacing: 16) {
                                Image(systemName: device.1)
                                    .font(.system(size: 28))
                                    .foregroundColor(.blue)
                                    .frame(width: 44, height: 44)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(8)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(device.0)
                                        .font(.headline)
                                        .foregroundColor(.primary)

                                    Text(deviceDescription(for: device.2))
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
                    Text("Available Devices")
                } footer: {
                    Text("Select a device to begin setup and configuration.")
                }
            }
            .navigationTitle("Add Device")
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

    private func deviceDescription(for type: ConnectedDevice.DeviceType) -> String {
        switch type {
        case .evenRealities:
            return "AR glasses with heads-up display"
        case .smartHome:
            return "Control smart home devices"
        case .wearable:
            return "Smartwatch integration"
        }
    }
}

#Preview {
    AddDeviceView { _ in }
}
