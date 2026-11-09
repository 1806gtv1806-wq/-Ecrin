import SwiftData
import SwiftUI

@main
struct EcrinApp: App {
    @State private var container: ModelContainer?
    @State private var startupError: String?

    init() {
        do {
            let schema = Schema([MemoryItem.self])
            let configuration = ModelConfiguration(
                schema: schema,
                cloudKitDatabase: .private("iCloud.com.memoryos.brain26")
            )
            _container = State(initialValue: try ModelContainer(
                for: schema,
                configurations: [configuration]
            ))
            _startupError = State(initialValue: nil)
        } catch {
            _container = State(initialValue: nil)
            _startupError = State(initialValue: error.localizedDescription)
        }
    }

    var body: some Scene {
        WindowGroup {
            if let container {
                MainView()
                    .modelContainer(container)
            } else {
                ContentUnavailableView(
                    "Synchronisation iCloud indisponible",
                    systemImage: "icloud.slash",
                    description: Text(startupError ?? "Impossible d’ouvrir la mémoire Ecrin.")
                )
            }
        }
    }
}
