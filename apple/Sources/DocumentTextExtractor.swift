import CoreGraphics
import Foundation
import PDFKit
import Vision

struct ExtractedDocument: Sendable {
    let text: String
    let labels: [String]
    let method: String
}

/// Extracts a working copy of text only. Never alters or deletes the source.
enum DocumentTextExtractor {
    static let maximumBytes = 30 * 1_024 * 1_024
    static let maximumPages = 100

    static func read(_ url: URL) async throws -> ExtractedDocument {
        let task = Task.detached(priority: .userInitiated) {
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            guard size <= maximumBytes else { throw ExtractionError.tooLarge }
            let data = try Data(contentsOf: url)
            try Task.checkCancellation()
            return try await extract(data, filename: url.lastPathComponent)
        }
        return try await withTaskCancellationHandler {
            let result = try await task.value
            try Task.checkCancellation()
            return result
        } onCancel: { task.cancel() }
    }

    static func extract(_ data: Data, filename: String) async throws -> ExtractedDocument {
        guard data.count <= maximumBytes else { throw ExtractionError.tooLarge }
        let task = Task.detached(priority: .userInitiated) {
            try Task.checkCancellation()
            switch (filename as NSString).pathExtension.lowercased() {
            case "pdf": return try readPDF(data)
            case "txt", "md", "csv", "json":
                guard let text = String(data: data, encoding: .utf8) else {
                    throw ExtractionError.encoding
                }
                return try result(text, method: "Texte UTF-8")
            default:
                let analysis = try await ImageAnalyzer.analyze(data)
                guard !analysis.recognizedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || !analysis.labels.isEmpty else { throw ExtractionError.noText }
                return ExtractedDocument(text: analysis.recognizedText, labels: analysis.labels, method: "Vision sur l’appareil")
            }
        }
        return try await withTaskCancellationHandler {
            let result = try await task.value
            try Task.checkCancellation()
            return result
        } onCancel: { task.cancel() }
    }

    private static func readPDF(_ data: Data) throws -> ExtractedDocument {
        guard let document = PDFDocument(data: data), !document.isLocked else {
            throw ExtractionError.lockedPDF
        }
        guard document.pageCount > 0 else { throw ExtractionError.noText }
        guard document.pageCount <= maximumPages else { throw ExtractionError.tooManyPages }
        var pages: [String] = []
        var ocrPages = 0
        var hasRecognizedText = false
        for index in 0..<document.pageCount {
            try Task.checkCancellation()
            guard let page = document.page(at: index) else { throw ExtractionError.invalidPage }
            let selectable = (page.string ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let text: String
            if selectable.isEmpty {
                text = try recognize(page)
                ocrPages += 1
            } else { text = selectable }
            if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { hasRecognizedText = true }
            pages.append("Page \(index + 1)\n\(text.isEmpty ? "[Aucun texte reconnu sur cette page]" : text)")
        }
        guard hasRecognizedText else { throw ExtractionError.noText }
        return try result(pages.joined(separator: "\n\n"), method: "PDF · \(document.pageCount) pages · \(ocrPages) pages OCR")
    }

    private static func recognize(_ page: PDFPage) throws -> String {
        guard let pdfPage = page.pageRef else { throw ExtractionError.invalidPage }
        let bounds = pdfPage.getBoxRect(.mediaBox)
        guard bounds.width > 0, bounds.height > 0 else { throw ExtractionError.invalidPage }
        let rotated = abs(pdfPage.rotationAngle) % 180 == 90
        let sourceWidth = rotated ? bounds.height : bounds.width
        let sourceHeight = rotated ? bounds.width : bounds.height
        let scale = min(2.5, 2000 / max(sourceWidth, sourceHeight))
        let width = max(1, Int(sourceWidth * scale))
        let height = max(1, Int(sourceHeight * scale))
        guard let context = CGContext(data: nil, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { throw ExtractionError.invalidPage }
        let target = CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height))
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(target)
        context.concatenate(pdfPage.getDrawingTransform(.mediaBox, rect: target, rotate: 0, preserveAspectRatio: true))
        context.drawPDFPage(pdfPage)
        guard let image = context.makeImage() else { throw ExtractionError.invalidPage }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["fr-FR", "en-US"]
        try VNImageRequestHandler(cgImage: image).perform([request])
        return (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
    }

    private static func result(_ text: String, method: String) throws -> ExtractedDocument {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw ExtractionError.noText }
        return ExtractedDocument(text: text, labels: [], method: method)
    }
}

enum ExtractionError: LocalizedError {
    case tooLarge, tooManyPages, encoding, noText, lockedPDF, invalidPage
    var errorDescription: String? {
        switch self {
        case .tooLarge: return "Ce fichier dépasse la limite de 30 Mo. Choisissez un fichier plus petit."
        case .tooManyPages: return "Ce PDF dépasse 100 pages. Importez une section plus courte."
        case .encoding: return "Ce fichier texte n’est pas encodé en UTF-8."
        case .noText: return "Aucun texte n’a été reconnu. L’original reste intact."
        case .lockedPDF: return "Ce PDF est protégé ou illisible. Importez une copie déverrouillée."
        case .invalidPage: return "Une page du PDF ne peut pas être lue. Aucun texte partiel n’a été ajouté."
        }
    }
}
