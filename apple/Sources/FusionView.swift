import SwiftData
import SwiftUI

struct FusionView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MemoryItem.createdAt, order: .reverse) private var memories: [MemoryItem]
    @State private var selection: Set<PersistentIdentifier> = []
    @State private var title = ""
    @State private var draft = ""
    @State private var errorMessage: String?
    @State private var saved = false

    private var selected: [MemoryItem] { memories.filter { selection.contains($0.persistentModelID) } }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Rassemblez plusieurs mémoires dans un nouveau document. Les originaux sont conservés.")
                        .foregroundStyle(.secondary)
                }
                Section("Choisir les sources · \(selected.count)") {
                    if memories.isEmpty {
                        Text("Ajoutez d’abord des documents dans MemoryOS.")
                    }
                    ForEach(memories) { item in
                        Toggle(isOn: Binding(
                            get: { selection.contains(item.persistentModelID) },
                            set: { enabled in
                                if enabled { selection.insert(item.persistentModelID) }
                                else { selection.remove(item.persistentModelID) }
                            }
                        )) {
                            VStack(alignment: .leading) {
                                Text(item.title)
                                Text(item.createdAt, style: .date).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                Section("Assemblage local") {
                    Button("Préparer la fusion") { prepare() }
                        .disabled(selected.count < 2)
                    Text("Assemblage des textes avec leurs titres et dates. Aucune synthèse IA automatique.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if !draft.isEmpty {
                    Section("Document à vérifier") {
                        TextField("Titre de la fusion", text: $title)
                        TextEditor(text: $draft).frame(minHeight: 240)
                        ShareLink("Exporter le texte", item: draft)
                        Button(saved ? "Fusion enregistrée" : "Créer une nouvelle mémoire", action: save)
                            .disabled(saved || draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            .navigationTitle("Fusion")
            .onChange(of: selection) { draft = ""; saved = false }
            .onChange(of: draft) { saved = false }
            .onChange(of: title) { saved = false }
            .alert("Fusion impossible", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK", role: .cancel) {}
            } message: { Text(errorMessage ?? "") }
        }
    }

    private func prepare() {
        guard selected.count >= 2 else { return }
        title = "Fusion — \(selected.map(\.title).prefix(3).joined(separator: " + "))"
        draft = selected.map {
            "# \($0.title)\nSource créée le \($0.createdAt.formatted(date: .numeric, time: .shortened))\n\n\($0.content)"
        }.joined(separator: "\n\n––––––––\n\n")
        saved = false
    }

    private func save() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        guard !memories.contains(where: { $0.content == text }) else {
            errorMessage = "Ce document est déjà présent dans MemoryOS."
            return
        }
        let item = MemoryItem(title: title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Fusion" : title, content: text)
        item.category = "Fusion"
        item.tags = ["fusion", "assemblage local"]
        modelContext.insert(item)
        do { try modelContext.save(); saved = true }
        catch { modelContext.delete(item); errorMessage = error.localizedDescription }
    }
}
