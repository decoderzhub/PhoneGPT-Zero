import SwiftUI
import CoreData

@main
struct PhoneGPTApp: App {
    let persistenceController = PersistenceController.shared
    @State private var settings = AppSettings()
    @State private var viewModel: ChatViewModel?
    @State private var databaseService = DatabaseService()
    @State private var showingSplash = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                if showingSplash {
                    SplashView()
                        .transition(.opacity)
                        .zIndex(1)
                } else {
                    Group {
                        if let viewModel = viewModel {
                            ChatView(
                                viewModel: viewModel,
                                databaseService: databaseService,
                                settings: settings
                            )
                        } else {
                            ProgressView()
                        }
                    }
                    .transition(.opacity)
                }
            }
            .environment(\.managedObjectContext, persistenceController.container.viewContext)
            .onAppear {
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    viewModel = ChatViewModel(settings: settings)
                    withAnimation(.easeOut(duration: 0.5)) {
                        showingSplash = false
                    }
                }
            }
        }
    }
}
