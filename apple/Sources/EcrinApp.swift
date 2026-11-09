import SwiftData
import SwiftUI

@main
struct EcrinApp: App {
    @State private var container: ModelContainer?
    @State private var startupError: String?
    @State private var localOnly = false

    init() {
        do {
            _container = State(initialValue: try Self.openContainer(local: false))
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
                    .safeAreaInset(edge: .top) {
                        if localOnly {
                            Text("Mode local · iCloud désactivé pour cette session. Mémoire séparée, sans migration automatique.")
                                .font(.caption).foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity).padding(8)
                                .background(.regularMaterial)
                        }
                    }
            } else {
                VStack(spacing: 18) {
                    ContentUnavailableView(
                        "La mémoire iCloud ne peut pas être ouverte",
                        systemImage: "icloud.slash",
                        description: Text(startupError ?? "Impossible d’ouvrir la mémoire ÉCRIN.")
                    )
                    Button("Réessayer iCloud") { open(local: false) }
                    Button("Ouvrir une mémoire locale séparée") { open(local: true) }
                    Text("La mémoire locale reste sur cet appareil. Vos données iCloud ne sont ni remplacées, ni effacées, ni copiées automatiquement.")
                        .font(.footnote).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center).padding()
                }.padding()
            }
        }
    }

    private func open(local: Bool) {
        do {
            container = try Self.openContainer(local: local)
            localOnly = local
            startupError = nil
        } catch { startupError = error.localizedDescription }
    }

    private static func openContainer(local: Bool) throws -> ModelContainer {
        let schema = Schema([MemoryItem.self])
        let configuration: ModelConfiguration
        if local {
            configuration = ModelConfiguration("EcrinLocal", schema: schema, cloudKitDatabase: .none)
        } else {
            // Preserve the existing CloudKit store identity and container.
            configuration = ModelConfiguration(schema: schema, cloudKitDatabase: .private("iCloud.com.memoryos.brain26"))
        }
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
