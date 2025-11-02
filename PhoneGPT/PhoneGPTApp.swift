import SwiftUI
import CoreData

@main
struct PhoneGPTApp: App {
    let persistenceController = PersistenceController.shared
    @StateObject private var modelManager = MLXModelManager.shared

    var body: some Scene {
        WindowGroup {
            ChatViewWithSessions()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(modelManager)
                .preferredColorScheme(.dark)
        }
    }
}
