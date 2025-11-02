//
//  AppSettings.swift
//  PhoneGPT
//
//  Created by Darin Manley on 11/2/25.
//

import Foundation

@Observable
class AppSettings {
    var useDocuments: Bool {
        didSet {
            UserDefaults.standard.set(useDocuments, forKey: "useDocuments")
        }
    }

    var modelDownloaded: Bool {
        didSet {
            UserDefaults.standard.set(modelDownloaded, forKey: "modelDownloaded")
        }
    }

    var temperature: Double {
        didSet {
            UserDefaults.standard.set(temperature, forKey: "temperature")
        }
    }

    var maxTokens: Int {
        didSet {
            UserDefaults.standard.set(maxTokens, forKey: "maxTokens")
        }
    }

    init() {
        self.useDocuments = UserDefaults.standard.bool(forKey: "useDocuments")
        self.modelDownloaded = UserDefaults.standard.bool(forKey: "modelDownloaded")
        self.temperature = UserDefaults.standard.object(forKey: "temperature") as? Double ?? 0.7
        self.maxTokens = UserDefaults.standard.object(forKey: "maxTokens") as? Int ?? 512
    }
}
