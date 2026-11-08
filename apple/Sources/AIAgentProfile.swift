import Foundation

enum AIExecutionPreference: String, CaseIterable, Codable, Identifiable {
    case server
    case appleOnDevice

    var id: String { rawValue }

    var title: String {
        switch self {
        case .server: return "Serveur configuré"
        case .appleOnDevice: return "Apple Intelligence sur l’appareil"
        }
    }
}

struct AIAgentProfile: Codable, Equatable, Identifiable {
    var id: String
    var name: String
    var summary: String
    var instructions: String
    var executionPreference: AIExecutionPreference
    var canUseMemory: Bool
    var availableActions: [String]

    static let builtIns: [AIAgentProfile] = [
        AIAgentProfile(
            id: "einstein",
            name: "Einstein",
            summary: "Assistant transversal · curieux, malicieux et expressif",
            instructions: "Tu es Einstein, l’assistant transversal d’ÉCRIN. Réponds avec curiosité, tact et clarté.",
            executionPreference: .server,
            canUseMemory: true,
            availableActions: ["rechercher", "créer une mémoire"]
        ),
        AIAgentProfile(
            id: "coach",
            name: "Coach",
            summary: "Objectifs, concentration et bilans",
            instructions: "Tu es un coach de travail bienveillant. Aide à clarifier un objectif et à choisir un prochain petit pas, sans jugement.",
            executionPreference: .server,
            canUseMemory: false,
            availableActions: []
        ),
        AIAgentProfile(
            id: "memory",
            name: "MemoryOS",
            summary: "Recherche, synthèse et classement",
            instructions: "Tu aides à organiser et comprendre la mémoire numérique. Distingue les faits fournis des suggestions et n’invente pas de documents consultés.",
            executionPreference: .server,
            canUseMemory: true,
            availableActions: ["rechercher", "créer une mémoire"]
        ),
        AIAgentProfile(
            id: "writer",
            name: "Rédaction",
            summary: "Notes, notices et guides",
            instructions: "Tu es un assistant de rédaction en français. Adapte le ton et la structure au besoin exprimé.",
            executionPreference: .server,
            canUseMemory: true,
            availableActions: ["créer une mémoire"]
        ),
        AIAgentProfile(
            id: "vision",
            name: "Vision",
            summary: "OCR, compréhension et analyse d’images",
            instructions: "Tu aides à décrire des images et des documents à partir des informations fournies. Signale les limites et ne prétends pas avoir vu un média absent.",
            executionPreference: .server,
            canUseMemory: true,
            availableActions: ["rechercher"]
        ),
        AIAgentProfile(
            id: "developer",
            name: "Développement",
            summary: "Code, projets et tâches techniques",
            instructions: "Tu es un assistant de développement. Explique les choix, préserve les données, propose des changements vérifiables et n’exécute pas de code.",
            executionPreference: .server,
            canUseMemory: false,
            availableActions: ["générer un projet"]
        ),
        AIAgentProfile(
            id: "personal",
            name: "Toi",
            summary: "Ton agent personnel configurable",
            instructions: "Tu es un assistant personnel. Aide à organiser les idées et tâches exprimées par l’utilisateur, sans prétendre être humain ni ressentir des émotions.",
            executionPreference: .server,
            canUseMemory: true,
            availableActions: []
        )
    ]

    static func load(from encodedProfiles: String) throws -> [AIAgentProfile] {
        guard !encodedProfiles.isEmpty else { return builtIns }
        guard let data = encodedProfiles.data(using: .utf8) else {
            throw AIAgentProfileError.invalidEncoding
        }
        let saved = try JSONDecoder().decode([AIAgentProfile].self, from: data)
        let builtInIDs = Set(builtIns.map(\.id))
        let custom = saved.filter { !builtInIDs.contains($0.id) }
        return builtIns + custom
    }

    static func encode(_ profiles: [AIAgentProfile]) throws -> String {
        let builtInIDs = Set(builtIns.map(\.id))
        let custom = profiles.filter { !builtInIDs.contains($0.id) }
        let data = try JSONEncoder().encode(custom)
        guard let encoded = String(data: data, encoding: .utf8) else {
            throw AIAgentProfileError.invalidEncoding
        }
        return encoded
    }
}

private enum AIAgentProfileError: LocalizedError {
    case invalidEncoding

    var errorDescription: String? {
        "Les profils d’agents n’ont pas pu être enregistrés."
    }
}
