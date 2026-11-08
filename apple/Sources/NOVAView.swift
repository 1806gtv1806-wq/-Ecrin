import SwiftData
import SwiftUI

struct NOVAView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MemoryItem.createdAt, order: .reverse) private var memories: [MemoryItem]
    @AppStorage("nova.intentDraft") private var intentDraft = ""
    @StateObject private var speechCapture = SpeechCaptureService()
    @State private var transcript = ""
    @State private var searchText = ""
    @State private var errorMessage: String?
    @State private var savedMessage: String?

    private var exchanges: [MemoryItem] {
        memories.filter { $0.category == "NOVA" }
    }

    private var filteredExchanges: [MemoryItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return exchanges }
        return exchanges.filter {
            $0.title.localizedCaseInsensitiveContains(query)
                || $0.content.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    VStack(spacing: 12) {
                        Image(systemName: speechCapture.isRecording ? "waveform" : "waveform.circle")
                            .font(.system(size: 38, weight: .ultraLight))
                            .foregroundStyle(Color(red: 0.28, green: 0.43, blue: 0.34))
                            .symbolEffect(.pulse, isActive: speechCapture.isRecording)
                            .frame(width: 92, height: 92)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 30, style: .continuous)
                                    .stroke(.white.opacity(0.82), lineWidth: 1)
                            }
                            .accessibilityHidden(true)

                        Text(speechCapture.isRecording ? "Je vous écoute…" : "Une idée en tête ?")
                            .font(.system(size: 25, weight: .light, design: .serif))
                            .foregroundStyle(Color(red: 0.14, green: 0.22, blue: 0.18))

                        Text("Dictez une pensée, puis enregistrez la transcription dans MemoryOS.")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 28)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("TRANSCRIPTION")
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(1.6)
                            .foregroundStyle(.secondary)
                        TextEditor(text: $transcript)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 140)
                            .padding(9)
                            .background(.white.opacity(0.58), in: RoundedRectangle(cornerRadius: 16))
                            .overlay {
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(.white.opacity(0.85), lineWidth: 1)
                            }
                            .accessibilityLabel("Transcription de la note vocale")
                    }
                    .frame(maxWidth: 640)

                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle")
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .frame(maxWidth: 640, alignment: .leading)
                    }
                    if let savedMessage {
                        Label(savedMessage, systemImage: "checkmark.circle")
                            .font(.footnote)
                            .foregroundStyle(Color(red: 0.28, green: 0.43, blue: 0.34))
                            .frame(maxWidth: 640, alignment: .leading)
                    }

                    HStack(spacing: 10) {
                        Button(action: toggleRecording) {
                            Label(
                                speechCapture.isRecording ? "Terminer" : "Dicter",
                                systemImage: speechCapture.isRecording ? "stop.fill" : "mic.fill"
                            )
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .foregroundStyle(.white)
                            .background(
                                speechCapture.isRecording
                                    ? Color(red: 0.55, green: 0.29, blue: 0.26)
                                    : Color(red: 0.2, green: 0.36, blue: 0.27),
                                in: Capsule()
                            )
                        }

                        Button(action: saveTranscript) {
                            Label("Garder la note", systemImage: "square.and.arrow.down")
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(.ultraThinMaterial, in: Capsule())
                        }
                        .disabled(transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: 640)

                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Vos échanges")
                                    .font(.system(size: 19, weight: .light, design: .serif))
                                Text("Les transcriptions sauvegardées dans MemoryOS")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(exchanges.count)")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary)
                        }

                        if exchanges.isEmpty {
                            Text("Vos notes vocales apparaîtront ici.")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                                .padding(15)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                        } else {
                            ForEach(filteredExchanges) { item in
                                NavigationLink {
                                    MemoryDetailView(item: item)
                                } label: {
                                    MemoryRow(item: item)
                                        .padding(14)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .frame(maxWidth: 640)
                    .padding(.top, 7)
                    .padding(.bottom, 18)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 18)
            }
            .scrollIndicators(.hidden)
            .background {
                LinearGradient(
                    colors: [Color(red: 0.93, green: 0.95, blue: 0.92), Color(red: 0.87, green: 0.91, blue: 0.88)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            }
            .navigationTitle("NOVA")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Rechercher dans les transcriptions")
            .onDisappear {
                speechCapture.stop()
            }
            .onAppear(perform: importIntentDraft)
            .onChange(of: intentDraft) {
                importIntentDraft()
            }
        }
    }

    private func toggleRecording() {
        errorMessage = nil
        savedMessage = nil
        if speechCapture.isRecording {
            speechCapture.stop()
            return
        }
        Task {
            do {
                try await speechCapture.start(
                    onText: { text, _ in
                        transcript = text
                    },
                    onError: { message in
                        errorMessage = message
                    }
                )
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func saveTranscript() {
        let text = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let item = MemoryItem(
            title: String(text.split(whereSeparator: \.isWhitespace).prefix(7).joined(separator: " ")),
            content: text,
            createdAt: .now
        )
        item.summary = String(text.prefix(240))
        item.category = "NOVA"
        modelContext.insert(item)
        do {
            try modelContext.save()
            savedMessage = "Note enregistrée dans MemoryOS."
            transcript = ""
        } catch {
            modelContext.delete(item)
            errorMessage = error.localizedDescription
        }
    }

    private func importIntentDraft() {
        guard !intentDraft.isEmpty else { return }
        transcript = intentDraft
        intentDraft = ""
    }
}
