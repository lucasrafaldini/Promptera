import SwiftUI
import PrompteraKit

/// Assistente de primeira execução: guia o usuário a instalar o Ollama,
/// baixar o modelo Gemma e configurar o Promptera para começar a gerar prompts.
public struct OllamaSetupWizardView: View {
    @ObservedObject var state: PrompteraState
    @State private var currentStep: SetupStep = .installOllama
    @State private var showingSkipConfirmation = false

    public enum SetupStep: Int, CaseIterable, Identifiable {
        case installOllama = 1
        case startOllama = 2
        case pullGemma = 3
        case finished = 4

        public var id: Int { rawValue }

        public var title: String {
            switch self {
            case .installOllama: return L10n.t("Passo 1 — Instalar o Ollama")
            case .startOllama: return L10n.t("Passo 2 — Iniciar o Ollama")
            case .pullGemma: return L10n.t("Passo 3 — Baixar o modelo Gemma")
            case .finished: return L10n.t("Passo 4 — Pronto para usar")
            }
        }

        public var subtitle: String {
            switch self {
            case .installOllama: return L10n.t("O Ollama roda os modelos locais no seu Mac.")
            case .startOllama: return L10n.t("Deixe o Ollama em execução antes de gerar prompts.")
            case .pullGemma: return L10n.t("O Gemma é leve, eficaz e roda 100% local.")
            case .finished: return L10n.t("Você já pode gerar seu primeiro Master Prompt.")
            }
        }
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    PrompteraLogo(size: 24)
                    Text("Promptera")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(PrompteraColors.textPrimary)
                }
                Spacer()
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
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                LinearGradient(
                    colors: [PrompteraColors.surfacePrimary, PrompteraColors.surfacePrimary.opacity(0.9)],
                    startPoint: .top, endPoint: .bottom
                )
            )
            .overlay(alignment: .bottom) {
                Divider().background(PrompteraColors.borderSubtle)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Progresso dos passos
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            ForEach(SetupStep.allCases) { step in
                                StepIndicator(step: step, isActive: currentStep == step, isDone: step.rawValue < currentStep.rawValue)
                            }
                        }
                        Text(currentStep.title)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(PrompteraColors.textPrimary)
                        Text(currentStep.subtitle)
                            .font(.callout)
                            .foregroundStyle(PrompteraColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(16)
                    .background(PrompteraColors.surfaceSecondary)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(PrompteraColors.borderSubtle, lineWidth: 1)
                    )

                    // Conteúdo do passo atual
                    Group {
                        switch currentStep {
                        case .installOllama: installOllamaStep
                        case .startOllama: startOllamaStep
                        case .pullGemma: pullGemmaStep
                        case .finished: finishedStep
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Spacer(minLength: 40)
                }
                .padding(20)
            }

            // Rodapé com ações
            VStack(spacing: 12) {
                Divider().background(PrompteraColors.borderSubtle)
                footerActions
            }
            .padding(16)
            .background(PrompteraColors.surfacePrimary)
        }
        .frame(width: 560, height: 640)
        .background(PrompteraColors.surfacePrimary)
        .onAppear {
            refreshStepFromStatus()
        }
        .onChange(of: state.ollamaSetupStatus) { _, _ in
            refreshStepFromStatus()
        }
        .confirmationDialog(L10n.t("Pular a configuração do Gemma?"), isPresented: $showingSkipConfirmation, titleVisibility: .visible) {
            Button(L10n.t("Sim, pular e usar outro modelo"), role: .destructive) {
                state.setGemmaSetupCompleted(true)
                state.setStatus(L10n.t("Configuração pulada. Você pode configurar o Gemma em Configurações a qualquer momento."), kind: .info)
            }
            Button(L10n.t("Cancelar"), role: .cancel) {}
        } message: {
            Text(L10n.t("Sem o Gemma, o harness de guardrails não estará ativo e a saída pode não ficar na língua do vendor (Inglês)."))
        }
    }

    // MARK: - Passos

    private var installOllamaStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(L10n.t("O que é o Ollama?"), systemImage: "server.rack")
                .font(.headline)
                .foregroundStyle(PrompteraColors.textPrimary)
            Text(L10n.t("O Ollama é um servidor local que roda modelos de linguagem no seu Mac, sem enviar dados para a nuvem. O Promptera se conecta a ele para gerar prompts com o Gemma."))
                .font(.callout)
                .foregroundStyle(PrompteraColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Divider().background(PrompteraColors.borderSubtle)

            HStack(spacing: 12) {
                Circle()
                    .fill(OllamaSetupService.isOllamaInstalled() ? PrompteraColors.success : PrompteraColors.error)
                    .frame(width: 12, height: 12)
                Text(OllamaSetupService.isOllamaInstalled() ? L10n.t("Ollama já está instalado") : L10n.t("Ollama não detectado neste Mac"))
                    .font(.callout.weight(.medium))
                    .foregroundStyle(PrompteraColors.textPrimary)
                Spacer()
            }

            HStack(spacing: 10) {
                Button {
                    state.openOllamaDownloadPage()
                } label: {
                    Label(L10n.t("Baixar Ollama"), systemImage: "arrow.down.circle")
                        .font(.callout.weight(.medium))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)

                Button {
                    state.launchOllamaApp()
                } label: {
                    Label(L10n.t("Abrir app Ollama"), systemImage: "app.fill")
                        .font(.callout.weight(.medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .disabled(!OllamaSetupService.isOllamaInstalled())

                Spacer()

                Button {
                    showingSkipConfirmation = true
                } label: {
                    Text(L10n.t("Pular esta etapa"))
                        .font(.callout)
                        .foregroundStyle(PrompteraColors.textSecondary)
                }
                .buttonStyle(.plain)

                Button {
                    Task { await state.checkOllamaReadiness() }
                } label: {
                    Label(L10n.t("Verificar novamente"), systemImage: "arrow.clockwise")
                        .font(.callout.weight(.medium))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .disabled(state.isOllamaConnected && state.ollamaSetupStatus != .ollamaNotInstalled)
            }
        }
    }

    private var startOllamaStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(L10n.t("Iniciar o servidor Ollama"), systemImage: "play.circle")
                .font(.headline)
                .foregroundStyle(PrompteraColors.textPrimary)
            Text(L10n.t("O Ollama precisa estar rodando (execute 'ollama serve' ou abra o app Ollama) para que o Promptera encontre os modelos locais."))
                .font(.callout)
                .foregroundStyle(PrompteraColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Divider().background(PrompteraColors.borderSubtle)

            HStack(spacing: 12) {
                Circle()
                    .fill(state.isOllamaConnected ? PrompteraColors.success : PrompteraColors.error)
                    .frame(width: 12, height: 12)
                Text(state.isOllamaConnected ? L10n.t("Ollama está rodando") : L10n.t("Ollama não está rodando"))
                    .font(.callout.weight(.medium))
                    .foregroundStyle(PrompteraColors.textPrimary)
                Spacer()
            }

            HStack(spacing: 10) {
                Button {
                    state.launchOllamaApp()
                } label: {
                    Label(L10n.t("Abrir app Ollama"), systemImage: "app.fill")
                        .font(.callout.weight(.medium))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)

                Button {
                    Task { await state.checkOllamaReadiness() }
                } label: {
                    Label(L10n.t("Verificar conexão"), systemImage: "arrow.clockwise")
                        .font(.callout.weight(.medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .disabled(state.isRefreshingModels)

                Spacer()

                Button {
                    showingSkipConfirmation = true
                } label: {
                    Text(L10n.t("Pular esta etapa"))
                        .font(.callout)
                        .foregroundStyle(PrompteraColors.textSecondary)
                }
                .buttonStyle(.plain)
            }

            if let error = state.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(PrompteraColors.error)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var pullGemmaStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(L10n.t("Baixar o modelo Gemma"), systemImage: "arrow.down.circle")
                .font(.headline)
                .foregroundStyle(PrompteraColors.textPrimary)
            Text(L10n.t("O Gemma é um modelo pequeno e eficaz. Recomendamos o Gemma 3 1B para começar rapidamente em Macs com Apple Silicon."))
                .font(.callout)
                .foregroundStyle(PrompteraColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Divider().background(PrompteraColors.borderSubtle)

            // Escolha do modelo
            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.t("Modelo Gemma"))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(PrompteraColors.textSecondary)
                HStack(spacing: 10) {
                    GemmaModelPill(
                        name: state.recommendedGemmaModel,
                        label: L10n.t("Gemma 3 1B (leve)"),
                        isSelected: state.selectedGemmaModel == state.recommendedGemmaModel
                    ) {
                        state.updateSelectedGemmaModel(state.recommendedGemmaModel)
                    }
                    GemmaModelPill(
                        name: state.alternativeGemmaModels[0],
                        label: L10n.t("Gemma 3 4B (mais eficaz)"),
                        isSelected: state.selectedGemmaModel == state.alternativeGemmaModels[0]
                    ) {
                        state.updateSelectedGemmaModel(state.alternativeGemmaModels[0])
                    }
                    if state.alternativeGemmaModels.count > 1 {
                        GemmaModelPill(
                            name: state.alternativeGemmaModels[1],
                            label: L10n.t("Gemma 3 12B"),
                            isSelected: state.selectedGemmaModel == state.alternativeGemmaModels[1]
                        ) {
                            state.updateSelectedGemmaModel(state.alternativeGemmaModels[1])
                        }
                    }
                }
            }

            Divider().background(PrompteraColors.borderSubtle)

            // Progresso do download
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(state.isPullingGemma ? L10n.t("Baixando…") : L10n.t("Pronto para baixar"))
                        .font(.callout.weight(.medium))
                        .foregroundStyle(PrompteraColors.textPrimary)
                    Spacer()
                    Text(String(format: "%.0f%%", state.gemmaPullProgress * 100))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(PrompteraColors.textSecondary)
                        .monospacedDigit()
                }
                ProgressView(value: state.gemmaPullProgress, total: 1.0)
                    .frame(maxWidth: .infinity)
                Text(state.gemmaPullStatus)
                    .font(.caption)
                    .foregroundStyle(PrompteraColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 10) {
                Button {
                    Task { await state.pullGemmaModel() }
                } label: {
                    if state.isPullingGemma {
                        ProgressView().controlSize(.small)
                    } else {
                        Label(L10n.t("Baixar Gemma %@", state.selectedGemmaModel), systemImage: "arrow.down.circle")
                            .font(.callout.weight(.medium))
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .disabled(state.isPullingGemma || !state.isOllamaConnected)

                Spacer()

                Button {
                    showingSkipConfirmation = true
                } label: {
                    Text(L10n.t("Pular esta etapa"))
                        .font(.callout)
                        .foregroundStyle(PrompteraColors.textSecondary)
                }
                .buttonStyle(.plain)

                Button {
                    Task { await state.checkOllamaReadiness() }
                } label: {
                    Label(L10n.t("Verificar modelos"), systemImage: "arrow.clockwise")
                        .font(.callout.weight(.medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .disabled(state.isPullingGemma)
            }
        }
    }

    private var finishedStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(L10n.t("Configuração concluída"), systemImage: "checkmark.circle.fill")
                .font(.headline)
                .foregroundStyle(PrompteraColors.success)

            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(PrompteraColors.success)
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.t("Ollama conectado + Gemma instalado"))
                        .font(.callout.weight(.medium))
                        .foregroundStyle(PrompteraColors.textPrimary)
                    Text(state.selectedGemmaModel.isEmpty ? L10n.t("Modelo Gemma selecionado") : state.selectedGemmaModel)
                        .font(.caption)
                        .foregroundStyle(PrompteraColors.textSecondary)
                }
                Spacer()
            }

            Divider().background(PrompteraColors.borderSubtle)

            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.t("O que vem a seguir?"))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(PrompteraColors.textSecondary)
                Text(L10n.t("1. Descreva sua necessidade na aba Gerador."))
                    .font(.callout)
                    .foregroundStyle(PrompteraColors.textSecondary)
                Text(L10n.t("2. O Gemma cria um Master Prompt em Inglês (língua do vendor), com guardrails contra delírios."))
                    .font(.callout)
                    .foregroundStyle(PrompteraColors.textSecondary)
                Text(L10n.t("3. Copie o Master Prompt e use no seu modelo de IA favorito."))
                    .font(.callout)
                    .foregroundStyle(PrompteraColors.textSecondary)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Rodapé

    @ViewBuilder
    private var footerActions: some View {
        switch currentStep {
        case .finished:
            HStack(spacing: 10) {
                Button(L10n.t("Configurar novamente"), action: {
                    state.setGemmaSetupCompleted(false)
                    currentStep = .installOllama
                    Task { await state.checkOllamaReadiness() }
                })
                .buttonStyle(.bordered)
                .controlSize(.small)
                Spacer()
                Button(L10n.t("Começar a usar o Promptera")) {
                    state.setGemmaSetupCompleted(true)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
            }
        default:
            HStack(spacing: 10) {
                Button {
                    showingSkipConfirmation = true
                } label: {
                    Text(L10n.t("Pular configuração"))
                        .font(.callout)
                        .foregroundStyle(PrompteraColors.textSecondary)
                }
                .buttonStyle(.plain)
                Spacer()
                Button {
                    Task { await state.checkOllamaReadiness() }
                } label: {
                    Label(L10n.t("Verificar novamente"), systemImage: "arrow.clockwise")
                        .font(.callout.weight(.medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }

    // MARK: - Lógica de navegação

    private func refreshStepFromStatus() {
        switch state.ollamaSetupStatus {
        case .checking, .ollamaNotInstalled:
            currentStep = .installOllama
        case .ollamaInstalledNotRunning:
            currentStep = .startOllama
        case .ollamaRunning(models: _), .ollamaRunningGemmaMissing(installed: _):
            currentStep = .pullGemma
        case .ready:
            currentStep = .finished
        case .error:
            break // mantém o passo atual para o usuário tentar novamente
        }
    }
}

// MARK: - Subviews

private struct StepIndicator: View {
    let step: OllamaSetupWizardView.SetupStep
    let isActive: Bool
    let isDone: Bool

    var body: some View {
        HStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(isDone ? PrompteraColors.success : (isActive ? PrompteraColors.brandPrimary : PrompteraColors.borderDefault))
                    .frame(width: 24, height: 24)
                if isDone {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                } else {
                    Text("\(step.rawValue)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(isDone ? .white : (isActive ? PrompteraColors.textOnBrand : PrompteraColors.textSecondary))
                }
            }
            if step != .finished {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(isDone || isActive ? PrompteraColors.brandPrimary : PrompteraColors.borderSubtle)
            }
        }
    }
}

private struct GemmaModelPill: View {
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
