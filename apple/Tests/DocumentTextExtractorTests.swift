import CoreGraphics
import UIKit
import XCTest
@testable import Ecrin_iOS

final class DocumentTextExtractorTests: XCTestCase {
    func testUTF8ContentIsPreserved() async throws {
        let original = "Facture ÉCRIN\nTotal : CHF 42.50\n"
        let result = try await DocumentTextExtractor.extract(Data(original.utf8), filename: "facture.txt")
        XCTAssertEqual(result.text, original)
        XCTAssertTrue(result.labels.isEmpty)
        XCTAssertEqual(result.method, "Texte UTF-8")
    }

    func testInvalidUTF8IsRejectedInsteadOfReplaced() async {
        do {
            _ = try await DocumentTextExtractor.extract(Data([0xFF, 0xFE, 0xFF]), filename: "note.txt")
            XCTFail("Expected an encoding failure")
        } catch ExtractionError.encoding { }
        catch { XCTFail("Unexpected error: \(error)") }
    }

    func testOversizedDocumentIsRejected() async {
        do {
            _ = try await DocumentTextExtractor.extract(Data(count: DocumentTextExtractor.maximumBytes + 1), filename: "scan.pdf")
            XCTFail("Expected size limit")
        } catch ExtractionError.tooLarge { }
        catch { XCTFail("Unexpected error: \(error)") }
    }

    @MainActor
    func testScannedPDFRunsOCRRatherThanReturningEmptyText() async throws {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 1000, height: 300)).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 1000, height: 300))
            ("ECRIN VALIDATION 322" as NSString).draw(at: CGPoint(x: 50, y: 100), withAttributes: [
                .font: UIFont.systemFont(ofSize: 50), .foregroundColor: UIColor.black
            ])
        }
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 1000, height: 300))
        let pdf = renderer.pdfData { context in
            context.beginPage()
            image.draw(in: CGRect(x: 0, y: 0, width: 1000, height: 300))
        }
        let result = try await DocumentTextExtractor.extract(pdf, filename: "scan.pdf")
        XCTAssertTrue(result.text.localizedCaseInsensitiveContains("ECRIN"), result.text)
        XCTAssertTrue(result.text.contains("322"), result.text)
        XCTAssertTrue(result.method.contains("1 pages OCR"))
    }

    @MainActor
    func testTooManyPagesFailsWithoutReturningPartialText() async {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 100, height: 100))
        let pdf = renderer.pdfData { context in
            for _ in 0...DocumentTextExtractor.maximumPages { context.beginPage() }
        }
        do {
            _ = try await DocumentTextExtractor.extract(pdf, filename: "long.pdf")
            XCTFail("Expected page limit")
        } catch ExtractionError.tooManyPages { }
        catch { XCTFail("Unexpected error: \(error)") }
    }

    func testCancelledExtractionDoesNotReturnAResult() async {
        let task = Task {
            try await DocumentTextExtractor.extract(Data("texte".utf8), filename: "note.txt")
        }
        task.cancel()
        do { _ = try await task.value; XCTFail("Expected cancellation") }
        catch is CancellationError { }
        catch { XCTFail("Unexpected error: \(error)") }
    }
}
