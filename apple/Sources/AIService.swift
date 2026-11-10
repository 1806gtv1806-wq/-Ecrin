import Foundation

struct Classification: Decodable, Sendable {
    let category: String
    let tags: [String]
    let keywords: [String]
    let summary: String
}

struct AIHealth: Decodable, Sendable {
    let status: String
    let service: String
    let ai_backend: String
}

struct GeneratedDocument: Decodable, Sendable {
    let title: String
    let content: String
    let summary: String
    let category: String
    let tags: [String]
    let keywords: [String]
}

struct AssistantAnswer: Decodable, Sendable {
    let answer: String
    let provider: String?
}

struct AIProviderConfiguration: Decodable, Sendable {
    let provider: String
    let model: String?
    let conversation: Bool
    let project_generation: Bool
    let provider_configured: Bool
    let authentication_required: Bool
}

struct ConversationTurn: Codable, Sendable {
    let role: String
    let content: String

    static func user(_ content: String) -> ConversationTurn {
        ConversationTurn(role: "user", content: content)
    }

    static func assistant(_ content: String) -> ConversationTurn {
        ConversationTurn(role: "assistant", content: content)
    }
}

enum DocumentKind: String, Encodable, Sendable {
    case notice
    case guide
}

enum AIServiceError: LocalizedError {
    case remoteDisabled
    case missingServer
    case invalidServerURL
    case badResponse(Int)
    case invalidProjectArchive

    var errorDescription: String? {
        switch self {
        case .remoteDisabled:
            return "Mode gratuit : les services IA distants sont désactivés. Utilisez Apple Intelligence sur cet appareil."
        case .missingServer:
            return "Configurez l’adresse HTTPS de votre serveur IA dans Réglages."
        case .invalidServerURL:
            return "L’adresse du serveur doit être une URL HTTPS valide."
        case .badResponse(let status):
            return "Le serveur IA a répondu avec le code HTTP \(status)."
        case .invalidProjectArchive:
            return "Le serveur n’a pas renvoyé une archive de projet valide."
        }
    }
}

struct AIService {
    private var remoteAIEnabled: Bool { false }
    private let session: URLSession
    static let serverConfigurationLabel = "Serveur IA"

    init(session: URLSession = .shared) {
        self.session = session
    }

    func classify(_ text: String, serverAddress: String) async throws -> Classification {
        let url = try endpoint(path: "/api/classify", serverAddress: serverAddress)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(TextRequest(text: text))
        return try await send(request, as: Classification.self)
    }

    func generate(_ text: String, kind: DocumentKind, serverAddress: String) async throws -> GeneratedDocument {
        let url = try endpoint(path: "/api/generate", serverAddress: serverAddress)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(GenerateRequest(text: text, kind: kind))
        return try await send(request, as: GeneratedDocument.self)
    }

    func ask(
        _ question: String,
        agent: AIAgentProfile,
        history: [ConversationTurn],
        apiToken: String,
        serverAddress: String
    ) async throws -> AssistantAnswer {
        let prompt = (history.suffix(20).map { "\($0.role): \($0.content)" } + ["user: \(question)"]).joined(separator: "\n")
        let answer = try await AppleIntelligenceService.answer(prompt, instructions: agent.instructions)
        return AssistantAnswer(answer: answer, provider: "apple-on-device")
    }

    private func remoteAskDisabled(
        _ question: String, agent: AIAgentProfile, history: [ConversationTurn],
        apiToken: String, serverAddress: String
    ) async throws -> AssistantAnswer {
        let url = try endpoint(path: "/api/ask", serverAddress: serverAddress)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(AskRequest(
            text: question,
            agent_id: agent.id,
            instructions: agent.instructions,
            history: Array(history.suffix(20))
        ))
        return try await send(request, as: AssistantAnswer.self)
    }

    func configuration(serverAddress: String) async throws -> AIProviderConfiguration {
        let url = try endpoint(path: "/api/ai/config", serverAddress: serverAddress)
        return try await send(URLRequest(url: url), as: AIProviderConfiguration.self)
    }

    func generateProjectArchive(
        description: String,
        stack: String,
        apiToken: String,
        serverAddress: String
    ) async throws -> URL {
        let url = try endpoint(path: "/api/projects/generate", serverAddress: serverAddress)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(ProjectRequest(description: description, stack: stack))
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIServiceError.badResponse(-1)
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw AIServiceError.badResponse(httpResponse.statusCode)
        }
        guard
            httpResponse.mimeType == "application/zip",
            data.count > 4,
            data.prefix(2) == Data([0x50, 0x4B])
        else {
            throw AIServiceError.invalidProjectArchive
        }
        let archiveURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ecrin-projet-\(UUID().uuidString).zip")
        try data.write(to: archiveURL, options: .atomic)
        return archiveURL
    }

    func health(serverAddress: String) async throws -> AIHealth {
        let url = try endpoint(path: "/api/health", serverAddress: serverAddress)
        return try await send(URLRequest(url: url), as: AIHealth.self)
    }

    private func endpoint(path: String, serverAddress: String) throws -> URL {
        guard remoteAIEnabled else { throw AIServiceError.remoteDisabled }
        guard !serverAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AIServiceError.missingServer
        }
        guard
            let baseURL = URL(string: serverAddress),
            baseURL.scheme?.lowercased() == "https",
            baseURL.host != nil,
            let url = URL(string: path, relativeTo: baseURL)
        else {
            throw AIServiceError.invalidServerURL
        }
        return url.absoluteURL
    }

    private func send<Response: Decodable>(
        _ request: URLRequest,
        as responseType: Response.Type
    ) async throws -> Response {
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIServiceError.badResponse(-1)
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw AIServiceError.badResponse(httpResponse.statusCode)
        }
        return try JSONDecoder().decode(responseType, from: data)
    }
}

private struct TextRequest: Encodable {
    let text: String
}

private struct GenerateRequest: Encodable {
    let text: String
    let kind: DocumentKind
}

private struct AskRequest: Encodable {
    let text: String
    let agent_id: String
    let instructions: String
    let history: [ConversationTurn]
}

private struct ProjectRequest: Encodable {
    let description: String
    let stack: String
}
