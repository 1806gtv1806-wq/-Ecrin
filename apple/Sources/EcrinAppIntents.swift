import AppIntents
import Foundation

struct OpenEinsteinIntent: AppIntent {
    static var title: LocalizedStringResource = "Parler à Einstein"
    static var description = IntentDescription("Ouvre Einstein dans ÉCRIN.")
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        UserDefaults.standard.set(true, forKey: "openEinsteinFromIntent")
        return .result()
    }
}

struct CaptureIdeaIntent: AppIntent {
    static var title: LocalizedStringResource = "Dicter une idée dans NOVA"
    static var description = IntentDescription("Ouvre NOVA pour dicter et enregistrer une idée.")
    static var openAppWhenRun = true

    @Parameter(title: "Idée à garder")
    var idea: String

    func perform() async throws -> some IntentResult {
        UserDefaults.standard.set(idea, forKey: "nova.intentDraft")
        UserDefaults.standard.set(true, forKey: "openNOVAFromIntent")
        return .result()
    }
}

struct EcrinShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenEinsteinIntent(),
            phrases: [
                "Parler à Einstein dans \(.applicationName)",
                "Demander à Einstein dans \(.applicationName)"
            ],
            shortTitle: "Einstein",
            systemImageName: "sparkles"
        )
        AppShortcut(
            intent: CaptureIdeaIntent(),
            phrases: [
                "Dicter une idée dans \(.applicationName)",
                "Garder une idée avec \(.applicationName)"
            ],
            shortTitle: "NOVA",
            systemImageName: "waveform"
        )
    }
}
