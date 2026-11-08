import SwiftUI

struct DeveloperProjectView: View {
    @AppStorage("aiServerAddress") private var aiServerAddress = ""
    @State private var apiAccessToken = ""
    @State private var description = ""
    @State private var stack = ProjectStack.swiftui
    @State private var archiveURL: URL?
    @State private var isGenerating = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section {
                Text("Décrivez l’application à créer. L’agent prépare des fichiers source dans une archive; il n’exécute pas le code généré.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Projet") {
                Picker("Technologie", selection: $stack) {
                    ForEach(ProjectStack.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                TextField("Nom ou idée de l’application", text: $description, axis: .vertical)
                    .lineLimit(4...9)
            }

            Section("Validation et export") {
                Button {
                    Task { await generate() }
                } label: {
                    if isGenerating {
                        ProgressView("Préparation du projet…")
                    } else {
                        Label("Générer une archive", systemImage: "hammer")
                    }
                }
                .disabled(isGenerating || description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if let archiveURL {
                    ShareLink(item: archiveURL) {
                        Label("Exporter le projet ZIP", systemImage: "square.and.arrow.up")
                    }
                    Text("Vérifiez les fichiers de l’archive avant de les ouvrir ou de les compiler. Le code n’a pas été exécuté.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Créer une application")
        .task {
            do {
                apiAccessToken = try SecureStore.readAPIAccessToken() ?? ""
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func generate() async {
        let projectDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !projectDescription.isEmpty else { return }
        errorMessage = nil
        archiveURL = nil
        isGenerating = true
        defer { isGenerating = false }
        do {
            archiveURL = try await AIService().generateProjectArchive(
                description: projectDescription,
                stack: stack.rawValue,
                apiToken: apiAccessToken,
                serverAddress: aiServerAddress
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private enum ProjectStack: String, CaseIterable, Identifiable {
    case swiftui
    case web

    var id: String { rawValue }
    var title: String {
        switch self {
        case .swiftui: return "Application SwiftUI"
        case .web: return "Application Web"
        }
    }
}
