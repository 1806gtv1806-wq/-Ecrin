import PhotosUI
import SwiftData
import SwiftUI

struct MainView: View {
    var body: some View {
        TabView {
            MemoryListView()
                .tabItem {
                    Label("Mémoire", systemImage: "square.stack.3d.up")
                }

            SettingsView()
                .tabItem {
                    Label("Réglages IA", systemImage: "slider.horizontal.3")
                }
        }
    }
}

private struct MemoryListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MemoryItem.createdAt, order: .reverse) private var items: [MemoryItem]
    @State private var showingComposer = false
    @State private var selectedOnly = false
    @State private var isClassifying = false
    @State private var errorMessage: String?
    @AppStorage("aiServerAddress") private var aiServerAddress = ""
    private let reminderScheduler = ReminderScheduler()

    private var visibleItems: [MemoryItem] {
        selectedOnly ? items.filter(\.isSelected) : items
    }

    var body: some View {
        NavigationStack {
            List {
                if visibleItems.isEmpty {
                    ContentUnavailableView(
                        selectedOnly ? "Aucune note sélectionnée" : "Votre mémoire est vide",
                        systemImage: "tray",
                        description: Text(selectedOnly
                            ? "Sélectionnez des notes pour les classer ensemble."
                            : "Ajoutez une idée, un texte ou une image pour commencer.")
                    )
                } else {
                    ForEach(visibleItems) { item in
                        NavigationLink {
                            MemoryDetailView(item: item)
                        } label: {
                            MemoryRow(item: item)
                        }
                        .swipeActions {
                            Button {
                                item.isSelected.toggle()
                            } label: {
                                Label(
                                    item.isSelected ? "Désélectionner" : "Sélectionner",
                                    systemImage: item.isSelected ? "checkmark.circle.fill" : "circle"
                                )
                            }
                            .tint(.indigo)
                        }
                    }
                    .onDelete(perform: deleteItems)
                }
            }
            .navigationTitle("Ecrin")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingComposer = true
                    } label: {
                        Label("Ajouter", systemImage: "plus")
                    }
                }
                ToolbarItem(placement: .secondaryAction) {
                    Button(selectedOnly ? "Tout afficher" : "Trier la sélection") {
                        selectedOnly.toggle()
                    }
                }
                ToolbarItem(placement: .secondaryAction) {
                    Button("Classer la sélection", systemImage: "sparkles") {
                        Task { await classifySelected() }
                    }
                    .disabled(isClassifying || !items.contains(where: \.isSelected))
                }
            }
            .sheet(isPresented: $showingComposer) {
                MemoryComposerView()
            }
            .task {
                await synchronizeReminders()
            }
            .onChange(of: reminderScheduleKey) {
                Task { await synchronizeReminders() }
            }
            .alert("Action impossible", isPresented: errorIsPresented) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "Une erreur inattendue est survenue.")
            }
        }
    }

    private var errorIsPresented: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }

    private var reminderScheduleKey: String {
        items.map {
            "\($0.reminderID.uuidString):\($0.reminderAt?.timeIntervalSince1970 ?? 0):\($0.title):\($0.summary):\($0.content)"
        }
        .sorted()
        .joined(separator: "|")
    }

    private func synchronizeReminders() async {
        for item in items {
            do {
                try await reminderScheduler.schedule(item)
            } catch {
                errorMessage = error.localizedDescription
                return
            }
        }
    }

    private func deleteItems(at offsets: IndexSet) {
        for index in offsets {
            let item = visibleItems[index]
            reminderScheduler.cancel(item)
            modelContext.delete(item)
        }
    }

    private func classifySelected() async {
        isClassifying = true
        defer { isClassifying = false }
        do {
            let service = AIService()
            let selectedItems = items.filter(\.isSelected)
            var results: [Classification] = []
            for item in selectedItems {
                let result = try await service.classify(item.content, serverAddress: aiServerAddress)
                results.append(result)
            }
            for (item, result) in zip(selectedItems, results) {
                item.category = result.category
                item.tags = result.tags
                item.summary = result.summary
                item.isSelected = false
            }
            try modelContext.save()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct MemoryRow: View {
    let item: MemoryItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(item.title)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                if item.isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.indigo)
                }
            }
            Text(item.summary.isEmpty ? item.content : item.summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            HStack {
                Text(item.category)
                if !item.tags.isEmpty {
                    Text("· \(item.tags.prefix(3).joined(separator: ", "))")
                }
                if !item.visualLabels.isEmpty {
                    Image(systemName: "viewfinder")
                    Text(item.visualLabels.prefix(2).joined(separator: ", "))
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

private struct MemoryDetailView: View {
    @Bindable var item: MemoryItem
    @AppStorage("aiServerAddress") private var aiServerAddress = ""
    @State private var isClassifying = false
    @State private var errorMessage: String?
    private let reminderScheduler = ReminderScheduler()

    var body: some View {
        Form {
            Section("Classement") {
                TextField("Titre", text: $item.title)
                LabeledContent("Catégorie", value: item.category)
                Toggle("Inclure dans le prochain tri", isOn: $item.isSelected)
                if !item.tags.isEmpty {
                    LabeledContent("Tags", value: item.tags.joined(separator: ", "))
                }
                if !item.visualLabels.isEmpty {
                    LabeledContent("Détection visuelle", value: item.visualLabels.joined(separator: ", "))
                }
                Button {
                    Task { await classify() }
                } label: {
                    if isClassifying {
                        ProgressView()
                    } else {
                        Label("Analyser avec l’IA", systemImage: "sparkles")
                    }
                }
                .disabled(isClassifying)
            }

            Section("Rappel") {
                Toggle("Activer un rappel", isOn: reminderEnabled)
                if item.reminderAt != nil {
                    DatePicker(
                        "Date et heure",
                        selection: reminderDate,
                        in: Date.now...
                    )
                }
            }

            Section("Contenu") {
                TextEditor(text: $item.content)
                    .frame(minHeight: 220)
            }

            if !item.summary.isEmpty {
                Section("Résumé") {
                    Text(item.summary)
                }
            }
        }
        .navigationTitle(item.title)
        .onChange(of: item.reminderAt) {
            Task { await updateReminder() }
        }
        .alert("Analyse impossible", isPresented: errorIsPresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Une erreur inattendue est survenue.")
        }
    }

    private var errorIsPresented: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }

    private var reminderEnabled: Binding<Bool> {
        Binding(
            get: { item.reminderAt != nil },
            set: { enabled in
                item.reminderAt = enabled ? Calendar.current.date(
                    byAdding: .hour,
                    value: 1,
                    to: .now
                ) : nil
            }
        )
    }

    private var reminderDate: Binding<Date> {
        Binding(
            get: { item.reminderAt ?? .now },
            set: { item.reminderAt = $0 }
        )
    }

    private func updateReminder() async {
        do {
            try await reminderScheduler.schedule(item)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func classify() async {
        isClassifying = true
        defer { isClassifying = false }
        do {
            let result = try await AIService().classify(item.content, serverAddress: aiServerAddress)
            item.category = result.category
            item.tags = result.tags
            item.summary = result.summary
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct MemoryComposerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @AppStorage("aiServerAddress") private var aiServerAddress = ""
    @State private var title = ""
    @State private var content = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isAnalyzingImage = false
    @State private var isGenerating = false
    @State private var generatedDocument: GeneratedDocument?
    @State private var visualLabels: [String] = []
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Nouvelle mémoire") {
                    TextField("Titre", text: $title)
                    TextEditor(text: $content)
                        .frame(minHeight: 180)
                }
                Section("Image") {
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        Label("Choisir une image à analyser", systemImage: "photo")
                    }
                    .onChange(of: selectedPhoto) {
                        Task { await analyzeSelectedPhoto() }
                    }
                    if isAnalyzingImage {
                        ProgressView("Analyse de l’image…")
                    }
                    if !visualLabels.isEmpty {
                        LabeledContent("Éléments détectés", value: visualLabels.joined(separator: ", "))
                    }
                }
                Section("Génération IA") {
                    Button {
                        Task { await generate(kind: .notice) }
                    } label: {
                        Label("Générer une notice", systemImage: "doc.text")
                    }
                    .disabled(isGenerating || content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    Button {
                        Task { await generate(kind: .guide) }
                    } label: {
                        Label("Générer un guide", systemImage: "list.number")
                    }
                    .disabled(isGenerating || content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    if isGenerating {
                        ProgressView("Rédaction en cours…")
                    }
                    if let generatedDocument {
                        LabeledContent("Type", value: generatedDocument.category)
                        Text(generatedDocument.content)
                            .font(.footnote)
                            .textSelection(.enabled)
                    }
                }
            }
            .navigationTitle("Ajouter une mémoire")
            .onChange(of: content) {
                if generatedDocument?.content != content {
                    generatedDocument = nil
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer", action: save)
                        .disabled(content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .alert("Analyse impossible", isPresented: errorIsPresented) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "Une erreur inattendue est survenue.")
            }
        }
    }

    private var errorIsPresented: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }

    private func analyzeSelectedPhoto() async {
        guard let selectedPhoto else { return }
        isAnalyzingImage = true
        defer { isAnalyzingImage = false }
        do {
            guard let data = try await selectedPhoto.loadTransferable(type: Data.self) else {
                throw CocoaError(.fileReadCorruptFile)
            }
            let analysis = try await ImageAnalyzer.analyze(data)
            visualLabels = analysis.labels
            if !analysis.recognizedText.isEmpty {
                content = [content, analysis.recognizedText]
                    .filter { !$0.isEmpty }
                    .joined(separator: "\n")
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func generate(kind: DocumentKind) async {
        let source = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !source.isEmpty else { return }
        isGenerating = true
        defer { isGenerating = false }
        do {
            let document = try await AIService().generate(
                source,
                kind: kind,
                serverAddress: aiServerAddress
            )
            generatedDocument = document
            title = document.title
            content = document.content
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func save() {
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let item = MemoryItem(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "Nouvelle mémoire"
                : title.trimmingCharacters(in: .whitespacesAndNewlines),
            content: trimmedContent
        )
        item.visualLabels = visualLabels
        if let generatedDocument, generatedDocument.content == trimmedContent {
            item.summary = generatedDocument.summary
            item.category = generatedDocument.category
            item.tags = generatedDocument.tags
        }
        modelContext.insert(item)
        do {
            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct SettingsView: View {
    @AppStorage("aiServerAddress") private var aiServerAddress = ""
    @State private var backendName: String?
    @State private var errorMessage: String?
    @State private var isChecking = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Serveur IA") {
                    TextField("https://votre-serveur.example", text: $aiServerAddress)
#if os(iOS)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
#endif
                    Button {
                        Task { await checkConnection() }
                    } label: {
                        if isChecking {
                            ProgressView()
                        } else {
                            Label("Tester la connexion", systemImage: "network")
                        }
                    }
                    .disabled(isChecking)
                    if let backendName {
                        LabeledContent("Moteur actif", value: backendName)
                    }
                    Text("Les clés OpenAI ou Ollama restent sur le serveur et ne sont pas stockées dans l’app.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Synchronisation") {
                    Label("CloudKit privé", systemImage: "icloud")
                    Text("Les mémoires se synchronisent entre vos appareils connectés au même compte Apple.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Analyse visuelle") {
                    Label("Traitement sur l’appareil", systemImage: "viewfinder")
                    Text("Le texte et les éléments visibles sont détectés sur l’appareil; l’image n’est pas envoyée au serveur IA.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Réglages IA")
            .alert("Connexion impossible", isPresented: errorIsPresented) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "Une erreur inattendue est survenue.")
            }
        }
    }

    private var errorIsPresented: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }

    private func checkConnection() async {
        isChecking = true
        backendName = nil
        defer { isChecking = false }
        do {
            let health = try await AIService().health(serverAddress: aiServerAddress)
            backendName = health.ai_backend
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
