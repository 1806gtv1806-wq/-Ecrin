import SwiftUI

struct AIWorkshopView: View {
    @AppStorage("ai.agentProfiles") private var encodedProfiles = ""
    @AppStorage("aiServerAddress") private var aiServerAddress = ""
    @State private var showingNewAgent = false
    @State private var editingAgent: AIAgentProfile?
    @State private var providerConfiguration: AIProviderConfiguration?
    @State private var providerError: String?
    @State private var profileError: String?

    private var profiles: [AIAgentProfile] {
        do {
            return try AIAgentProfile.load(from: encodedProfiles)
        } catch {
            return AIAgentProfile.builtIns
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("ATELIER INTELLIGENT")
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(1.8)
                            .foregroundStyle(Color(red: 0.29, green: 0.43, blue: 0.35))
                        Text("Un esprit, plusieurs expertises.")
                            .font(.system(size: 27, weight: .light, design: .serif))
                        Text("Choisissez un agent, adaptez ses consignes et son accès à votre mémoire.")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 10) {
                        Label {
                            if let providerConfiguration {
                                Text("Serveur : \(providerConfiguration.provider) · \(providerConfiguration.model ?? "aucun modèle")")
                            } else if let providerError {
                                Text(providerError)
                            } else {
                                Text("Lecture de la configuration IA…")
                            }
                        } icon: {
                            Image(systemName: providerConfiguration?.conversation == true ? "network" : "network.slash")
                        }
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                        Spacer(minLength: 4)
                        Label(
                            AppleIntelligenceService.isSupportedByOperatingSystem ? "Apple IA disponible" : "Apple IA selon l’appareil",
                            systemImage: "apple.intelligence"
                        )
                    }
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(13)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))

                    LazyVStack(spacing: 10) {
                        ForEach(profiles) { profile in
                            agentCard(profile)
                        }
                    }

                    NavigationLink {
                        SettingsView()
                    } label: {
                        Label("Configurer le serveur IA", systemImage: "slider.horizontal.3")
                            .font(.system(size: 12, weight: .medium))
                    }

                    Button {
                        showingNewAgent = true
                    } label: {
                        Label("Créer un agent personnalisé", systemImage: "plus")
                            .font(.system(size: 13, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(Color(red: 0.2, green: 0.36, blue: 0.27), in: Capsule())
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)

                    Text("Les identifiants fournisseur restent sur le serveur. Les agents personnalisés ne reçoivent pas d’outils d’exécution.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let profileError {
                        Label(profileError, systemImage: "exclamationmark.triangle")
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
                .frame(maxWidth: 720, alignment: .leading)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 18)
                .padding(.vertical, 24)
            }
            .scrollIndicators(.hidden)
            .background {
                LinearGradient(
                    colors: [Color(red: 0.93, green: 0.95, blue: 0.92), Color(red: 0.86, green: 0.91, blue: 0.88)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            }
            .navigationTitle("Atelier IA")
            .task {
                do {
                    _ = try AIAgentProfile.load(from: encodedProfiles)
                } catch {
                    profileError = error.localizedDescription
                }
                await loadProviderConfiguration()
            }
            .sheet(isPresented: $showingNewAgent) {
                AgentProfileEditor(profile: nil) { profile in
                    save(profile)
                }
            }
            .sheet(item: $editingAgent) { profile in
                AgentProfileEditor(profile: profile) { updated in
                    save(updated)
                }
            }
        }
    }

    private func agentCard(_ profile: AIAgentProfile) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            NavigationLink {
                EinsteinView(profile: profile)
            } label: {
                HStack(spacing: 14) {
                    agentIcon(profile.id == "einstein" ? "sparkles" : "brain")
                    VStack(alignment: .leading, spacing: 4) {
                        Text(profile.name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.primary)
                        Text(profile.summary)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer(minLength: 4)
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            if profile.id == "developer" {
                NavigationLink {
                    DeveloperProjectView()
                } label: {
                    Label("Créer une application", systemImage: "hammer")
                        .font(.system(size: 11, weight: .semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 6) {
                Label(profile.executionPreference == .server ? AIService.serverConfigurationLabel : "Apple Intelligence", systemImage: profile.executionPreference == .server ? "network" : "apple.intelligence")
                if profile.canUseMemory {
                    Label("Mémoire autorisée", systemImage: "square.stack.3d.up")
                }
            }
            .font(.system(size: 9, weight: .medium))
            .foregroundStyle(.secondary)

            if !Self.isBuiltIn(profile) {
                Button {
                    editingAgent = profile
                } label: {
                    Label("Configurer cet agent", systemImage: "slider.horizontal.3")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.white.opacity(0.78), lineWidth: 1)
        }
    }

    private func agentIcon(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 18, weight: .light))
            .foregroundStyle(Color(red: 0.29, green: 0.43, blue: 0.35))
            .frame(width: 42, height: 42)
            .background(.white.opacity(0.56), in: RoundedRectangle(cornerRadius: 14))
    }

    private func save(_ profile: AIAgentProfile) {
        var updated = profiles
        if let index = updated.firstIndex(where: { $0.id == profile.id }) {
            updated[index] = profile
        } else {
            updated.append(profile)
        }
        do {
            encodedProfiles = try AIAgentProfile.encode(updated)
            profileError = nil
        } catch {
            profileError = error.localizedDescription
        }
    }

    private func loadProviderConfiguration() async {
        do {
            providerConfiguration = try await AIService().configuration(serverAddress: aiServerAddress)
            providerError = nil
        } catch {
            providerConfiguration = nil
            providerError = error.localizedDescription
        }
    }

    private static func isBuiltIn(_ profile: AIAgentProfile) -> Bool {
        AIAgentProfile.builtIns.contains { $0.id == profile.id }
    }
}

private struct AgentProfileEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var summary: String
    @State private var instructions: String
    @State private var executionPreference: AIExecutionPreference
    @State private var canUseMemory: Bool
    let onSave: (AIAgentProfile) -> Void

    private let existingID: String?

    init(profile: AIAgentProfile?, onSave: @escaping (AIAgentProfile) -> Void) {
        _name = State(initialValue: profile?.name ?? "")
        _summary = State(initialValue: profile?.summary ?? "")
        _instructions = State(initialValue: profile?.instructions ?? "")
        _executionPreference = State(initialValue: profile?.executionPreference ?? .server)
        _canUseMemory = State(initialValue: profile?.canUseMemory ?? false)
        existingID = profile?.id
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Identité") {
                    TextField("Nom de l’agent", text: $name)
                    TextField("Rôle résumé", text: $summary, axis: .vertical)
                        .lineLimit(2...4)
                }
                Section("Consignes") {
                    TextEditor(text: $instructions)
                        .frame(minHeight: 140)
                    if instructions.count > 4000 {
                        Text("Les consignes ne peuvent pas dépasser 4 000 caractères.")
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                    Text("Ces consignes guident la conversation; elles ne donnent pas accès à des outils d’exécution.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Section("Exécution") {
                    Picker("Modèle", selection: $executionPreference) {
                        Text("Serveur configuré").tag(AIExecutionPreference.server)
                        if AppleIntelligenceService.isSupportedByOperatingSystem {
                            Text("Apple Intelligence").tag(AIExecutionPreference.appleOnDevice)
                        }
                    }
                    Toggle("Autoriser l’accès à MemoryOS", isOn: $canUseMemory)
                }
            }
            .navigationTitle(existingID == nil ? "Nouvel agent" : "Configurer l’agent")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") {
                        let profile = AIAgentProfile(
                            id: existingID ?? "agent-\(UUID().uuidString.lowercased())",
                            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                            summary: summary.trimmingCharacters(in: .whitespacesAndNewlines),
                            instructions: instructions.trimmingCharacters(in: .whitespacesAndNewlines),
                            executionPreference: executionPreference,
                            canUseMemory: canUseMemory,
                            availableActions: []
                        )
                        onSave(profile)
                        dismiss()
                    }
                    .disabled(
                        name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            || instructions.count > 4000
                    )
                }
            }
        }
    }
}
