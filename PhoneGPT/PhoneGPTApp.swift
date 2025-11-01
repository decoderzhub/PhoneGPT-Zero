import SwiftUI
import CoreData

@main
struct PhoneGPTApp: App {
    let persistenceController = PersistenceController.shared
    @StateObject private var modelManager = ModelManager.shared
    
    var body: some Scene {
        WindowGroup {
            ChatView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(modelManager)
                .preferredColorScheme(.dark)
        }
    }
}
