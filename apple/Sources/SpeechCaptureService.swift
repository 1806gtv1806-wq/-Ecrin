import AVFoundation
import Speech
import SwiftUI

@MainActor
final class SpeechCaptureService: ObservableObject {
    @Published private(set) var isRecording = false

    private let audioEngine = AVAudioEngine()
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "fr-FR"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var activeStartID: UUID?
    private var activeRecognitionID: UUID?

    func start(
        onText: @escaping (String, Bool) -> Void,
        onError: @escaping (String) -> Void
    ) async throws {
        guard !isRecording, activeStartID == nil else { return }
        let startID = UUID()
        activeStartID = startID
        defer {
            if activeStartID == startID {
                activeStartID = nil
            }
        }
        try await requestPermissions()
        guard activeStartID == startID else { return }
        guard let recognizer, recognizer.isAvailable else {
            throw SpeechCaptureError.recognizerUnavailable
        }

#if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .duckOthers])
        try session.setActive(true, options: .notifyOthersOnDeactivation)
#endif

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        recognitionRequest = request
        let recognitionID = UUID()
        activeRecognitionID = recognitionID

        let input = audioEngine.inputNode
        input.installTap(onBus: 0, bufferSize: 1024, format: input.outputFormat(forBus: 0)) { buffer, _ in
            request.append(buffer)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            input.removeTap(onBus: 0)
            recognitionRequest = nil
            activeRecognitionID = nil
            throw error
        }
        isRecording = true

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            if let result {
                let text = result.bestTranscription.formattedString
                let isFinal = result.isFinal
                Task { @MainActor in
                    guard self?.activeRecognitionID == recognitionID else { return }
                    onText(text, isFinal)
                    if isFinal {
                        self?.finish(recognitionID)
                    }
                }
            }
            if let error {
                Task { @MainActor in
                    guard self?.activeRecognitionID == recognitionID else { return }
                    self?.finish(recognitionID)
                    onError(error.localizedDescription)
                }
            }
        }
    }

    func stop() {
        activeStartID = nil
        guard isRecording else { return }
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        activeRecognitionID = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        isRecording = false
#if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
#endif
    }

    private func finish(_ recognitionID: UUID) {
        guard isRecording, activeRecognitionID == recognitionID else { return }
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        activeRecognitionID = nil
        recognitionRequest = nil
        recognitionTask = nil
        isRecording = false
#if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
#endif
    }

    private func requestPermissions() async throws {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:
            break
        case .notDetermined:
            let status = await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
            }
            guard status == .authorized else {
                throw SpeechCaptureError.speechPermissionDenied
            }
        case .denied, .restricted:
            throw SpeechCaptureError.speechPermissionDenied
        @unknown default:
            throw SpeechCaptureError.speechPermissionDenied
        }

        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            break
        case .notDetermined:
            let granted = await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: .audio) { continuation.resume(returning: $0) }
            }
            guard granted else {
                throw SpeechCaptureError.microphonePermissionDenied
            }
        case .denied, .restricted:
            throw SpeechCaptureError.microphonePermissionDenied
        @unknown default:
            throw SpeechCaptureError.microphonePermissionDenied
        }
    }
}

enum SpeechCaptureError: LocalizedError {
    case speechPermissionDenied
    case microphonePermissionDenied
    case recognizerUnavailable

    var errorDescription: String? {
        switch self {
        case .speechPermissionDenied:
            return "Autorisez la reconnaissance vocale dans Réglages pour utiliser la dictée."
        case .microphonePermissionDenied:
            return "Autorisez l’accès au microphone dans Réglages pour dicter une question."
        case .recognizerUnavailable:
            return "La reconnaissance vocale française est indisponible pour le moment."
        }
    }
}
