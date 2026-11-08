import Foundation
import Vision

struct ImageAnalysis: Sendable {
    let recognizedText: String
    let labels: [String]
}

enum ImageAnalyzer {
    static func analyze(_ data: Data) async throws -> ImageAnalysis {
        try await Task.detached {
            let textRequest = VNRecognizeTextRequest()
            textRequest.recognitionLevel = .accurate
            textRequest.usesLanguageCorrection = true

            let classificationRequest = VNClassifyImageRequest()
            let handler = VNImageRequestHandler(data: data)
            try handler.perform([textRequest, classificationRequest])

            let recognizedText = (textRequest.results ?? [])
                .compactMap { $0.topCandidates(1).first?.string }
                .joined(separator: "\n")
            let labels = (classificationRequest.results ?? [])
                .prefix(5)
                .map(\.identifier)

            return ImageAnalysis(recognizedText: recognizedText, labels: labels)
        }.value
    }
}
