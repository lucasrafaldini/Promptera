import SwiftUI
import PrompteraKit

public struct PromptGeneratorView: View {
    @ObservedObject var state: PrompteraState
    
    public init(state: PrompteraState) {
        self.state = state
    }
    
    public var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Configuration Header
                ConfigHeaderView(state: state)
                
                // Domain Presets
                PresetsScrollView(state: state)
                
                // Input Area
                InputAreaView(state: state)
                
                // Action Button
                ActionButtonView(state: state)
                
                // Output Section
                if !state.outputText.isEmpty || state.isGenerating {
                    OutputAreaView(state: state)
                }
                
                // Error Display
                if let error = state.errorMessage {
                    ErrorBanner(message: error)
                }
            }
            .padding(16)
        }
    }
}

struct ConfigHeaderView: View {
    @ObservedObject var state: PrompteraState
    
    var body: some View {
        VStack(spacing: 12) {
            // Model Selector
            HStack(spacing: 10) {
                Image(systemName: "cpu.fill")
                    .font(.caption)
                    .foregroundStyle(PrompteraColors.brandGradient)
                    .frame(width: 28, height: 28)
                    .background(PrompteraColors.surfaceSecondary)
                    .cornerRadius(6)
                
                if state.availableModels.isEmpty {
                    HStack(spacing: 6) {
                        ProgressView()
                            .controlSize(.mini)
                        Text(state.isOllamaConnected ? "Carregando modelos..." : "Ollama desconectado")
                            .font(.caption)
                            .foregroundStyle(PrompteraColors.textSecondary)
                    }
                } else {
                    Menu {
                        ForEach(state.availableModels) { model in
                            Button {
                                state.updateSelectedModel(model.name)
                            } label: {
                                HStack {
                                    Text(model.name)
                                    if state.selectedModel == model.name {
                                        Image(systemName: "checkmark")
                                    }
                                    Text(model.formattedSize)
                                        .foregroundStyle(PrompteraColors.textSecondary)
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(state.selectedModel.isEmpty ? "Selecionar modelo" : state.selectedModel)
                                .font(.callout.weight(.medium))
                                .lineLimit(1)
                                .foregroundStyle(state.selectedModel.isEmpty ? PrompteraColors.textSecondary : PrompteraColors.textPrimary)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(PrompteraColors.textSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(PrompteraColors.surfaceSecondary)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(PrompteraColors.borderDefault, lineWidth: 1)
                        )
                    }
                    .menuStyle(.borderlessButton)
                }
                
                // Mode Selector
                Menu {
                    ForEach(HarnessMode.allCases) { mode in
                        Button {
                            state.updateSelectedMode(mode)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(mode.rawValue)
                                    Text(mode.description)
                                        .font(.caption2)
                                        .foregroundStyle(PrompteraColors.textSecondary)
                                }
                                if state.selectedMode == mode {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: modeIcon(for: state.selectedMode))
                            .font(.caption)
                            .foregroundStyle(PrompteraColors.textSecondary)
                        Text(state.selectedMode.rawValue)
                            .font(.callout.weight(.medium))
                            .lineLimit(1)
                            .foregroundStyle(PrompteraColors.textPrimary)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(PrompteraColors.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(PrompteraColors.surfaceSecondary)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(PrompteraColors.borderDefault, lineWidth: 1)
                    )
                }
                .menuStyle(.borderlessButton)
                .help(state.selectedMode.description)
            }
        }
        .padding(14)
        .background(PrompteraColors.surfaceSecondary)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(PrompteraColors.borderSubtle, lineWidth: 1)
        )
    }
    
    private func modeIcon(for mode: HarnessMode) -> String {
        switch mode {
        case .standard: return "wand.and.stars"
        case .iterativeLoop: return "arrow.triangle.2.circlepath"
        case .modularTemplate: return "curlybraces"
        }
    }
}

struct PresetsScrollView: View {
    @ObservedObject var state: PrompteraState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Domínios")
                .font(.caption.weight(.medium))
                .foregroundStyle(PrompteraColors.textSecondary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(HarnessPreset.presets) { preset in
                        PresetPill(preset: preset, isSelected: state.selectedPreset.id == preset.id) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                state.updateSelectedPreset(preset)
                            }
                        }
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }
}

struct PresetPill: View {
    let preset: HarnessPreset
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: preset.icon)
                    .font(.system(size: 12, weight: .medium))
                Text(preset.title)
                    .font(.caption.weight(.medium))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                ZStack {
                    if isSelected {
                        PrompteraColors.brandGradient
                            .clipShape(Capsule())
                            .shadow(color: PrompteraColors.shadowBrand, radius: 4, x: 0, y: 2)
                    } else {
                        Capsule()
                            .fill(PrompteraColors.surfaceSecondary)
                            .overlay(
                                Capsule()
                                    .stroke(PrompteraColors.borderDefault, lineWidth: 1)
                            )
                    }
                }
            )
            .foregroundStyle(isSelected ? PrompteraColors.textOnBrand : PrompteraColors.textPrimary)
            .scaleEffect(isSelected ? 1.02 : 1.0)
        }
        .buttonStyle(.plain)
        .help(preset.description)
        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isSelected)
    }
}

struct InputAreaView: View {
    @ObservedObject var state: PrompteraState
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Entrada", systemImage: "text.cursor")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(PrompteraColors.textSecondary)
                
                Spacer()
                
                Button {
                    state.useLatestClipboard()
                    isInputFocused = true
                } label: {
                    Label("Colar do Clipboard", systemImage: "doc.on.clipboard")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(state.clipboardManager.latestItem == nil)
                
                if !state.inputText.isEmpty {
                    Button {
                        state.inputText = ""
                    } label: {
                        Label("Limpar", systemImage: "trash")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(PrompteraColors.surfacePrimary)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(isInputFocused ? PrompteraColors.brandPrimary : PrompteraColors.borderDefault, lineWidth: isInputFocused ? 2 : 1)
                    )
                    .animation(.easeInOut(duration: 0.2), value: isInputFocused)
                
                TextEditor(text: $state.inputText)
                    .font(.system(.body, design: .default))
                    .frame(minHeight: 100, maxHeight: 150)
                    .padding(12)
                    .focused($isInputFocused)
                    .scrollContentBackground(.hidden)
                
                if state.inputText.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Cole seu texto ou descreva sua ideia...")
                            .foregroundStyle(PrompteraColors.textTertiary)
                            .font(.callout)
                        
                        Text("Ex: \"Preciso de um script para sincronizar arquivos S3 com retry exponencial e logs estruturados em JSON\"")
                            .foregroundStyle(PrompteraColors.textTertiary.opacity(0.7))
                            .font(.caption)
                            .italic()
                    }
                    .padding(16)
                    .allowsHitTesting(false)
                }
            }
        }
    }
}

struct ActionButtonView: View {
    @ObservedObject var state: PrompteraState
    
    var body: some View {
        HStack(spacing: 12) {
            if state.isGenerating {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.regular)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Gerando Master Prompt...")
                            .font(.callout.weight(.medium))
                            .foregroundStyle(PrompteraColors.textPrimary)
                        Text(state.statusMessage)
                            .font(.caption)
                            .foregroundStyle(PrompteraColors.textSecondary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    Button {
                        state.cancelGeneration()
                    } label: {
                        Label("Cancelar", systemImage: "xmark.circle.fill")
                            .font(.callout.weight(.medium))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                    .keyboardShortcut(.escape, modifiers: [])
                }
                .padding(16)
                .background(PrompteraColors.brandPrimary.opacity(0.1))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(PrompteraColors.brandPrimary.opacity(0.3), lineWidth: 1)
                )
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            } else {
                HStack {
                    if !state.statusMessage.isEmpty && state.statusMessage != "Pronto" {
                        Label(state.statusMessage, systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(PrompteraColors.success)
                    }
                    
                    Spacer()
                    
                    Button {
                        state.generatePrompt()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "sparkles")
                                .font(.title3.weight(.semibold))
                            Text("Gerar Master Prompt")
                                .font(.headline.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(state.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || state.selectedModel.isEmpty)
                    .keyboardShortcut(.return, modifiers: .command)
                }
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: state.isGenerating)
    }
}

struct OutputAreaView: View {
    @ObservedObject var state: PrompteraState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Master Prompt Gerado", systemImage: "doc.text.fill")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(PrompteraColors.textSecondary)
                
                Spacer()
                
                Text("\(state.outputText.count) caracteres")
                    .font(.caption2)
                    .foregroundStyle(PrompteraColors.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(PrompteraColors.surfaceSecondary)
                    .cornerRadius(6)
                
                if !state.outputText.isEmpty {
                    Button {
                        state.copyOutput()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: state.copiedToast ? "checkmark.circle.fill" : "doc.on.doc.fill")
                            Text(state.copiedToast ? "Copiado!" : "Copiar")
                        }
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .tint(state.copiedToast ? PrompteraColors.success : PrompteraColors.brandPrimary)
                }
            }
            
            ScrollView {
                Text(state.outputText.isEmpty ? "O Master Prompt estruturado aparecerá aqui em tempo real..." : state.outputText)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(state.outputText.isEmpty ? PrompteraColors.textTertiary : PrompteraColors.textPrimary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
            }
            .frame(minHeight: 150, maxHeight: 300)
            .background(PrompteraColors.surfacePrimary)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(PrompteraColors.borderSubtle, lineWidth: 1)
            )
        }
    }
}

struct ErrorBanner: View {
    let message: String
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title3)
                .foregroundStyle(PrompteraColors.warning)
            
            Text(message)
                .font(.callout)
                .foregroundStyle(PrompteraColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer()
        }
        .padding(14)
        .background(PrompteraColors.warning.opacity(0.1))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(PrompteraColors.warning.opacity(0.3), lineWidth: 1)
        )
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}