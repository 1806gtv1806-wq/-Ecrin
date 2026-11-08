import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

enum AppleIntelligenceService {
    static var isSupportedByOperatingSystem: Bool {
#if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            return true
        }
#endif
        return false
    }

    static func answer(_ prompt: String, instructions: String) async throws -> String {
#if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            let session = LanguageModelSession(instructions: instructions)
            let response = try await session.respond(to: prompt)
            return response.content
        }
#endif
        throw AppleIntelligenceError.unavailable
    }
}

enum AppleIntelligenceError: LocalizedError {
    case unavailable

    var errorDescription: String? {
        "Apple Intelligence demande un appareil et une version du système compatibles. Vous pouvez choisir le serveur IA configuré."
    }
}
