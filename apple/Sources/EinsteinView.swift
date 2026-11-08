import AVFoundation
import MultipeerConnectivity
import SwiftData
import SwiftUI

struct EinsteinView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("aiServerAddress") private var aiServerAddress = ""
    @Query(sort: \MemoryItem.createdAt, order: .reverse) private var memories: [MemoryItem]
    @StateObject private var speechCapture = SpeechCaptureService()
    @StateObject private var speechOutput = SpeechOutputService()
    @StateObject private var nearbyHandoff = NearbyHandoffService()
    @State private var apiAccessToken = ""
    @State private var activeProfile: AIAgentProfile
    @State private var question = ""
    @State private var answer = ""
    @State private var conversationHistory: [ConversationTurn] = []
    @State private var includeMemoryContext = false
    @State private var state: AssistantState = .ready
    @State private var errorMessage: String?
    @State private var savedMessage: String?
    @State private var showingTransferConfirmation = false

    init(profile: AIAgentProfile = AIAgentProfile.builtIns[0]) {
        _activeProfile = State(initialValue: profile)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 14) {
                            Image(systemName: expressionSymbol)
                                .font(.system(size: 23, weight: .light))
                                .foregroundStyle(Color(red: 0.29, green: 0.43, blue: 0.35))
                                .frame(width: 52, height: 52)
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 17))
                                .symbolEffect(.pulse, isActive: state == .listening || state == .processing)
                                .accessibilityLabel(state.label)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(activeProfile.name)
                                    .font(.system(size: 21, weight: .medium, design: .serif))
                                Text(state.label)
                                    .font(.system(size: 12))
                                    .foregroundStyle(state == .error ? Color.red : Color.secondary)
                            }
                            Spacer()
                            if state == .processing {
                                ProgressView()
                            } else if speechOutput.isSpeaking {
                                Button {
                                    speechOutput.stop()
                                    state = .ready
                                } label: {
                                    Label("Interrompre", systemImage: "stop.fill")
                                        .labelStyle(.iconOnly)
                                }
                                .accessibilityLabel("Interrompre la réponse")
                            }
                        }
                        .padding(16)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .stroke(.white.opacity(0.75), lineWidth: 1)
                        }

                        if !nearbyHandoff.connectedPeers.isEmpty {
                            Label(
                                "Un autre écran ÉCRIN est à proximité",
                                systemImage: "ipad.and.iphone"
                            )
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(Color(red: 0.29, green: 0.43, blue: 0.35))

                            Button {
                                showingTransferConfirmation = true
                            } label: {
                                Label("Proposer le transfert d’Einstein", systemImage: "arrow.left.arrow.right")
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 44)
                                    .background(.ultraThinMaterial, in: Capsule())
                            }
                            .buttonStyle(.plain)
                            .disabled(state == .processing || state == .authorizing)
                        }

                        if let errorMessage {
                            Label(errorMessage, systemImage: "exclamationmark.triangle")
                                .font(.footnote)
                                .foregroundStyle(.red)
                                .padding(14)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(.red.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))
                        }

                        if !answer.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Label("Réponse", systemImage: "sparkles")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Color(red: 0.29, green: 0.43, blue: 0.35))
                                Text(answer)
                                    .font(.system(size: 15))
                                    .lineSpacing(5)
                                    .textSelection(.enabled)
                                Button(action: saveExchange) {
                                    Label(
                                        savedMessage ?? "Enregistrer dans MemoryOS",
                                        systemImage: savedMessage == nil ? "square.and.arrow.down" : "checkmark"
                                    )
                                }
                                .disabled(savedMessage != nil)
                                .font(.footnote.weight(.medium))
                            }
                            .padding(18)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .stroke(.white.opacity(0.75), lineWidth: 1)
                            }
                        } else {
                            ContentUnavailableView(
                                "Que souhaitez-vous explorer ?",
                                systemImage: "bubble.left.and.bubble.right",
                                description: Text("Écrivez votre question ou dictez-la. Einstein utilise le serveur IA configuré dans les réglages.")
                            )
                            .frame(maxWidth: .infinity, minHeight: 200)
                        }

                        if activeProfile.canUseMemory {
                            Toggle(isOn: $includeMemoryContext) {
                                Label(
                                    "Inclure des extraits pertinents de MemoryOS",
                                    systemImage: "lock.shield"
                                )
                                .font(.system(size: 11))
                            }
                        }
                    }
                    .frame(maxWidth: 680)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 18)
                    .padding(.top, 20)
                }
                .scrollIndicators(.hidden)

                VStack(spacing: 12) {
                    TextField("Votre question à Einstein…", text: $question, axis: .vertical)
                        .lineLimit(2...5)
                        .padding(13)
                        .background(.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 14))
                        .overlay {
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(.white.opacity(0.85), lineWidth: 1)
                        }

                    HStack(spacing: 10) {
                        Button(action: toggleListening) {
                            Label(
                                speechCapture.isRecording ? "Arrêter l’écoute" : "Dicter",
                                systemImage: speechCapture.isRecording ? "stop.circle.fill" : "mic"
                            )
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                            .background(.ultraThinMaterial, in: Capsule())
                        }
                        .disabled(state == .processing)

                        Button {
                            Task { await askEinstein() }
                        } label: {
                            Label("Demander", systemImage: "arrow.up")
                                .frame(maxWidth: .infinity)
                                .frame(height: 46)
                                .foregroundStyle(.white)
                                .background(Color(red: 0.2, green: 0.36, blue: 0.27), in: Capsule())
                        }
                        .disabled(
                            state == .processing
                                || question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        )
                    }
                    .buttonStyle(.plain)

                    Text("Dictée avec Speech · réponses par Apple Intelligence compatible ou par le serveur configuré.")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: 680)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 18)
                .padding(.bottom, 8)
            }
            .background {
                LinearGradient(
                    colors: [Color(red: 0.93, green: 0.95, blue: 0.92), Color(red: 0.88, green: 0.92, blue: 0.89)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            }
            .navigationTitle(activeProfile.name)
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                nearbyHandoff.start()
                do {
                    apiAccessToken = try SecureStore.readAPIAccessToken() ?? ""
                } catch {
                    errorMessage = error.localizedDescription
                    state = .error
                }
                speechOutput.onFinish = {
                    if state == .responding {
                        state = .ready
                    }
                }
            }
            .onDisappear {
                speechCapture.stop()
                speechOutput.stop()
                nearbyHandoff.stop()
            }
            .confirmationDialog(
                "Continuer Einstein sur un autre écran ?",
                isPresented: $showingTransferConfirmation,
                titleVisibility: .visible
            ) {
                ForEach(Array(nearbyHandoff.connectedPeers.enumerated()), id: \.offset) { index, peer in
                    Button("Transférer vers l’appareil \(index + 1)") {
                        transfer(to: peer)
                    }
                }
                Button("Annuler", role: .cancel) {}
            } message: {
                Text("Seule cette question et sa réponse seront transférées. L’écoute et la lecture vocale s’arrêteront sur cet appareil.")
            }
            .alert(
                "Einstein veut continuer ici",
                isPresented: Binding(
                    get: { nearbyHandoff.incomingTransfer != nil },
                    set: { if !$0 { nearbyHandoff.declineIncomingTransfer() } }
                )
            ) {
                Button("Continuer") {
                    guard let transfer = nearbyHandoff.acceptIncomingTransfer() else { return }
                    speechCapture.stop()
                    speechOutput.stop()
                    activeProfile = transfer.profile
                    question = transfer.question
                    answer = transfer.answer
                    conversationHistory = transfer.history
                    includeMemoryContext = false
                    savedMessage = nil
                    errorMessage = nil
                    state = .ready
                }
                Button("Ignorer", role: .cancel) {
                    nearbyHandoff.declineIncomingTransfer()
                }
            } message: {
                Text("Un appareil ÉCRIN à proximité vous propose de reprendre une conversation. Aucun contenu n’est appliqué avant votre accord.")
            }
        }
    }

    private func toggleListening() {
        errorMessage = nil
        if speechCapture.isRecording {
            speechCapture.stop()
            state = .ready
            return
        }
        state = .authorizing
        Task {
            do {
                try await speechCapture.start(
                    onText: { text, isFinal in
                        question = text
                        if isFinal {
                            state = .ready
                        }
                    },
                    onError: { message in
                        errorMessage = message
                        state = .error
                    }
                )
                if speechCapture.isRecording {
                    state = .listening
                }
            } catch {
                errorMessage = error.localizedDescription
                state = .error
            }
        }
    }

    private func askEinstein() async {
        let userQuestion = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !userQuestion.isEmpty else { return }
        guard userQuestion.count <= 12000 else {
            errorMessage = "Votre question dépasse la limite de 12 000 caractères."
            state = .error
            return
        }
        errorMessage = nil
        savedMessage = nil
        answer = ""
        state = .processing
        do {
            let context = includeMemoryContext ? relevantMemory(for: userQuestion) : []
            let prompt: String
            if context.isEmpty {
                prompt = userQuestion
            } else {
                let contextExcerpt = context.map { item in
                    let source = item.summary.isEmpty ? item.content : item.summary
                    return "[\(item.title)] \(source.prefix(1200))"
                }.joined(separator: "\n")
                prompt = """
                Question de l’utilisateur :
                \(userQuestion)

                Extraits de MemoryOS explicitement autorisés par l’utilisateur (références possibles : \(context.map(\.title).joined(separator: ", "))):
                \(contextExcerpt)

                Utilise ces extraits uniquement s’ils sont pertinents. Distingue clairement les informations des extraits de tes propres suggestions.
                """
            }
            guard prompt.count <= 12000 else {
                throw EinsteinViewError.promptTooLarge
            }

            let responseText: String
            switch activeProfile.executionPreference {
            case .server:
                let response = try await AIService().ask(
                    prompt,
                    agent: activeProfile,
                    history: conversationHistory,
                    apiToken: apiAccessToken,
                    serverAddress: aiServerAddress
                )
                responseText = response.answer
            case .appleOnDevice:
                let historyText = conversationHistory.suffix(12).map {
                    "\($0.role == "user" ? "Utilisateur" : "Agent") : \(String($0.content.prefix(3000)))"
                }.joined(separator: "\n")
                responseText = try await AppleIntelligenceService.answer(
                    "\(historyText)\nUtilisateur : \(prompt)",
                    instructions: activeProfile.instructions
                )
            }
            answer = responseText
            conversationHistory.append(.user(userQuestion))
            conversationHistory.append(.assistant(responseText))
            conversationHistory = Array(conversationHistory.suffix(20))
            state = .responding
            speechOutput.speak(responseText)
        } catch {
            errorMessage = error.localizedDescription
            state = .error
        }
    }

    private func saveExchange() {
        let item = MemoryItem(
            title: "Échange avec \(activeProfile.name)",
            content: "Question :\n\(question)\n\nRéponse :\n\(answer)",
            createdAt: .now
        )
        item.summary = String(answer.prefix(240))
        item.category = "Conversation"
        modelContext.insert(item)
        do {
            try modelContext.save()
            savedMessage = "Enregistré dans MemoryOS"
        } catch {
            modelContext.delete(item)
            errorMessage = error.localizedDescription
            state = .error
        }
    }

    private func transfer(to peer: MCPeerID) {
        guard !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !answer.isEmpty else {
            errorMessage = "Commencez une conversation avant de la transférer."
            return
        }
        do {
            try nearbyHandoff.send(
                EinsteinHandoffPayload(
                    profile: activeProfile,
                    question: question,
                    answer: answer,
                    history: Array(conversationHistory.suffix(8))
                ),
                to: peer
            )
            speechCapture.stop()
            speechOutput.stop()
            state = .ready
            savedMessage = "Transfert envoyé. Acceptez-le sur l’autre appareil."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func relevantMemory(for prompt: String) -> [MemoryItem] {
        guard activeProfile.canUseMemory else { return [] }
        let terms = Set(
            prompt.lowercased()
                .split { !$0.isLetter && !$0.isNumber }
                .filter { $0.count > 2 }
                .map(String.init)
        )
        guard !terms.isEmpty else { return [] }
        return memories
            .compactMap { item -> (MemoryItem, Int)? in
                let searchable = ([item.title, item.summary, item.category] + item.tags + item.visualLabels)
                    .joined(separator: " ")
                    .lowercased()
                let score = terms.reduce(into: 0) { count, term in
                    if searchable.localizedStandardContains(term) { count += 2 }
                    else if item.content.lowercased().localizedStandardContains(term) { count += 1 }
                }
                return score > 0 ? (item, score) : nil
            }
            .sorted { $0.1 > $1.1 }
            .prefix(3)
            .map(\.0)
    }

    private var expressionSymbol: String {
        switch state {
        case .authorizing, .processing: return "brain.head.profile"
        case .listening: return "waveform"
        case .ready, .responding, .error: return "sparkles"
        }
    }
}

private enum EinsteinViewError: LocalizedError {
    case promptTooLarge

    var errorDescription: String? {
        "La question et les extraits mémoire dépassent la limite de taille. Désactivez l’accès à MemoryOS ou raccourcissez la question."
    }
}

@MainActor
private final class SpeechOutputService: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    @Published private(set) var isSpeaking = false
    var onFinish: (() -> Void)?

    private let synthesizer = AVSpeechSynthesizer()

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "fr-FR")
        isSpeaking = true
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
    }

    func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        isSpeaking = false
        onFinish?()
    }

    func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didCancel utterance: AVSpeechUtterance
    ) {
        isSpeaking = false
    }
}

private enum AssistantState: Equatable {
    case ready
    case authorizing
    case listening
    case processing
    case responding
    case error

    var label: String {
        switch self {
        case .ready: return "Prêt à vous écouter"
        case .authorizing: return "Autorisation et démarrage du microphone"
        case .listening: return "Écoute en cours"
        case .processing: return "Réflexion en cours"
        case .responding: return "Eurêka !"
        case .error: return "Une erreur est survenue"
        }
    }
}
