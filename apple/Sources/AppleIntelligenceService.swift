import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

enum AppleIntelligenceService {
    static var isSupportedByOperatingSystem: Bool {
#if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            return SystemLanguageModel.default.isAvailable
        }
#endif
        return false
    }

    static func answer(_ prompt: String, instructions: String) async throws -> String {
#if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            guard SystemLanguageModel.default.isAvailable else { throw AppleIntelligenceError.unavailable }
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
        "Apple Intelligence demande un appareil et une version du système compatibles. Le mode gratuit ne contacte aucun serveur IA distant."
    }
}
