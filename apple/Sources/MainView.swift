import PhotosUI
import PDFKit
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct MainView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var router = AppRouter()
    @AppStorage("openEinsteinFromIntent") private var openEinsteinFromIntent = false
    @AppStorage("openNOVAFromIntent") private var openNOVAFromIntent = false

    var body: some View {
        ZStack {
            MasterBackground()

            Group {
                switch router.destination {
                case .home:
                    MasterHomeView { router.navigate(to: $0) }
                case .atelier:
                    AIWorkshopView()
                case .memoryOS:
                    MemoryListView()
                case .einstein:
                    EinsteinView()
                case .nova:
                    NOVAView()
                case .search:
                    MemorySearchView()
                case .settings:
                    SettingsView()
                case .organic:
                    OrganicView()
                case .fusion:
                    FusionView()
                case .verso:
                    VersoView()
                }
            }
            .frame(maxWidth: 1120, maxHeight: .infinity)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transition(.opacity)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            MasterDock(router: router)
                .padding(.horizontal, 18)
                .padding(.bottom, 8)
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: router.destination)
        .preferredColorScheme(.light)
        .onAppear(perform: handleAppIntents)
        .onChange(of: openEinsteinFromIntent) {
            handleAppIntents()
        }
        .onChange(of: openNOVAFromIntent) {
            handleAppIntents()
        }
    }

    private func handleAppIntents() {
        if openEinsteinFromIntent {
            router.navigate(to: .einstein)
            openEinsteinFromIntent = false
        } else if openNOVAFromIntent {
            router.navigate(to: .nova)
            openNOVAFromIntent = false
        }
    }
}

private struct MasterBackground: View {
    var body: some View {
        ZStack {
            Color(red: 0.91, green: 0.94, blue: 0.92)
            RadialGradient(
                colors: [
                    Color.white.opacity(0.95),
                    Color(red: 0.85, green: 0.9, blue: 0.86).opacity(0.2),
                    .clear
                ],
                center: .init(x: 0.5, y: 0.3),
                startRadius: 10,
                endRadius: 520
            )
            LinearGradient(
                colors: [.white.opacity(0.38), .clear, Color(red: 0.75, green: 0.83, blue: 0.78).opacity(0.18)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .ignoresSafeArea()
    }
}

private struct MasterHomeView: View {
    let open: (EcrinDestination) -> Void

    var body: some View {
        GeometryReader { geometry in
            let isCompact = geometry.size.height < 620
            VStack(spacing: isCompact ? 14 : 22) {
                VStack(spacing: 8) {
                    Text("L’ATELIER VIVANT")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .tracking(2.2)
                        .foregroundStyle(.secondary)
                    Text("Tout prend place ici.")
                        .font(.system(size: isCompact ? 27 : 32, weight: .light, design: .serif))
                        .tracking(-0.7)
                        .foregroundStyle(Color(red: 0.14, green: 0.22, blue: 0.18))
                    Text("Vos idées, vos documents, votre espace de création.")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, isCompact ? 12 : 30)

                MasterCubeView(open: open)
                    .frame(width: min(geometry.size.width - 40, 350), height: isCompact ? 220 : 264)
                    .padding(.vertical, 4)

                EinsteinStatusCard()
                    .frame(maxWidth: 540)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 20)
        }
    }
}

private struct MasterCubeView: View {
    let open: (EcrinDestination) -> Void

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [.white.opacity(0.75), .white.opacity(0.08), .clear],
                        center: .center,
                        startRadius: 12,
                        endRadius: 160
                    )
                )
                .frame(width: 300, height: 250)

            ZStack {
                CubeFaceShape(face: .top)
                    .fill(.ultraThinMaterial)
                    .overlay(CubeFaceShape(face: .top).fill(Color.white.opacity(0.33)))
                    .overlay(CubeFaceShape(face: .top).stroke(.white.opacity(0.86), lineWidth: 1.2))
                CubeFaceShape(face: .left)
                    .fill(.ultraThinMaterial)
                    .overlay(CubeFaceShape(face: .left).fill(Color(red: 0.77, green: 0.87, blue: 0.8).opacity(0.45)))
                    .overlay(CubeFaceShape(face: .left).stroke(.white.opacity(0.78), lineWidth: 1.2))
                CubeFaceShape(face: .right)
                    .fill(.ultraThinMaterial)
                    .overlay(CubeFaceShape(face: .right).fill(Color(red: 0.82, green: 0.85, blue: 0.93).opacity(0.42)))
                    .overlay(CubeFaceShape(face: .right).stroke(.white.opacity(0.78), lineWidth: 1.2))

                cubeFaceButton(.memoryOS, position: CGPoint(x: 64, y: 148))
                cubeFaceButton(.organic, position: CGPoint(x: 125, y: 69))
                cubeFaceButton(.fusion, position: CGPoint(x: 186, y: 148))
            }
            .frame(width: 250, height: 220)
            .shadow(color: Color(red: 0.2, green: 0.31, blue: 0.25).opacity(0.17), radius: 22, x: 0, y: 16)
            .rotation3DEffect(.degrees(4), axis: (x: 1, y: 0, z: 0), perspective: 0.35)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Cube ÉCRIN. Choisissez un univers.")
    }

    private func cubeFaceButton(_ destination: EcrinDestination, position: CGPoint) -> some View {
        Button {
            open(destination)
        } label: {
            VStack(spacing: 4) {
                Image(systemName: destination.symbol)
                    .font(.system(size: 18, weight: .light))
                Text(destination.title)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(Color(red: 0.2, green: 0.31, blue: 0.25))
            .frame(width: 88, height: 54)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Ouvrir \(destination.title)")
        .position(position)
    }
}

private struct CubeFaceShape: Shape {
    enum Face {
        case top
        case left
        case right
    }

    let face: Face

    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        let points: [CGPoint]
        switch face {
        case .top:
            points = [
                CGPoint(x: w * 0.5, y: 0),
                CGPoint(x: w, y: h * 0.25),
                CGPoint(x: w * 0.5, y: h * 0.5),
                CGPoint(x: 0, y: h * 0.25)
            ]
        case .left:
            points = [
                CGPoint(x: 0, y: h * 0.25),
                CGPoint(x: w * 0.5, y: h * 0.5),
                CGPoint(x: w * 0.5, y: h),
                CGPoint(x: 0, y: h * 0.75)
            ]
        case .right:
            points = [
                CGPoint(x: w * 0.5, y: h * 0.5),
                CGPoint(x: w, y: h * 0.25),
                CGPoint(x: w, y: h * 0.75),
                CGPoint(x: w * 0.5, y: h)
            ]
        }

        var path = Path()
        path.addLines(points)
        path.closeSubpath()
        return path
    }
}

private struct EinsteinStatusCard: View {
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "sparkles")
                .font(.system(size: 19, weight: .light))
                .foregroundStyle(Color(red: 0.29, green: 0.43, blue: 0.35))
                .frame(width: 42, height: 42)
                .background(.white.opacity(0.52), in: RoundedRectangle(cornerRadius: 14))
            VStack(alignment: .leading, spacing: 4) {
                Text("Einstein")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                Text("Assistant transversal · connexion vocale à venir")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Circle()
                .fill(Color.secondary.opacity(0.35))
                .frame(width: 7, height: 7)
                .accessibilityLabel("Inactif")
        }
        .padding(15)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(.white.opacity(0.72), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.045), radius: 16, x: 0, y: 8)
        .accessibilityElement(children: .combine)
    }
}

private struct MasterDock: View {
    @ObservedObject var router: AppRouter

    private let destinations: [EcrinDestination] = [
        .memoryOS, .nova, .organic, .fusion, .verso
    ]

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 5) {
                ForEach(destinations) { destination in
                    dockButton(destination)
                }
                Rectangle()
                    .fill(.white.opacity(0.46))
                    .frame(width: 1, height: 30)
                    .padding(.horizontal, 5)
                    dockControl(.atelier, label: "Atelier IA")
                    dockControl(.einstein, label: "Einstein")
                dockControl(.search, label: "Recherche")
                dockControl(.settings, label: "Réglages")
                Button {
                    router.recenter()
                } label: {
                    Image(systemName: "scope")
                        .font(.system(size: 16, weight: .medium))
                        .frame(width: 42, height: 48)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.primary.opacity(0.72))
                .accessibilityLabel("Recentrer le cube")
                .help("Recentrer le cube")
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
        }
        .scrollIndicators(.hidden)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay {
            Capsule()
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.95), .white.opacity(0.32), .white.opacity(0.72)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
        .shadow(color: Color(red: 0.16, green: 0.25, blue: 0.19).opacity(0.12), radius: 22, x: 0, y: 9)
        .frame(maxWidth: 760)
        .frame(maxWidth: .infinity)
    }

    private func dockButton(_ destination: EcrinDestination) -> some View {
        let isSelected = router.destination == destination
        return Button {
            router.navigate(to: destination)
        } label: {
            VStack(spacing: 4) {
                Image(systemName: destination.symbol)
                    .font(.system(size: 16, weight: isSelected ? .semibold : .regular))
                Text(destination.title)
                    .font(.system(size: 9, weight: isSelected ? .semibold : .medium))
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? Color(red: 0.19, green: 0.34, blue: 0.25) : Color.secondary)
            .frame(minWidth: 48, minHeight: 48)
            .padding(.horizontal, 3)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(.white.opacity(0.56))
                        .overlay {
                            RoundedRectangle(cornerRadius: 15, style: .continuous)
                                .stroke(.white.opacity(0.78), lineWidth: 0.8)
                        }
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(destination.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func dockControl(_ destination: EcrinDestination, label: String) -> some View {
        Button {
            router.navigate(to: destination)
        } label: {
            Image(systemName: destination.symbol)
                .font(.system(size: 16, weight: .medium))
                .frame(width: 42, height: 48)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(router.destination == destination ? Color.primary : Color.primary.opacity(0.72))
        .accessibilityLabel(label)
        .help(label)
    }
}

private struct MemoryListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MemoryItem.createdAt, order: .reverse) private var items: [MemoryItem]
    @State private var showingComposer = false
    @State private var selectedOnly = false
    @State private var isClassifying = false
    @State private var searchText = ""
    @State private var errorMessage: String?
    @AppStorage("aiServerAddress") private var aiServerAddress = ""
    private let reminderScheduler = ReminderScheduler()

    private var visibleItems: [MemoryItem] {
        let selection = selectedOnly ? items.filter(\.isSelected) : items
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return selection }
        return selection.filter { item in
            [item.title, item.content, item.summary, item.category]
                .joined(separator: " ")
                .localizedCaseInsensitiveContains(query)
                || item.tags.contains { $0.localizedCaseInsensitiveContains(query) }
                || item.visualLabels.contains { $0.localizedCaseInsensitiveContains(query) }
        }
    }

    var body: some View {
        NavigationSplitView {
            List {
                if visibleItems.isEmpty {
                    ContentUnavailableView(
                        searchText.isEmpty
                            ? (selectedOnly ? "Aucune note sélectionnée" : "Votre mémoire est vide")
                            : "Aucun résultat",
                        systemImage: searchText.isEmpty ? "tray" : "magnifyingglass",
                        description: Text(searchText.isEmpty
                            ? (selectedOnly
                                ? "Sélectionnez des notes pour les classer ensemble."
                                : "Ajoutez une idée, un texte ou une image pour commencer.")
                            : "Essayez un autre mot-clé ou une catégorie.")
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
            .searchable(text: $searchText, prompt: "Rechercher dans la mémoire")
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
        } detail: {
            ContentUnavailableView(
                "Votre MemoryOS",
                systemImage: "square.stack.3d.up",
                description: Text("Choisissez une mémoire pour la consulter ou en créer une nouvelle.")
            )
        }
        .navigationSplitViewStyle(.balanced)
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

struct MemoryRow: View {
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

private struct MemorySearchView: View {
    @Query(sort: \MemoryItem.createdAt, order: .reverse) private var items: [MemoryItem]
    @State private var query = ""

    private var results: [MemoryItem] {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return [] }
        return items.filter { item in
            [item.title, item.content, item.summary, item.category]
                .joined(separator: " ")
                .localizedCaseInsensitiveContains(term)
                || item.tags.contains { $0.localizedCaseInsensitiveContains(term) }
                || item.visualLabels.contains { $0.localizedCaseInsensitiveContains(term) }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    ContentUnavailableView(
                        "Rechercher dans ÉCRIN",
                        systemImage: "magnifyingglass",
                        description: Text("Recherchez dans les titres, le contenu, les catégories et les tags de MemoryOS.")
                    )
                } else if results.isEmpty {
                    ContentUnavailableView.search(text: query)
                } else {
                    ForEach(results) { item in
                        NavigationLink {
                            MemoryDetailView(item: item)
                        } label: {
                            MemoryRow(item: item)
                        }
                    }
                }
            }
            .searchable(text: $query, prompt: "Mots-clés, catégories, tags")
            .navigationTitle("Recherche")
        }
    }
}

struct MemoryDetailView: View {
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
    @Query private var items: [MemoryItem]
    @AppStorage("aiServerAddress") private var aiServerAddress = ""
    @State private var title = ""
    @State private var content = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showingFileImporter = false
    @State private var fileImportTask: Task<Void, Never>?
    @State private var isAnalyzingImage = false
    @State private var isClassifying = false
    @State private var isGenerating = false
    @State private var generatedDocument: GeneratedDocument?
    @State private var suggestedClassification: Classification?
    @State private var appliesSuggestedClassification = false
    @State private var visualLabels: [String] = []
    @State private var errorMessage: String?

    private var duplicateTitle: String? {
        let draft = normalized(content)
        guard !draft.isEmpty else { return nil }
        return items.first(where: { normalized($0.content) == draft })?.title
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Nouvelle mémoire") {
                    TextField("Titre", text: $title)
                    TextEditor(text: $content)
                        .frame(minHeight: 180)
                }
                Section("Importer") {
                    Button {
                        showingFileImporter = true
                    } label: {
                        Label("Importer un PDF, une image ou un texte", systemImage: "doc.badge.plus")
                    }
                    .disabled(isAnalyzingImage)

                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        Label("Importer une image et lancer l’OCR", systemImage: "photo")
                    }
                    .disabled(isAnalyzingImage)
                    .onChange(of: selectedPhoto) {
                        fileImportTask?.cancel()
                        fileImportTask = Task { await analyzeSelectedPhoto() }
                    }
                    if isAnalyzingImage {
                        ProgressView("Lecture et OCR du document…")
                    }
                    if !visualLabels.isEmpty {
                        LabeledContent("Éléments détectés", value: visualLabels.joined(separator: ", "))
                    }
                }
                .fileImporter(
                    isPresented: $showingFileImporter,
                    allowedContentTypes: [.pdf, .image, .plainText],
                    allowsMultipleSelection: false,
                    onCompletion: importFile
                )
                if let duplicateTitle {
                    Section("Doublon possible") {
                        Label("Un contenu identique existe déjà : \(duplicateTitle)", systemImage: "doc.on.doc")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                        Text("Votre brouillon n’est pas enregistré automatiquement. Vérifiez le contenu avant de continuer.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                Section("Classement proposé") {
                    Button {
                        Task { await suggestClassification() }
                    } label: {
                        if isClassifying {
                            ProgressView("Analyse du classement…")
                        } else {
                            Label("Proposer un classement", systemImage: "sparkles")
                        }
                    }
                    .disabled(isClassifying || content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    if let suggestedClassification {
                        LabeledContent("Catégorie", value: suggestedClassification.category)
                        Text(suggestedClassification.summary)
                            .font(.footnote)
                        if !suggestedClassification.tags.isEmpty {
                            LabeledContent("Mots-clés", value: suggestedClassification.tags.joined(separator: ", "))
                        }
                        Text("Proposition IA à vérifier avant application.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button {
                            appliesSuggestedClassification = true
                        } label: {
                            Label(
                                appliesSuggestedClassification ? "Classement accepté" : "Appliquer au brouillon",
                                systemImage: appliesSuggestedClassification ? "checkmark.circle.fill" : "checkmark"
                            )
                        }
                        .disabled(appliesSuggestedClassification)
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
                suggestedClassification = nil
                appliesSuggestedClassification = false
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer", action: save)
                        .disabled(content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isAnalyzingImage)
                }
            }
            .onDisappear { fileImportTask?.cancel() }
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
            let analysis = try await DocumentTextExtractor.extract(data, filename: "photo.jpg")
            try Task.checkCancellation()
            visualLabels = analysis.labels
            if !analysis.text.isEmpty {
                content = [content, analysis.text]
                    .filter { !$0.isEmpty }
                    .joined(separator: "\n")
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func importFile(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            fileImportTask?.cancel()
            isAnalyzingImage = true
            fileImportTask = Task { @MainActor in
                do {
                    let extracted = try await DocumentTextExtractor.read(url)
                    try Task.checkCancellation()
                    content = [content, extracted.text].filter { !$0.isEmpty }.joined(separator: "\n\n")
                    visualLabels = Array(Set(visualLabels + extracted.labels)).sorted()
                    if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        title = url.deletingPathExtension().lastPathComponent
                    }
                    isAnalyzingImage = false
                } catch is CancellationError { }
                catch { if !Task.isCancelled { errorMessage = error.localizedDescription; isAnalyzingImage = false } }
            }
        } catch { errorMessage = error.localizedDescription }
    }

    private func suggestClassification() async {
        let source = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !source.isEmpty else { return }
        isClassifying = true
        defer { isClassifying = false }
        do {
            suggestedClassification = try await AIService().classify(
                source,
                serverAddress: aiServerAddress
            )
            appliesSuggestedClassification = false
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
        if appliesSuggestedClassification, let suggestedClassification {
            item.summary = suggestedClassification.summary
            item.category = suggestedClassification.category
            item.tags = suggestedClassification.tags
        }
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
            modelContext.delete(item)
            errorMessage = error.localizedDescription
        }
    }

    private func normalized(_ value: String) -> String {
        value
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }


}

struct SettingsView: View {
    @AppStorage("aiServerAddress") private var aiServerAddress = ""
    @State private var backendName: String?
    @State private var errorMessage: String?
    @State private var isChecking = false
    @State private var apiAccessToken = ""
    @State private var tokenSaved = false

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

                Section("Accès sécurisé à l’Atelier IA") {
                    SecureField("Jeton d’accès ÉCRIN", text: $apiAccessToken)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button {
                        do {
                            try SecureStore.saveAPIAccessToken(
                                apiAccessToken.trimmingCharacters(in: .whitespacesAndNewlines)
                            )
                            tokenSaved = true
                            errorMessage = nil
                        } catch {
                            errorMessage = error.localizedDescription
                        }
                    } label: {
                        Label(tokenSaved ? "Jeton enregistré dans le trousseau" : "Enregistrer le jeton sécurisé", systemImage: tokenSaved ? "checkmark.shield" : "lock.shield")
                    }
                    .disabled(apiAccessToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Text("Saisissez le même jeton que ECRIN_API_TOKEN configuré sur votre serveur. Il est stocké dans le trousseau Apple, pas dans les préférences.")
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
            .task {
                do {
                    apiAccessToken = try SecureStore.readAPIAccessToken() ?? ""
                    tokenSaved = !apiAccessToken.isEmpty
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
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

