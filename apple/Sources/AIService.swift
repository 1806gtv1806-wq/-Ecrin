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

enum DocumentKind: String, Encodable, Sendable {
    case notice
    case guide
}

enum AIServiceError: LocalizedError {
    case missingServer
    case invalidServerURL
    case badResponse(Int)

    var errorDescription: String? {
        switch self {
        case .missingServer:
            return "Configurez l’adresse HTTPS de votre serveur IA dans Réglages."
        case .invalidServerURL:
            return "L’adresse du serveur doit être une URL HTTPS valide."
        case .badResponse(let status):
            return "Le serveur IA a répondu avec le code HTTP \(status)."
        }
    }
}

struct AIService {
    private let session: URLSession

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

    func health(serverAddress: String) async throws -> AIHealth {
        let url = try endpoint(path: "/api/health", serverAddress: serverAddress)
        return try await send(URLRequest(url: url), as: AIHealth.self)
    }

    private func endpoint(path: String, serverAddress: String) throws -> URL {
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
