import SwiftUI
import CoreData

@main
struct PhoneGPTApp: App {
    let persistenceController = PersistenceController.shared
    @State private var settings = AppSettings()
    @State private var viewModel: ChatViewModel?
    @State private var databaseService = DatabaseService()

    var body: some Scene {
        WindowGroup {
            Group {
                if settings.modelDownloaded {
                    if let viewModel = viewModel {
                        ChatView(
                            viewModel: viewModel,
                            databaseService: databaseService,
                            settings: settings
                        )
                    } else {
                        ProgressView()
                            .onAppear {
                                Task { @MainActor in
                                    viewModel = ChatViewModel(settings: settings)
                                }
                            }
                    }
                } else {
                    WelcomeView {
                        Task { @MainActor in
                            settings.modelDownloaded = true
                            viewModel = ChatViewModel(settings: settings)
                        }
                    }
                }
            }
            .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
