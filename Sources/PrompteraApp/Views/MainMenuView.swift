import SwiftUI
import PrompteraKit

private extension DateFormatter {
    static let iso8601: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        return formatter
    }()
}

public enum PrompteraTab: String, CaseIterable, Identifiable {
    case generator = "Gerador"
    case clipboard = "Clipboard"
    case library = "Biblioteca"
    case settings = "Configurações"
    
    public var id: String { rawValue }
    
    public var displayName: String {
        switch self {
        case .generator: return L10n.t("Gerador")
        case .clipboard: return L10n.t("Clipboard")
        case .library: return L10n.t("Biblioteca")
        case .settings: return L10n.t("Configurações")
        }
    }
    
    public var icon: String {
        switch self {
        case .generator: return "wand.and.stars"
        case .clipboard: return "doc.on.clipboard"
        case .library: return "books.vertical"
        case .settings: return "gearshape"
        }
    }
}

public struct MainMenuView: View {
    @ObservedObject var state: PrompteraState
    @AppStorage("promptera_selected_tab") private var selectedTab: PrompteraTab = .generator
    @Namespace private var animationNamespace
    
    private let tabAnimation = Animation.spring(response: 0.25, dampingFraction: 0.85)
    
    public init(state: PrompteraState) {
        self.state = state
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // App Header
            HStack {
                HStack(spacing: 8) {
                    PrompteraLogo(size: 24)
                    Text("Promptera")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(PrompteraColors.textPrimary)
                }
                
                Spacer()
                
                // Segmented Tab Picker with animation
                HStack(spacing: 4) {
                    ForEach(PrompteraTab.allCases) { tab in
                        Button {
                            withAnimation(tabAnimation) {
                                selectedTab = tab
                            }
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: tab.icon)
                                    .font(.system(size: 16, weight: .medium))
                                Text(tab.displayName)
                                    .font(.caption2)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(selectedTab == tab ? PrompteraColors.textOnBrand : PrompteraColors.textSecondary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                ZStack {
                                    if selectedTab == tab {
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(PrompteraColors.brandGradient)
                                            .matchedGeometryEffect(id: "tabSelector", in: animationNamespace)
                                            .shadow(color: PrompteraColors.shadowBrand, radius: 4, x: 0, y: 2)
                                    }
                                }
                            )
                        }
                        .buttonStyle(.plain)
                        .help(tab.displayName)
                        .accessibilityLabel(tab.displayName)
                        .accessibilityHint(L10n.t("Abre a aba %@", tab.displayName))
                        .accessibilityAddTraits(selectedTab == tab ? .isSelected : [])
                    }
                }
                .padding(4)
                .background(PrompteraColors.surfaceSecondary)
                .cornerRadius(12)
                .frame(width: 360)
                
                Spacer()
                
                // Quit App button
                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Image(systemName: "power")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(PrompteraColors.textSecondary)
                        .frame(width: 32, height: 32)
                        .background(PrompteraColors.surfaceSecondary)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .help(L10n.t("Encerrar Promptera"))
                .accessibilityLabel(L10n.t("Encerrar Promptera"))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                LinearGradient(
                    colors: [
                        PrompteraColors.surfacePrimary,
                        PrompteraColors.surfacePrimary.opacity(0.9)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(alignment: .bottom) {
                Divider()
                    .background(PrompteraColors.borderSubtle)
            }
            
            // Tab Contents with transition
            Group {
                if !state.hasCompletedGemmaSetup() {
                    // Assistente de primeira execução: instala Ollama e baixa o Gemma.
                    OllamaSetupWizardView(state: state)
                } else {
                    switch selectedTab {
                    case .generator:
                        PromptGeneratorView(state: state)
                    case .clipboard:
                        ClipboardHistoryView(clipboardManager: state.clipboardManager, state: state)
                    case .library:
                        PromptLibraryView(state: state)
                    case .settings:
                        SettingsView(state: state)
                    }
                }
            }
            .transition(.opacity.combined(with: .offset(y: 6)))
            .animation(tabAnimation, value: selectedTab)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 600, height: 640)
        .background(PrompteraColors.surfacePrimary)
        .tint(PrompteraColors.brandPrimary)
        .task { await state.refreshModelsIfNeeded() }
        // Fires every time the menu bar popover opens.
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
            Task { await state.refreshModelsIfNeeded() }
        }
    }
}

struct SettingsView: View {
    @ObservedObject var state: PrompteraState
    @State private var ollamaUrlText: String = "http://127.0.0.1:11434"
    @State private var urlError: String?
    @State private var languageStore = LanguageStore.shared
    private let themeStore = ThemeStore.shared
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.t("Configurações"))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(PrompteraColors.textPrimary)
                    Text(L10n.t("Gerencie preferências do Promptera e conexão com Ollama"))
                        .font(.subheadline)
                        .foregroundStyle(PrompteraColors.textSecondary)
                }
                
                // Appearance Section
                SettingsSection(title: L10n.t("Aparência"), icon: "paintpalette") {
                    VStack(alignment: .leading, spacing: 14) {
                        Picker(L10n.t("Modo"), selection: Binding(
                            get: { themeStore.appearance },
                            set: { newValue in
                                themeStore.appearance = newValue
                                themeStore.applyAppearance()
                            }
                        )) {
                            ForEach(PrompteraAppearance.allCases) { appearance in
                                Label(appearance.displayName, systemImage: appearance.icon)
                                    .tag(appearance)
                            }
                        }
                        .pickerStyle(.segmented)
                        
                        Picker(L10n.t("Idioma"), selection: Binding(
                            get: { languageStore.language },
                            set: { languageStore.language = $0 }
                        )) {
                            ForEach(AppLanguage.allCases) { language in
                                Text(language.displayName).tag(language)
                            }
                        }
                        .pickerStyle(.menu)
                        .accessibilityHint(L10n.t("Muda o idioma da interface imediatamente."))
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L10n.t("Tema de Cores"))
                                .font(.caption.weight(.medium))
                                .foregroundStyle(PrompteraColors.textSecondary)
                            
                            HStack(spacing: 10) {
                                ForEach(PrompteraTheme.allCases) { theme in
                                    ThemeSwatch(theme: theme, isSelected: themeStore.theme == theme) {
                                        withAnimation(.easeInOut(duration: 0.25)) {
                                            themeStore.theme = theme
                                        }
                                    }
                                }
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L10n.t("Cor de Destaque"))
                                .font(.caption.weight(.medium))
                                .foregroundStyle(PrompteraColors.textSecondary)
                            
                            HStack(spacing: 10) {
                                ForEach(accentOptions) { option in
                                    AccentSwatch(
                                        color: option.hex.map { Color(hex: UInt32($0, radix: 16) ?? 0) } ?? themeStore.theme.accent,
                                        name: option.name,
                                        isSelected: themeStore.accentHex == option.hex
                                    ) {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            themeStore.accentHex = option.hex
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                
                // Hardware Section
                SettingsSection(title: L10n.t("Hardware & Aceleração"), icon: "apple.logo") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            Image(systemName: "cpu.fill")
                                .font(.title2)
                                .foregroundStyle(PrompteraColors.brandGradient)
                                .frame(width: 40, height: 40)
                                .background(PrompteraColors.surfaceSecondary)
                                .cornerRadius(10)
                                .accessibilityHidden(true)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(SystemInfo.chipName)
                                    .font(.headline)
                                    .foregroundStyle(PrompteraColors.textPrimary)
                                Text(L10n.t("%@ de Memória Unificada • Metal GPU • Neural Engine", SystemInfo.memoryDescription))
                                    .font(.caption)
                                    .foregroundStyle(PrompteraColors.textSecondary)
                            }
                        }
                        
                        Divider()
                            .background(PrompteraColors.borderSubtle)
                        
                        Text(L10n.t("A inferência roda 100% local no seu Mac, sem dados saindo do dispositivo. Aproveita aceleração GPU Metal e Neural Engine via Ollama."))
                            .font(.callout)
                            .foregroundStyle(PrompteraColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                
                // Ollama Section
                SettingsSection(title: L10n.t("Servidor Ollama Local"), icon: "server.rack") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(state.isOllamaConnected ? PrompteraColors.success : PrompteraColors.error)
                                .frame(width: 12, height: 12)
                                .shadow(color: (state.isOllamaConnected ? PrompteraColors.success : PrompteraColors.error).opacity(0.5), radius: 4)
                                .accessibilityHidden(true)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(state.isOllamaConnected ? L10n.t("Ollama Conectado") : L10n.t("Ollama Não Detectado"))
                                    .font(.headline)
                                    .foregroundStyle(PrompteraColors.textPrimary)
                                Text(state.isOllamaConnected ? L10n.t("Pronto para gerar prompts") : L10n.t("Execute 'ollama serve' no terminal"))
                                    .font(.caption)
                                    .foregroundStyle(PrompteraColors.textSecondary)
                            }
                            
                            Spacer()
                            
                            Button {
                                Task { await state.refreshModels() }
                            } label: {
                                if state.isRefreshingModels {
                                    ProgressView().controlSize(.small)
                                } else {
                                    Label(L10n.t("Recarregar"), systemImage: "arrow.clockwise")
                                        .font(.callout.weight(.medium))
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                            .disabled(state.isGenerating || state.isRefreshingModels)
                            .accessibilityHint(L10n.t("Verifica novamente a conexão e a lista de modelos do Ollama."))
                        }
                        
                        // Ollama URL Configuration
                        Divider()
                            .background(PrompteraColors.borderSubtle)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L10n.t("URL do Servidor Ollama"))
                                .font(.caption.weight(.medium))
                                .foregroundStyle(PrompteraColors.textSecondary)
                            
                            HStack(spacing: 8) {
                                Image(systemName: "link")
                                    .foregroundStyle(PrompteraColors.textSecondary)
                                    .frame(width: 20)
                                    .accessibilityHidden(true)
                                
                                TextField("http://127.0.0.1:11434", text: $ollamaUrlText)
                                    .textFieldStyle(.plain)
                                    .font(.system(.callout, design: .monospaced))
                                    .onSubmit(applyURL)
                                    .accessibilityLabel(L10n.t("URL do Servidor Ollama"))
                                    .accessibilityHint(L10n.t("Endereço HTTP do servidor Ollama local."))
                                
                                Button(action: applyURL) {
                                    Label(L10n.t("Aplicar"), systemImage: "checkmark")
                                        .font(.callout.weight(.medium))
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                                .accessibilityHint(L10n.t("Salva a URL e recarrega os modelos."))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(PrompteraColors.surfaceSecondary)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(urlError == nil ? PrompteraColors.borderDefault : PrompteraColors.error, lineWidth: 1)
                            )
                            
                            if let urlError {
                                Text(urlError)
                                    .font(.caption)
                                    .foregroundStyle(PrompteraColors.error)
                                    .accessibilityLabel(L10n.t("Erro na URL: %@", urlError))
                            }
                        }
                        
                        if !state.availableModels.isEmpty {
                            Divider()
                                .background(PrompteraColors.borderSubtle)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text(L10n.t("Modelos Disponíveis"))
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(PrompteraColors.textSecondary)
                                
                                ForEach(state.availableModels) { model in
                                    ModelRow(model: model, isSelected: state.selectedModel == model.name) {
                                        state.updateSelectedModel(model.name)
                                    }
                                }
                            }
                        } else if state.isOllamaConnected {
                            Divider()
                                .background(PrompteraColors.borderSubtle)
                            
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(PrompteraColors.warning)
                                Text(L10n.t("Nenhum modelo instalado. Use 'ollama pull <modelo>' no terminal."))
                                    .font(.callout)
                                    .foregroundStyle(PrompteraColors.textSecondary)
                                Spacer()
                            }
                            .padding(12)
                            .background(PrompteraColors.warning.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                }
                
                // Gemma & Harness Section
                SettingsSection(title: L10n.t("Gemma & Guardrail Harness"), icon: "wand.and.stars") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            Circle()
                                .fill((state.useGemmaGuardrailHarness && state.selectedModel.lowercased().contains("gemma")) ? PrompteraColors.success : PrompteraColors.textSecondary.opacity(0.4))
                                .frame(width: 12, height: 12)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(state.useGemmaGuardrailHarness ? L10n.t("Harness Gemma ativo") : L10n.t("Harness Gemma desativado"))
                                    .font(.callout.weight(.medium))
                                    .foregroundStyle(PrompteraColors.textPrimary)
                                Text(state.useGemmaGuardrailHarness
                                    ? L10n.t("Saída JSON estruturada, anti-delírio e língua do vendor (Inglês).")
                                    : L10n.t("Usa o harness Oxair padrão com o modelo selecionado."))
                                    .font(.caption)
                                    .foregroundStyle(PrompteraColors.textSecondary)
                            }
                            Spacer()
                        }
                        
                        Divider().background(PrompteraColors.borderSubtle)
                        
                        Toggle(L10n.t("Usar Gemma Guardrail Harness (anti-delírio)"), isOn: $state.useGemmaGuardrailHarness)
                            .font(.callout.weight(.medium))
                            .foregroundStyle(PrompteraColors.textPrimary)
                            .help(L10n.t("Quando o Gemma está selecionado, força saída JSON estruturada e auto-reparo para evitar delírios."))
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L10n.t("Idioma de saída do Master Prompt"))
                                .font(.caption.weight(.medium))
                                .foregroundStyle(PrompteraColors.textSecondary)
                            Picker(L10n.t("Idioma"), selection: $state.masterPromptLanguage) {
                                ForEach(PrompteraState.MasterPromptLanguage.allCases) { language in
                                    Text(language.rawValue).tag(language)
                                }
                            }
                            .pickerStyle(.segmented)
                            .help(L10n.t("O padrão é Inglês, a língua do vendor dos LLMs alvo."))
                        }
                        
                        Divider().background(PrompteraColors.borderSubtle)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L10n.t("Modelo Gemma"))
                                .font(.caption.weight(.medium))
                                .foregroundStyle(PrompteraColors.textSecondary)
                            
                            HStack(spacing: 8) {
                                ForEach(Array(state.gemmaModelOptions.enumerated()), id: \.offset) { _, option in
                                    GemmaModelSettingsPill(
                                        name: option.name,
                                        label: option.label,
                                        isSelected: state.selectedGemmaModel == option.name
                                    ) {
                                        state.updateSelectedGemmaModel(option.name)
                                    }
                                }
                                if state.isPullingGemma {
                                    ProgressView().controlSize(.small)
                                }
                            }
                            
                            HStack(spacing: 8) {
                                Button {
                                    Task { await state.pullGemmaModel() }
                                } label: {
                                    if state.isPullingGemma {
                                        ProgressView().controlSize(.small)
                                    } else {
                                        Label(L10n.t("Baixar/Reinstalar Gemma"), systemImage: "arrow.down.circle")
                                            .font(.callout.weight(.medium))
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                                .disabled(state.isPullingGemma || !state.isOllamaConnected)
                                
                                Spacer()
                                
                                Text(state.gemmaPullStatus)
                                    .font(.caption2)
                                    .foregroundStyle(PrompteraColors.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
                
                // Open Weight Models Section
                SettingsSection(title: L10n.t("Modelos Open Weight (Hugging Face)"), icon: "arrow.down.app.fill") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(L10n.t("Escolha um modelo open weight popular para gerar prompts. A adequação e o risco são calculados com base na memória do seu Mac."))
                            .font(.caption)
                            .foregroundStyle(PrompteraColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)

                        Divider().background(PrompteraColors.borderSubtle)

                        // Modelo atualmente selecionado
                        HStack(spacing: 12) {
                            Circle()
                                .fill(state.selectedOpenWeightModel != nil ? PrompteraColors.success : PrompteraColors.textSecondary.opacity(0.4))
                                .frame(width: 12, height: 12)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(state.selectedOpenWeightModel ?? L10n.t("Não usar modelo open weight (usar modelo padrão)"))
                                    .font(.callout.weight(.medium))
                                    .foregroundStyle(PrompteraColors.textPrimary)
                                Text(state.selectedOpenWeightModel != nil
                                    ? L10n.t("Modelo selecionado")
                                    : L10n.t("Usa o modelo padrão do Ollama para gerar prompts."))
                                    .font(.caption)
                                    .foregroundStyle(PrompteraColors.textSecondary)
                            }
                            Spacer()
                            Button {
                                state.updateSelectedOpenWeightModel(nil)
                            } label: {
                                Text(L10n.t("Limpar seleção"))
                                    .font(.caption)
                                    .foregroundStyle(PrompteraColors.error)
                            }
                            .buttonStyle(.plain)
                            .disabled(state.selectedOpenWeightModel == nil)
                        }

                        Divider().background(PrompteraColors.borderSubtle)

                        // Botão aplicar recomendação de hardware
                        Button {
                            state.applyHardwareRecommendation()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "wand.and.stars")
                                Text(L10n.t("Aplicar recomendação de hardware"))
                            }
                            .font(.callout.weight(.medium))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        Divider().background(PrompteraColors.borderSubtle)

                        // Catálogo de modelos
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(state.openWeightModelsBySuitability) { model in
                                OpenWeightModelRow(
                                    model: model,
                                    isSelected: state.selectedOpenWeightModel == model.ollamaTag ?? model.id
                                ) {
                                    state.updateSelectedOpenWeightModel(model.ollamaTag ?? model.id)
                                }
                            }
                        }
                    }
                }

                // Methodology Section
                SettingsSection(title: L10n.t("Metodologia Oxair (Harness)"), icon: "brain.head.profile") {
                    VStack(alignment: .leading, spacing: 10) {
                        Label(L10n.t("Geração → Auto-Crítica → Refinamento"), systemImage: "arrow.right")
                            .font(.callout.weight(.medium))
                            .foregroundStyle(PrompteraColors.textPrimary)
                        
                        Text(L10n.t("O Promptera implementa a metodologia Oxair em 3 etapas:"))
                            .font(.caption)
                            .foregroundStyle(PrompteraColors.textSecondary)
                        
                        VStack(alignment: .leading, spacing: 6) {
                            MethodStep(number: "1", title: L10n.t("Geração"), description: L10n.t("Constrói rascunho estruturado com papel, objetivo e guardrails"))
                            MethodStep(number: "2", title: L10n.t("Auto-Crítica"), description: L10n.t("Auditoria de adjetivos vagos, premissas ocultas e pontos cegos"))
                            MethodStep(number: "3", title: L10n.t("Refinamento"), description: L10n.t("Master Prompt final blindado com métricas concretas e schema rígido"))
                        }
                    }
                }
                
                // About Section
                SettingsSection(title: L10n.t("Sobre"), icon: "info.circle") {
                    HStack(spacing: 12) {
                        PrompteraLogo(size: 44)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(L10n.t("Promptera v%@", SystemInfo.appVersion))
                                .font(.headline)
                                .foregroundStyle(PrompteraColors.textPrimary)
                            Text(L10n.t("Meta-Prompt Harness para macOS\nDesenvolvido para Apple Silicon com SwiftUI nativo"))
                                .font(.caption)
                                .foregroundStyle(PrompteraColors.textSecondary)
                        }
                        
                        Spacer()
                    }
                    
                    Divider()
                        .background(PrompteraColors.borderSubtle)
                    
                    HStack(spacing: 12) {
                        Button {
                            UpdateController.shared.checkForUpdates()
                        } label: {
                            Label(L10n.t("Verificar Atualizações"), systemImage: "arrow.triangle.2.circlepath")
                                .font(.callout.weight(.medium))
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(!UpdateController.shared.canCheckForUpdates)
                        .accessibilityHint(L10n.t("Procura uma versão mais recente do Promptera."))
                        
                        Toggle(L10n.t("Verificar automaticamente"), isOn: Binding(
                            get: { UpdateController.shared.automaticallyChecksForUpdates },
                            set: { UpdateController.shared.automaticallyChecksForUpdates = $0 }
                        ))
                        .toggleStyle(.switch)
                        .controlSize(.small)
                    }
                }
                
                // Export/Import Section
                SettingsSection(title: L10n.t("Exportar / Importar"), icon: "square.and.arrow.up.on.square") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(L10n.t("Faça backup dos seus prompts, histórico de clipboard e configurações."))
                            .font(.caption)
                            .foregroundStyle(PrompteraColors.textSecondary)
                        
                        HStack(spacing: 12) {
                            Button {
                                exportData()
                            } label: {
                                Label(L10n.t("Exportar Tudo"), systemImage: "square.and.arrow.up")
                                    .font(.callout.weight(.medium))
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.regular)
                            .accessibilityHint(L10n.t("Exporta prompts, biblioteca, clipboard e configurações em um arquivo criptografado."))
                            
                            Button {
                                importData()
                            } label: {
                                Label(L10n.t("Importar"), systemImage: "square.and.arrow.down")
                                    .font(.callout.weight(.medium))
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.regular)
                            .accessibilityHint(L10n.t("Importa um backup exportado anteriormente."))
                        }
                        
                        Divider()
                            .background(PrompteraColors.borderSubtle)
                        
                        HStack(spacing: 12) {
                            Button {
                                exportPromptsOnly()
                            } label: {
                                Label(L10n.t("Exportar Prompts"), systemImage: "doc.text")
                                    .font(.callout.weight(.medium))
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .accessibilityHint(L10n.t("Exporta apenas o prompt atual e a biblioteca."))
                            
                            Button {
                                exportClipboardOnly()
                            } label: {
                                Label(L10n.t("Exportar Clipboard"), systemImage: "doc.on.clipboard")
                                    .font(.callout.weight(.medium))
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .accessibilityHint(L10n.t("Exporta apenas o histórico de clipboard."))
                        }
                    }
                }
            }
            .padding(20)
        }
        .onAppear {
            Task {
                let url = await state.ollamaClient.baseURL
                await MainActor.run {
                    ollamaUrlText = url.absoluteString
                }
            }
        }
    }
    
    private var accentOptions: [AccentOption] {
        [
            AccentOption(hex: nil, name: L10n.t("Tema")),
            AccentOption(hex: "8B5CF6", name: L10n.t("Roxo")),
            AccentOption(hex: "0EA5E9", name: L10n.t("Azul")),
            AccentOption(hex: "10B981", name: L10n.t("Verde")),
            AccentOption(hex: "F97316", name: L10n.t("Laranja")),
            AccentOption(hex: "F43F5E", name: L10n.t("Rosa")),
            AccentOption(hex: "64748B", name: L10n.t("Grafite")),
        ]
    }

    private func applyURL() {
        let trimmed = ollamaUrlText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme),
              url.host != nil else {
            urlError = L10n.t("URL inválida. Use o formato http://host:porta")
            return
        }
        urlError = nil
        ollamaUrlText = trimmed
        Task { await state.applyOllamaBaseURL(url) }
    }
    
    private func exportData() {
        export(prefix: "promptera-backup") { try state.exportData() }
    }
    
    private func importData() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                let data = try Data(contentsOf: url)
                try state.importData(data)
                state.setStatus(L10n.t("Dados importados com sucesso!"), kind: .success)
            } catch {
                state.errorMessage = L10n.t("Erro ao importar: %@", error.localizedDescription)
            }
        }
    }
    
    private func exportPromptsOnly() {
        export(prefix: "promptera-prompts") { try state.exportData(includeClipboard: false) }
    }
    
    private func exportClipboardOnly() {
        // Encrypted like the full backup, and re-importable through "Importar".
        export(prefix: "promptera-clipboard") { try state.exportData(includePrompts: false) }
    }
    
    private func export(prefix: String, makeData: () throws -> Data) {
        let data: Data
        do {
            data = try makeData()
        } catch {
            state.errorMessage = L10n.t("Erro ao exportar: %@", error.localizedDescription)
            return
        }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "\(prefix)-\(DateFormatter.iso8601.string(from: Date())).json"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                try data.write(to: url, options: .atomic)
                state.setStatus(L10n.t("Exportado para %@", url.lastPathComponent), kind: .success)
            } catch {
                state.errorMessage = L10n.t("Erro ao salvar arquivo: %@", error.localizedDescription)
            }
        }
    }
}

struct AccentOption: Identifiable {
    let hex: String?
    let name: String

    var id: String { hex ?? "theme" }
}

struct AccentSwatch: View {
    let color: Color
    let name: String
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                ZStack {
                    Circle()
                        .fill(color)
                        .frame(width: 26, height: 26)
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .overlay(
                    Circle().stroke(isSelected ? color : Color.clear, lineWidth: 2)
                )
                .scaleEffect(isHovered && !isSelected ? 1.08 : 1)

                Text(name)
                    .font(.caption2)
                    .foregroundStyle(isSelected ? PrompteraColors.textPrimary : PrompteraColors.textSecondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) { isHovered = hovering }
        }
        .help(L10n.t("Cor de destaque: %@", name))
        .accessibilityLabel(L10n.t("Cor de destaque: %@", name))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct ThemeSwatch: View {
    let theme: PrompteraTheme
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: theme.colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 36, height: 36)
                        .shadow(color: theme.primary.opacity(isSelected ? 0.45 : 0.2), radius: isSelected ? 6 : 3, y: 2)
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .padding(3)
                .overlay(
                    Circle().stroke(isSelected ? theme.primary : Color.clear, lineWidth: 2)
                )
                .scaleEffect(isHovered && !isSelected ? 1.06 : 1)
                
                Text(theme.displayName)
                    .font(.caption2.weight(isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? PrompteraColors.textPrimary : PrompteraColors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) { isHovered = hovering }
        }
        .help(L10n.t("Tema %@", theme.displayName))
        .accessibilityLabel(L10n.t("Tema %@", theme.displayName))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct SettingsSection<Content: View>: View {
    let title: String
    let icon: String
    let content: Content
    
    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundStyle(PrompteraColors.textPrimary)
            
            content
        }
        .padding(16)
        .background(PrompteraColors.surfaceSecondary)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(PrompteraColors.borderSubtle, lineWidth: 1)
        )
    }
}

struct ModelRow: View {
    let model: OllamaModelInfo
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(isSelected ? PrompteraColors.brandPrimary : PrompteraColors.textSecondary)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.name)
                        .font(.system(.callout, design: .monospaced))
                        .foregroundStyle(PrompteraColors.textPrimary)
                    Text(model.formattedSize)
                        .font(.caption2)
                        .foregroundStyle(PrompteraColors.textSecondary)
                }
                
                Spacer()
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? PrompteraColors.brandPrimary.opacity(0.1) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? PrompteraColors.brandPrimary : PrompteraColors.borderDefault, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.t("Modelo %@", model.name))
        .accessibilityHint(model.formattedSize)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct MethodStep: View {
    let number: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(number)
                .font(.caption.weight(.bold))
                .foregroundStyle(PrompteraColors.textOnBrand)
                .frame(width: 22, height: 22)
                .background(Circle().fill(PrompteraColors.brandPrimary))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(PrompteraColors.textPrimary)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(PrompteraColors.textSecondary)
            }
        }
    }
}

struct GemmaModelSettingsPill: View {
    let name: String
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                }
                Text(label)
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                ZStack {
                    if isSelected {
                        PrompteraColors.brandGradient
                            .clipShape(Capsule())
                    } else {
                        Capsule().fill(PrompteraColors.surfaceSecondary)
                            .overlay(Capsule().stroke(PrompteraColors.borderDefault, lineWidth: 1))
                    }
                }
            )
            .foregroundStyle(isSelected ? PrompteraColors.textOnBrand : PrompteraColors.textPrimary)
        }
        .buttonStyle(.plain)
        .help(L10n.t("Selecionar modelo %@", name))
    }
}

/// Linha de um modelo open weight do catálogo, com adequação e risco ao hardware.
struct OpenWeightModelRow: View {
    let model: OpenWeightModel
    let isSelected: Bool
    let action: () -> Void

    private var suitability: OpenWeightModel.Suitability {
        let availableGB = Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824
        return model.suitability(availableMemoryGB: availableGB)
    }

    private var riskColor: Color {
        switch suitability.risk {
        case .low: return PrompteraColors.success
        case .medium: return PrompteraColors.warning
        case .high: return PrompteraColors.error
        }
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: familyIcon(model.family))
                        .font(.title3)
                        .foregroundStyle(PrompteraColors.brandPrimary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(model.displayName)
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(PrompteraColors.textPrimary)
                        Text(model.family.rawValue + " • " + model.parameters + " parâmetros")
                            .font(.caption2)
                            .foregroundStyle(PrompteraColors.textSecondary)
                    }
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(PrompteraColors.success)
                    }
                }

                HStack(spacing: 10) {
                    adequacyBadge
                    riskBadge
                    memoryBadge
                }

                Text(model.description)
                    .font(.caption)
                    .foregroundStyle(PrompteraColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    Text(suitability.rationale)
                        .font(.caption2)
                        .foregroundStyle(PrompteraColors.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer()
                    if let url = model.huggingFaceURL {
                        Button {
                            NSWorkspace.shared.open(url)
                        } label: {
                            Label(L10n.t("Ver no Hugging Face"), systemImage: "arrow.up.right.square")
                                .font(.caption2)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? PrompteraColors.brandPrimary.opacity(0.08) : PrompteraColors.surfaceSecondary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? PrompteraColors.brandPrimary : PrompteraColors.borderDefault, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .help(L10n.t("Selecionar modelo %@", model.displayName))
    }

    private var adequacyBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "cpu.chip")
                .font(.system(size: 9))
            Text(String(format: "%.0f%%", suitability.score * 100))
                .font(.caption2.weight(.bold))
        }
        .foregroundStyle(adequacyColor)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(adequacyColor.opacity(0.12))
        .cornerRadius(4)
    }

    private var adequacyColor: Color {
        if suitability.score >= 0.7 { return PrompteraColors.success }
        if suitability.score >= 0.4 { return PrompteraColors.warning }
        return PrompteraColors.error
    }

    private var riskBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 9))
            Text(L10n.t("Risco"))
                .font(.caption2.weight(.bold)) + Text(" \(suitability.risk.rawValue)")
                .font(.caption2.weight(.bold))
        }
        .foregroundStyle(riskColor)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(riskColor.opacity(0.12))
        .cornerRadius(4)
    }

    private var memoryBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "memorychip")
                .font(.system(size: 9))
            Text("\(String(format: "%.0f", model.estimatedMemoryGB)) GB \(L10n.t("Memória estimada"))")
                .font(.caption2.weight(.bold))
        }
        .foregroundStyle(PrompteraColors.textSecondary)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(PrompteraColors.borderSubtle)
        .cornerRadius(4)
    }

    private func familyIcon(_ family: OpenWeightModel.Family) -> String {
        switch family {
        case .gemma: return "sparkles"
        case .llama: return "hare.fill"
        case .qwen: return "cpu.fill"
        case .phi: return "brain.head.profile"
        case .deepseek: return "arrow.triangle.branch"
        case .mistral: return "leaf.fill"
        }
    }
}
