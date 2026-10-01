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
    case settings = "Configurações"
    
    public var id: String { rawValue }
    
    public var icon: String {
        switch self {
        case .generator: return "wand.and.stars"
        case .clipboard: return "doc.on.clipboard"
        case .settings: return "gearshape"
        }
    }
}

public struct MainMenuView: View {
    @StateObject private var state = PrompteraState()
    @State private var selectedTab: PrompteraTab = .generator
    @Namespace private var animationNamespace
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // App Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles.rectangle.stack.fill")
                        .foregroundStyle(PrompteraColors.brandGradient)
                        .font(.title2)
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
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                selectedTab = tab
                            }
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: tab.icon)
                                    .font(.system(size: 16, weight: .medium))
                                Text(tab.rawValue)
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
                        .help(tab.rawValue)
                        .accessibilityLabel(tab.rawValue)
                        .accessibilityAddTraits(selectedTab == tab ? .isSelected : [])
                    }
                }
                .padding(4)
                .background(PrompteraColors.surfaceSecondary)
                .cornerRadius(12)
                .frame(width: 300)
                
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
                .help("Encerrar Promptera")
                .accessibilityLabel("Encerrar Promptera")
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
                switch selectedTab {
                case .generator:
                    PromptGeneratorView(state: state)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                case .clipboard:
                    ClipboardHistoryView(clipboardManager: state.clipboardManager, state: state)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                case .settings:
                    SettingsView(state: state)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: selectedTab)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 600, height: 600)
        .background(PrompteraColors.surfacePrimary)
    }
}

struct SettingsView: View {
    @ObservedObject var state: PrompteraState
    @State private var ollamaUrlText: String = "http://127.0.0.1:11434"
    @State private var isTesting: Bool = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("Configurações")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(PrompteraColors.textPrimary)
                    Text("Gerencie preferências do Promptera e conexão com Ollama")
                        .font(.subheadline)
                        .foregroundStyle(PrompteraColors.textSecondary)
                }
                
                // Hardware Section
                SettingsSection(title: "Hardware & Aceleração", icon: "apple.logo") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            Image(systemName: "cpu.fill")
                                .font(.title2)
                                .foregroundStyle(PrompteraColors.brandGradient)
                                .frame(width: 40, height: 40)
                                .background(PrompteraColors.surfaceSecondary)
                                .cornerRadius(10)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Apple Silicon M4")
                                    .font(.headline)
                                    .foregroundStyle(PrompteraColors.textPrimary)
                                Text("Memória Unificada • Metal GPU • Neural Engine")
                                    .font(.caption)
                                    .foregroundStyle(PrompteraColors.textSecondary)
                            }
                        }
                        
                        Divider()
                            .background(PrompteraColors.borderSubtle)
                        
                        Text("A inferência roda 100% local no seu Mac, sem dados saindo do dispositivo. Aproveita aceleração GPU Metal e Neural Engine via Ollama.")
                            .font(.callout)
                            .foregroundStyle(PrompteraColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                
                // Ollama Section
                SettingsSection(title: "Servidor Ollama Local", icon: "server.rack") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(state.isOllamaConnected ? PrompteraColors.success : PrompteraColors.error)
                                .frame(width: 12, height: 12)
                                .shadow(color: (state.isOllamaConnected ? PrompteraColors.success : PrompteraColors.error).opacity(0.5), radius: 4)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(state.isOllamaConnected ? "Ollama Conectado" : "Ollama Não Detectado")
                                    .font(.headline)
                                    .foregroundStyle(PrompteraColors.textPrimary)
                                Text(state.isOllamaConnected ? "Pronto para gerar prompts" : "Execute 'ollama serve' no terminal")
                                    .font(.caption)
                                    .foregroundStyle(PrompteraColors.textSecondary)
                            }
                            
                            Spacer()
                            
                            Button {
                                Task { await state.refreshModels() }
                            } label: {
                                Label("Recarregar", systemImage: "arrow.clockwise")
                                    .font(.callout.weight(.medium))
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                            .disabled(state.isGenerating)
                        }
                        
                        // Ollama URL Configuration
                        Divider()
                            .background(PrompteraColors.borderSubtle)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("URL do Servidor Ollama")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(PrompteraColors.textSecondary)
                            
                            HStack(spacing: 8) {
                                Image(systemName: "link")
                                    .foregroundStyle(PrompteraColors.textSecondary)
                                    .frame(width: 20)
                                
                                TextField("http://127.0.0.1:11434", text: $ollamaUrlText)
                                    .textFieldStyle(.plain)
                                    .font(.system(.callout, design: .monospaced))
                                    .onSubmit {
                                        if let url = URL(string: ollamaUrlText) {
                                            state.setOllamaBaseURL(url)
                                        }
                                    }
                                
                                Button {
                                    if let url = URL(string: ollamaUrlText) {
                                        state.setOllamaBaseURL(url)
                                        Task { await state.refreshModels() }
                                    }
                                } label: {
                                    Label("Aplicar", systemImage: "checkmark")
                                        .font(.callout.weight(.medium))
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(PrompteraColors.surfaceSecondary)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(PrompteraColors.borderDefault, lineWidth: 1)
                            )
                        }
                        
                        if !state.availableModels.isEmpty {
                            Divider()
                                .background(PrompteraColors.borderSubtle)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Modelos Disponíveis")
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
                                Text("Nenhum modelo instalado. Use 'ollama pull <modelo>' no terminal.")
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
                
                // Methodology Section
                SettingsSection(title: "Metodologia Oxair (Harness)", icon: "brain.head.profile") {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Geração → Auto-Crítica → Refinamento", systemImage: "arrow.right")
                            .font(.callout.weight(.medium))
                            .foregroundStyle(PrompteraColors.textPrimary)
                        
                        Text("O Promptera implementa a metodologia Oxair em 3 etapas:")
                            .font(.caption)
                            .foregroundStyle(PrompteraColors.textSecondary)
                        
                        VStack(alignment: .leading, spacing: 6) {
                            MethodStep(number: "1", title: "Geração", description: "Constrói rascunho estruturado com papel, objetivo e guardrails")
                            MethodStep(number: "2", title: "Auto-Crítica", description: "Auditoria de adjetivos vagos, premissas ocultas e pontos cegos")
                            MethodStep(number: "3", title: "Refinamento", description: "Master Prompt final blindado com métricas concretas e schema rígido")
                        }
                    }
                }
                
                // About Section
                SettingsSection(title: "Sobre", icon: "info.circle") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Promptera v1.0.0")
                            .font(.headline)
                            .foregroundStyle(PrompteraColors.textPrimary)
                        Text("Meta-Prompt Harness para macOS\nDesenvolvido para Apple Silicon com SwiftUI nativo")
                            .font(.caption)
                            .foregroundStyle(PrompteraColors.textSecondary)
                    }
                }
                
                // Export/Import Section
                SettingsSection(title: "Exportar / Importar", icon: "square.and.arrow.up.on.square") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Faça backup dos seus prompts, histórico de clipboard e configurações.")
                            .font(.caption)
                            .foregroundStyle(PrompteraColors.textSecondary)
                        
                        HStack(spacing: 12) {
                            Button {
                                exportData()
                            } label: {
                                Label("Exportar Tudo", systemImage: "square.and.arrow.up")
                                    .font(.callout.weight(.medium))
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.regular)
                            
                            Button {
                                importData()
                            } label: {
                                Label("Importar", systemImage: "square.and.arrow.down")
                                    .font(.callout.weight(.medium))
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.regular)
                        }
                        
                        Divider()
                            .background(PrompteraColors.borderSubtle)
                        
                        HStack(spacing: 12) {
                            Button {
                                exportPromptsOnly()
                            } label: {
                                Label("Exportar Prompts", systemImage: "doc.text")
                                    .font(.callout.weight(.medium))
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            
                            Button {
                                exportClipboardOnly()
                            } label: {
                                Label("Exportar Clipboard", systemImage: "doc.on.clipboard")
                                    .font(.callout.weight(.medium))
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
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
    
    private func exportData() {
        do {
            let data = try state.exportData()
            let panel = NSSavePanel()
            panel.allowedContentTypes = [.json]
            panel.nameFieldStringValue = "promptera-backup-\(DateFormatter.iso8601.string(from: Date())).json"
            panel.begin { response in
                if response == .OK, let url = panel.url {
                    try? data.write(to: url)
                }
            }
        } catch {
            state.errorMessage = "Erro ao exportar: \(error.localizedDescription)"
        }
    }
    
    private func importData() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.begin { response in
            if response == .OK, let url = panel.url,
               let data = try? Data(contentsOf: url) {
                do {
                    try state.importData(data)
                    state.statusMessage = "Dados importados com sucesso!"
                } catch {
                    state.errorMessage = "Erro ao importar: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func exportPromptsOnly() {
        do {
            let data = try state.exportData()
            let panel = NSSavePanel()
            panel.allowedContentTypes = [.json]
            panel.nameFieldStringValue = "promptera-prompts-\(DateFormatter.iso8601.string(from: Date())).json"
            panel.begin { response in
                if response == .OK, let url = panel.url {
                    try? data.write(to: url)
                }
            }
        } catch {
            state.errorMessage = "Erro ao exportar prompts: \(error.localizedDescription)"
        }
    }
    
    private func exportClipboardOnly() {
        let data = try? JSONEncoder().encode(state.clipboardManager.history)
        if let data = data {
            let panel = NSSavePanel()
            panel.allowedContentTypes = [.json]
            panel.nameFieldStringValue = "promptera-clipboard-\(DateFormatter.iso8601.string(from: Date())).json"
            panel.begin { response in
                if response == .OK, let url = panel.url {
                    try? data.write(to: url)
                }
            }
        }
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
