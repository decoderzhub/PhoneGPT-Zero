//
//  PhoneGPTApp.swift
//  PhoneGPT
//
//  Created by Darin Manley on 10/31/25.
//

import SwiftUI

@main
struct PhoneGPTApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
