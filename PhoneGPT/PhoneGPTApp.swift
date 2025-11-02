import SwiftUI
import CoreData

@main
struct PhoneGPTApp: App {
    let persistenceController = PersistenceController.shared
    @State private var settings = AppSettings()

    var body: some Scene {
        WindowGroup {
            Group {
                if settings.modelDownloaded {
                    ChatView(
                        viewModel: ChatViewModel(settings: settings),
                        databaseService: DatabaseService(),
                        settings: settings
                    )
                } else {
                    WelcomeView {
                        Task {
                            settings.modelDownloaded = true
                        }
                    }
                }
            }
            .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
