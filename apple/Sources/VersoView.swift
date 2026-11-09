import PhotosUI
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct VersoView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var memories: [MemoryItem]
    @State private var photo: PhotosPickerItem?
    @State private var importing = false
    @State private var working = false
    @State private var title = ""
    @State private var text = ""
    @State private var labels: [String] = []
    @State private var method = ""
    @State private var errorMessage: String?
    @State private var saved = false
    @State private var operation: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            Form {
                Section("Lire autrement") {
                    Text("Extraire le texte d’une image ou d’un PDF, le corriger puis le conserver dans MemoryOS. Analyse locale, sans envoi au serveur IA.")
                        .foregroundStyle(.secondary)
                    PhotosPicker("Choisir une photo", selection: $photo, matching: .images)
                        .disabled(working)
                    Button("Importer une image, un PDF ou un texte") { importing = true }
                        .disabled(working)
                    if working {
                        ProgressView("Lecture du document…")
                        Button("Annuler la lecture") { operation?.cancel(); working = false }
                    }
                }
                if !method.isEmpty {
                    Section("Résultat à vérifier") {
                        LabeledContent("Traitement", value: method)
                        TextField("Titre", text: $title)
                        TextEditor(text: $text).frame(minHeight: 220)
                        if !labels.isEmpty {
                            Text("Éléments visuels proposés : \(labels.joined(separator: ", "))")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Text("L’OCR peut comporter des erreurs. Vérifiez les noms, montants et dates.")
                            .font(.caption).foregroundStyle(.secondary)
                        ShareLink("Exporter le texte", item: text).disabled(text.isEmpty)
                        Button(saved ? "Enregistré dans MemoryOS" : "Enregistrer dans MemoryOS", action: save)
                            .disabled(saved || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || working)
                    }
                }
            }
            .navigationTitle("Verso")
            .fileImporter(isPresented: $importing, allowedContentTypes: [.pdf, .image, .plainText], allowsMultipleSelection: false) { result in
                do {
                    guard let url = try result.get().first else { return }
                    begin(filename: url.deletingPathExtension().lastPathComponent) {
                        try await DocumentTextExtractor.read(url)
                    }
                } catch { errorMessage = error.localizedDescription }
            }
            .onChange(of: photo) {
                guard let photo else { return }
                begin(filename: "Image analysée") {
                    guard let bytes = try await photo.loadTransferable(type: Data.self) else { throw ExtractionError.noText }
                    return try await DocumentTextExtractor.extract(bytes, filename: "image.jpg")
                }
            }
            .onChange(of: text) { saved = false }
            .onChange(of: title) { saved = false }
            .onDisappear { operation?.cancel(); working = false }
            .alert("Lecture impossible", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK", role: .cancel) {}
            } message: { Text(errorMessage ?? "") }
        }
    }

    private func begin(filename: String, read: @escaping @Sendable () async throws -> ExtractedDocument) {
        operation?.cancel()
        working = true
        errorMessage = nil
        operation = Task { @MainActor in
            do {
                let result = try await read()
                try Task.checkCancellation()
                title = filename
                text = result.text
                labels = result.labels
                method = result.method
                saved = false
                working = false
            } catch is CancellationError { /* Keep the previous draft intact. */ }
            catch { if !Task.isCancelled { errorMessage = error.localizedDescription; working = false } }
        }
    }

    private func save() {
        let content = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }
        guard !memories.contains(where: { $0.content == content }) else {
            errorMessage = "Ce texte est déjà présent dans MemoryOS."
            return
        }
        let item = MemoryItem(title: title.isEmpty ? "Lecture Verso" : title, content: content)
        item.category = "Verso"
        item.visualLabels = labels
        item.tags = ["lecture locale", method]
        modelContext.insert(item)
        do { try modelContext.save(); saved = true }
        catch { modelContext.delete(item); errorMessage = error.localizedDescription }
    }
}
