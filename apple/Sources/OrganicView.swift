import AVFoundation
import Observation
import SwiftUI
import UniformTypeIdentifiers

@MainActor
@Observable
final class OrganicAudioPlayer: NSObject, AVAudioPlayerDelegate {
    private(set) var title = ""
    private(set) var isPlaying = false
    private(set) var duration: TimeInterval = 0
    private(set) var errorMessage: String?
    var volume: Float = 0.7 { didSet { player?.volume = volume } }
    private var player: AVAudioPlayer?

    var currentTime: TimeInterval { player?.currentTime ?? 0 }

    func load(_ url: URL) async {
        pause()
        errorMessage = nil
        do {
            // Copy only a user-selected file; keep the last playable track on failure.
            let task = Task.detached(priority: .userInitiated) {
                let access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }
                let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                guard size <= 200 * 1_024 * 1_024 else { throw OrganicAudioError.tooLarge }
                let directory = try FileManager.default.url(for: .applicationSupportDirectory,
                    in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("Organic", isDirectory: true)
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                let destination = directory.appendingPathComponent(UUID().uuidString).appendingPathExtension(url.pathExtension)
                try FileManager.default.copyItem(at: url, to: destination)
                return destination
            }
            let copy = try await task.value
            do {
                try Task.checkCancellation()
                let next = try AVAudioPlayer(contentsOf: copy)
                guard next.prepareToPlay() else { throw OrganicAudioError.invalidAudio }
                let previousURL = player?.url
                player?.stop()
                player = next
                next.delegate = self
                next.volume = volume
                duration = next.duration
                title = url.deletingPathExtension().lastPathComponent
                if let previousURL { try? FileManager.default.removeItem(at: previousURL) }
            } catch {
                try? FileManager.default.removeItem(at: copy)
                throw error
            }
        } catch is CancellationError { }
        catch { errorMessage = error.localizedDescription }
    }

    func toggle() {
        guard let player else { return }
        if isPlaying { pause(); return }
        do {
#if os(iOS)
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
#endif
            if player.currentTime >= player.duration { player.currentTime = 0 }
            guard player.play() else { throw OrganicAudioError.invalidAudio }
            isPlaying = true
            errorMessage = nil
        } catch { errorMessage = error.localizedDescription; pause() }
    }

    func pause() {
        player?.pause()
        isPlaying = false
#if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
#endif
    }

    func unload() {
        pause()
        if let url = player?.url { try? FileManager.default.removeItem(at: url) }
        player = nil
        title = ""
        duration = 0
    }

    func seek(_ time: TimeInterval) { player?.currentTime = min(max(time, 0), duration) }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        pause()
        if !flag { errorMessage = OrganicAudioError.invalidAudio.localizedDescription }
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        pause()
        errorMessage = error?.localizedDescription ?? OrganicAudioError.invalidAudio.localizedDescription
    }
}

private enum OrganicAudioError: LocalizedError {
    case tooLarge, invalidAudio
    var errorDescription: String? {
        switch self {
        case .tooLarge: return "Choisissez un fichier audio de moins de 200 Mo."
        case .invalidAudio: return "Ce fichier audio ne peut pas être lu. Essayez un fichier M4A, MP3 ou WAV."
        }
    }
}

struct OrganicView: View {
    @State private var player = OrganicAudioPlayer()
    @Environment(\.scenePhase) private var scenePhase
    @State private var importing = false
    @State private var importTask: Task<Void, Never>?
    @State private var loading = false
    @State private var focusMinutes = 25
    @State private var deadline: Date?
    @State private var remaining: TimeInterval = 25 * 60
    @State private var completed = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Votre espace d’écoute") {
                    Text("Écoutez un fichier choisi dans Fichiers. Aucun son ni abonnement externe n’est ajouté automatiquement.")
                        .foregroundStyle(.secondary)
                    Button("Importer un fichier audio") { importing = true }.disabled(loading)
                    if loading { ProgressView("Préparation du fichier…") }
                    if !player.title.isEmpty {
                        Text(player.title).font(.headline)
                        TimelineView(.periodic(from: .now, by: 0.5)) { _ in
                            VStack(alignment: .leading, spacing: 10) {
                                Slider(value: Binding(get: { player.currentTime }, set: { player.seek($0) }), in: 0...max(player.duration, 1))
                                    .accessibilityLabel("Position de lecture")
                                    .accessibilityValue(clock(player.currentTime) + " sur " + clock(player.duration))
                                Text(clock(player.currentTime) + " / " + clock(player.duration)).font(.caption.monospacedDigit())
                            }
                        }
                        Button(player.isPlaying ? "Mettre en pause" : "Lire le fichier") { player.toggle() }
                        Slider(value: $player.volume, in: 0...1) { Text("Volume") }
                            .accessibilityLabel("Volume")
                        Text("La lecture s’arrête en quittant Organic ou en passant en arrière-plan.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    if let error = player.errorMessage { Text(error).foregroundStyle(.red) }
                }
                Section("Concentration") {
                    Picker("Durée", selection: $focusMinutes) {
                        ForEach([5, 15, 25, 45, 60], id: \.self) { Text("\($0) minutes").tag($0) }
                    }.disabled(deadline != nil)
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        let seconds = deadline.map { max(0, $0.timeIntervalSince(context.date)) } ?? remaining
                        Text(clock(seconds)).font(.system(.largeTitle, design: .monospaced))
                            .accessibilityLabel("Concentration : \(Int(ceil(seconds / 60))) minutes restantes")
                    }
                    HStack {
                        Button(deadline == nil ? "Démarrer" : "Mettre en pause") {
                            if let end = deadline {
                                remaining = max(0, end.timeIntervalSinceNow)
                                deadline = nil
                            } else {
                                completed = false
                                if remaining <= 0 { remaining = Double(focusMinutes * 60) }
                                deadline = Date.now.addingTimeInterval(remaining)
                            }
                        }
                        Button("Réinitialiser") { resetFocus() }
                    }
                    if completed { Text("Session terminée. Prenez une pause.").foregroundStyle(.secondary) }
                    Text("À la fin du minuteur, l’audio est mis en pause. Aucune notification en arrière-plan.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Organic")
            .onChange(of: focusMinutes) { if deadline == nil { remaining = Double(focusMinutes * 60); completed = false } }
            .task(id: deadline) {
                guard let deadline else { return }
                do {
                    try await Task.sleep(for: .seconds(max(0, deadline.timeIntervalSinceNow)))
                    try Task.checkCancellation()
                    remaining = 0
                    self.deadline = nil
                    completed = true
                    player.pause()
                } catch { }
            }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.audio], allowsMultipleSelection: false) { result in
                do {
                    guard let url = try result.get().first else { return }
                    loading = true
                    importTask = Task { @MainActor in
                        await player.load(url)
                        loading = false
                    }
                } catch { importError = error.localizedDescription }
            }
            .alert("Import impossible", isPresented: Binding(get: { importError != nil }, set: { if !$0 { importError = nil } })) {
                Button("OK", role: .cancel) {}
            } message: { Text(importError ?? "") }
            .onChange(of: scenePhase) { if scenePhase != .active { suspend() } }
            .onDisappear { importTask?.cancel(); suspend(); player.unload() }
#if os(iOS)
            .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)) { _ in player.pause() }
#endif
        }
    }

    @State private var importError: String?
    private func resetFocus() { deadline = nil; remaining = Double(focusMinutes * 60); completed = false }
    private func suspend() {
        player.pause()
        if let deadline { remaining = max(0, deadline.timeIntervalSinceNow); self.deadline = nil }
    }
    private func clock(_ seconds: TimeInterval) -> String {
        let value = Int(max(seconds, 0))
        return String(format: "%02d:%02d", value / 60, value % 60)
    }
}
