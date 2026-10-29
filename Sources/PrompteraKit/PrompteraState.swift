import Foundation
import SwiftUI
import Combine
import AppKit

@MainActor
public final class PrompteraState: ObservableObject {
    public enum StatusKind: Sendable, Equatable {
        case idle
        case info
        case success
        case error
    }

    /// Status do assistente de configuração Ollama + Gemma.
    public enum OllamaSetupStatus: Equatable {
        case checking
        case ollamaNotInstalled
        case ollamaInstalledNotRunning
        case ollamaRunning(models: [OllamaModelInfo])
        case ollamaRunningGemmaMissing(installed: [OllamaModelInfo])
        case ready(gemmaModel: String)
        case error(String)
    }

    /// Língua de saída do Master Prompt otimizado.
    /// Como otimizamos prompts para LLMs de terceiros, o padrão é a língua do vendor (Inglês).
    public enum MasterPromptLanguage: String, CaseIterable, Identifiable, Codable, Sendable {
        case english = "Inglês (língua do vendor)"
        case portuguese = "Português"

        public var id: String { rawValue }
    }

    @Published public var availableModels: [OllamaModelInfo] = []
    @Published public var selectedModel: String = ""
    @Published public var selectedPreset: HarnessPreset = HarnessPreset.presets[0]
    @Published public var selectedMode: HarnessMode = .iterativeLoop
    @Published public var inputText: String = ""
    @Published public var outputText: String = ""
    @Published public var statusMessage: String = L10n.t("Pronto")
    @Published public var statusKind: StatusKind = .idle
    @Published public var isGenerating: Bool = false
    @Published public var errorMessage: String? = nil
    @Published public var copiedToast: Bool = false
    @Published public var isOllamaConnected: Bool = false
    @Published public private(set) var library: [PromptLibraryItem] = []
    public var isRefreshingModels: Bool { activeRefreshes > 0 }
    @Published private var activeRefreshes = 0
    
    public let clipboardManager: ClipboardManager
    public let ollamaClient: OllamaClient
    public let promptHarness: PromptHarness
    public let gemmaGuardrailHarness: GemmaGuardrailHarness
    
    private var generationTask: Task<Void, Never>?
    private var currentGenerationID: UUID?
    private var lastWarmUp: (model: String, date: Date)?
    /// UI updates during streaming are coalesced to this interval instead of one per token.
    private let streamFlushInterval: Duration = .milliseconds(40)
    private let settingsStorage = UserDefaults.standard
    private let selectedModelKey = "promptera_selected_model"
    private let selectedPresetKey = "promptera_selected_preset"
    private let selectedModeKey = "promptera_selected_mode"
    private let ollamaBaseURLKey = "promptera_ollama_base_url"
    private let libraryStorageKey = "promptera_prompt_library"
    private let maxLibraryItems = 100

    // MARK: - Setup Ollama + Gemma (primeira execução / foco no Gemma)

    /// Alternativas maiores de Gemma, quando o usuário quiser mais qualidade.
    public let alternativeGemmaModels = ["gemma3:4b", "gemma3:12b"]

    /// Modelo Gemma recomendado dinamicamente com base no hardware local
    /// (memória unificada e chip Apple Silicon).
    public var recommendedGemmaModel: String {
        GemmaHardwareAdvisor.recommend().model
    }

    /// Recomendação completa de hardware para o Gemma (útil para mostrar ao usuário).
    public var gemmaHardwareRecommendation: GemmaHardwareRecommendation {
        GemmaHardwareAdvisor.recommend()
    }

    @Published public var ollamaSetupStatus: OllamaSetupStatus = .checking
    @Published public var isPullingGemma: Bool = false
    @Published public var gemmaPullProgress: Double = 0
    @Published public var gemmaPullStatus: String = ""
    @Published public var useGemmaGuardrailHarness: Bool = true
    @Published public var masterPromptLanguage: MasterPromptLanguage = .english

    /// Modelo Gemma selecionado pelo usuário (persistido).
    @Published public var selectedGemmaModel: String = "gemma3:1b"

    /// Modelo open weight selecionado pelo usuário (persistido). Quando não nulo,
    /// sobrepõe o `selectedModel` na geração.
    @Published public var selectedOpenWeightModel: String? = nil

    /// Catálogo de modelos open weight (Hugging Face / Ollama).
    public var openWeightModels: [OpenWeightModel] {
        OpenWeightModelCatalog.models
    }

    /// Modelos open weight ordenados por adequação ao hardware local.
    public var openWeightModelsBySuitability: [OpenWeightModel] {
        let availableGB = Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824
        return OpenWeightModelCatalog.sortedBySuitability(availableMemoryGB: availableGB)
    }

    /// Opções de modelo Gemma expostas à UI.
    public var gemmaModelOptions: [(name: String, label: String)] {
        var options: [(name: String, label: String)] = [
            (recommendedGemmaModel, L10n.t("Gemma 3 1B (leve)")),
            (alternativeGemmaModels[0], L10n.t("Gemma 3 4B (mais eficaz)")),
        ]
        if alternativeGemmaModels.count > 1 {
            options.append((alternativeGemmaModels[1], L10n.t("Gemma 3 12B")))
        }
        return options
    }

    private let gemmaSetupCompletedKey = "promptera_gemma_setup_completed"
    private let selectedGemmaModelKey = "promptera_selected_gemma_model"
    private let selectedOpenWeightModelKey = "promptera_selected_open_weight_model"

    /// Encryption + UserDefaults writes for the prompt library happen off the main thread.
    private static let libraryPersistenceQueue = DispatchQueue(
        label: "com.promptera.library.persistence",
        qos: .utility
    )
    
    public init(
        clipboardManager: ClipboardManager? = nil,
        ollamaClient: OllamaClient = OllamaClient(),
        autoRefresh: Bool = true
    ) {
        let cm = clipboardManager ?? ClipboardManager()
        self.clipboardManager = cm
        self.ollamaClient = ollamaClient
        self.promptHarness = PromptHarness(ollamaClient: ollamaClient)
        self.gemmaGuardrailHarness = GemmaGuardrailHarness(ollamaClient: ollamaClient)
        loadPersistedLibrary()
        
        // Load persisted settings, then refresh using the saved server URL
        // (sequenced, so the first request never goes to the default URL by mistake).
        let savedURL = loadPersistedSettings()
        loadPersistedGemmaSettings()
        guard autoRefresh else { return }
        
        Task {
            if let savedURL {
                await ollamaClient.setBaseURL(savedURL)
            }
            await refreshModels()
            await checkOllamaReadiness()
        }
    }
    
    @discardableResult
    private func loadPersistedSettings() -> URL? {
        // Load selected model
        if let savedModel = settingsStorage.string(forKey: selectedModelKey) {
            self.selectedModel = savedModel
        }
        
        // Load selected preset
        if let savedPresetId = settingsStorage.string(forKey: selectedPresetKey),
           let preset = HarnessPreset.presets.first(where: { $0.id == savedPresetId }) {
            self.selectedPreset = preset
        }
        
        // Load selected mode
        if let savedModeRaw = settingsStorage.string(forKey: selectedModeKey),
           let mode = HarnessMode(rawValue: savedModeRaw) {
            self.selectedMode = mode
        }
        
        // Load Ollama base URL
        if let savedURL = settingsStorage.string(forKey: ollamaBaseURLKey) {
            return URL(string: savedURL)
        }
        return nil
    }

    // MARK: - Persistência de configurações Gemma

    private func loadPersistedGemmaSettings() {
        if let saved = settingsStorage.string(forKey: selectedGemmaModelKey) {
            self.selectedGemmaModel = saved
        }
        if let saved = settingsStorage.string(forKey: selectedOpenWeightModelKey) {
            self.selectedOpenWeightModel = saved
        }
    }

    private func persistSelectedGemmaModel() {
        settingsStorage.set(selectedGemmaModel, forKey: selectedGemmaModelKey)
    }

    private func persistSelectedOpenWeightModel() {
        settingsStorage.set(selectedOpenWeightModel, forKey: selectedOpenWeightModelKey)
    }

    public func updateSelectedGemmaModel(_ model: String) {
        selectedGemmaModel = model
        persistSelectedGemmaModel()
    }

    public func hasCompletedGemmaSetup() -> Bool {
        settingsStorage.bool(forKey: gemmaSetupCompletedKey)
    }

    public func setGemmaSetupCompleted(_ completed: Bool) {
        settingsStorage.set(completed, forKey: gemmaSetupCompletedKey)
    }

    // MARK: - Setup Ollama + Gemma (primeira execução / foco no Gemma)

    public func checkOllamaReadiness() async {
        let available = await ollamaClient.isAvailable()
        guard available else {
            if OllamaSetupService.isOllamaInstalled() {
                self.ollamaSetupStatus = .ollamaInstalledNotRunning
                self.setStatus(
                    L10n.t("Ollama instalado, mas não está rodando. Execute 'ollama serve' ou abra o app Ollama."),
                    kind: .error
                )
            } else {
                self.ollamaSetupStatus = .ollamaNotInstalled
                self.setStatus(
                    L10n.t("Ollama não detectado. Siga o assistente para instalar o Ollama e baixar o Gemma."),
                    kind: .error
                )
            }
            return
        }

        do {
            let models = try await ollamaClient.fetchAvailableModels()
            self.availableModels = models

            let gemmaEntry = models.first { $0.name.hasPrefix("gemma3") || $0.name.hasPrefix("gemma:") }
            if let gemmaName = gemmaEntry?.name {
                self.selectedGemmaModel = gemmaName
                self.persistSelectedGemmaModel()
                // Seleciona o Gemma como modelo ativo, se o usuário ainda não escolheu outro.
                // Prioriza a recomendação de hardware (memória/chip) quando não há preferência salva.
                if self.selectedModel.isEmpty {
                    self.selectedModel = self.recommendedGemmaModel
                    self.persistSelectedModel()
                }
                self.ollamaSetupStatus = .ready(gemmaModel: gemmaName)
                self.setStatus(L10n.t("Pronto com o Gemma (%@)", gemmaName), kind: .success)
            } else {
                self.ollamaSetupStatus = .ollamaRunningGemmaMissing(installed: models)
                self.setStatus(L10n.t("Ollama rodando. Baixe o modelo Gemma para começar."), kind: .info)
            }
        } catch {
            self.ollamaSetupStatus = .error(error.localizedDescription)
            self.setStatus(L10n.t("Falha ao carregar modelos: %@", error.localizedDescription), kind: .error)
        }
    }

    public func openOllamaDownloadPage() {
        OllamaSetupService.openDownloadPage()
    }

    public func launchOllamaApp() {
        OllamaSetupService.launchOrOpenDownload()
    }

    /// Faz o pull do modelo Gemma selecionado, atualizando a barra de progresso.
    /// Quando termina, recarrega os modelos e marca o setup como concluído.
    public func pullGemmaModel() async {
        let model = selectedGemmaModel
        isPullingGemma = true
        gemmaPullProgress = 0
        gemmaPullStatus = L10n.t("Baixando modelo Gemma %@...", model)
        defer { isPullingGemma = false }

        do {
            for try await progress in await ollamaClient.pullModel(named: model) {
                guard !Task.isCancelled else { break }
                gemmaPullProgress = progress.fraction
                gemmaPullStatus = progress.status.isEmpty
                    ? L10n.t("Baixando %@ (%.0f%%)...", model, progress.fraction * 100)
                    : progress.status
            }

            await refreshModels()
            await checkOllamaReadiness()

            if case .ready = ollamaSetupStatus {
                setGemmaSetupCompleted(true)
                setStatus(L10n.t("Setup concluído! O Gemma está pronto para gerar prompts."), kind: .success)
            }
        } catch {
            gemmaPullStatus = L10n.t("Falha ao baixar o Gemma: %@", error.localizedDescription)
            setStatus(gemmaPullStatus, kind: .error)
        }
    }

    private func persistSelectedModel() {
        settingsStorage.set(selectedModel, forKey: selectedModelKey)
    }
    
    private func persistSelectedPreset() {
        settingsStorage.set(selectedPreset.id, forKey: selectedPresetKey)
    }
    
    private func persistSelectedMode() {
        settingsStorage.set(selectedMode.rawValue, forKey: selectedModeKey)
    }
    
    public func setOllamaBaseURL(_ url: URL) {
        // Kept for API compatibility; prefer `applyOllamaBaseURL(_:)`.
        Task {
            await ollamaClient.setBaseURL(url)
        }
        settingsStorage.set(url.absoluteString, forKey: ollamaBaseURLKey)
    }
    
    /// Saves the URL, points the client at it and reloads the model list, in order.
    public func applyOllamaBaseURL(_ url: URL) async {
        settingsStorage.set(url.absoluteString, forKey: ollamaBaseURLKey)
        await ollamaClient.setBaseURL(url)
        await refreshModels()
    }
    
    /// Called whenever the popover opens: reconnects if Ollama was started after the
    /// app, and pre-loads the selected model so the first generation starts faster.
    public func refreshModelsIfNeeded() async {
        if !isOllamaConnected || availableModels.isEmpty {
            await refreshModels()
        }
        warmUpSelectedModel()
    }
    
    private func warmUpSelectedModel() {
        guard isOllamaConnected, !selectedModel.isEmpty, !isGenerating else { return }
        // Ollama keeps the model loaded for `OllamaClient.keepAlive`; don't re-send before that.
        if let last = lastWarmUp, last.model == selectedModel, Date().timeIntervalSince(last.date) < 20 * 60 {
            return
        }
        lastWarmUp = (selectedModel, Date())
        let model = selectedModel
        let client = ollamaClient
        Task.detached(priority: .utility) {
            await client.warmUp(model: model)
        }
    }
    
    public func refreshModels() async {
        activeRefreshes += 1
        defer { activeRefreshes -= 1 }
        setStatus(L10n.t("Verificando modelos locais..."))
        let available = await ollamaClient.isAvailable()
        self.isOllamaConnected = available
        
        guard available else {
            self.errorMessage = L10n.t("Ollama offline. Execute 'ollama serve' no terminal.")
            self.setStatus(L10n.t("Desconectado do Ollama"), kind: .error)
            return
        }
        
        do {
            let models = try await ollamaClient.fetchAvailableModels()
            self.availableModels = models
            self.errorMessage = nil
            
            // Prefer optimal models for M4 hardware.
            // O Gemma é o foco principal do Promptera, então é priorizado na seleção automática.
            let preferredPriorities = [
                "gemma3:1b",
                "gemma3:4b",
                "gemma3:12b",
                "qwen2.5-coder:7b",
                "qwen2.5-coder:14b",
                "qwen2.5-coder:3b",
                "llama3.1:latest",
                "deepseek-coder-v2:16b",
                "phi4-mini:latest"
            ]
            
            if selectedModel.isEmpty || !models.contains(where: { $0.name == selectedModel }) {
                var foundModel: String?
                for preferred in preferredPriorities {
                    if let found = models.first(where: { $0.name.contains(preferred) || preferred.contains($0.name) }) {
                        foundModel = found.name
                        break
                    }
                }
                // Fallback to first available model if no preferred match
                if foundModel == nil, let first = models.first {
                    foundModel = first.name
                }
                
                if let modelName = foundModel {
                    self.selectedModel = modelName
                    persistSelectedModel()
                }
            }
            
            self.setStatus(L10n.t("Pronto (%d modelos locais)", models.count), kind: .success)
        } catch {
            self.errorMessage = L10n.t("Falha ao carregar modelos: %@", error.localizedDescription)
            self.setStatus(L10n.t("Erro de conexão"), kind: .error)
        }
    }
    
    public func useClipboardItem(_ item: ClipboardItem) {
        self.inputText = item.content
    }
    
    public func useLatestClipboard() {
        if let latest = clipboardManager.latestItem {
            self.inputText = latest.content
        }
    }
    
    public func cancelGeneration() {
        generationTask?.cancel()
        generationTask = nil
        currentGenerationID = nil
        isGenerating = false
        setStatus(L10n.t("Geração cancelada"))
    }
    
    public func generatePrompt() {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = L10n.t("Digite uma ideia ou selecione um item do clipboard para começar.")
            return
        }
        guard !selectedModel.isEmpty else {
            errorMessage = L10n.t("Selecione um modelo local do Ollama.")
            return
        }
        
        isGenerating = true
        errorMessage = nil
        outputText = ""
        setStatus(L10n.t("Iniciando harness..."))
        
        generationTask?.cancel()
        let generationID = UUID()
        currentGenerationID = generationID
        let input = inputText
        let preset = selectedPreset
        let mode = selectedMode
        // Se o usuário escolheu um modelo open weight, ele sobrepõe o modelo padrão.
        let effectiveModel = selectedOpenWeightModel ?? selectedModel
        let flushInterval = streamFlushInterval
        
        generationTask = Task {
            let clock = ContinuousClock()
            var pending = ""
            var lastFlush = clock.now
            
            do {
                // Foco principal: quando o Gemma está selecionado (padrão ou open weight),
                // usa o Gemma Guardrail Harness (saída JSON estruturada, anti-delírio,
                // língua do vendor).
                let useGemma = effectiveModel.lowercased().contains("gemma") && useGemmaGuardrailHarness
                let stream: AsyncThrowingStream<HarnessExecutionEvent, Error>
                if useGemma {
                    stream = await gemmaGuardrailHarness.executeHarnessStream(
                        rawInput: input,
                        preset: preset,
                        mode: mode,
                        model: effectiveModel,
                        includePortugueseVersion: masterPromptLanguage == .portuguese
                    )
                } else {
                    stream = await promptHarness.executeHarnessStream(
                        rawInput: input,
                        preset: preset,
                        mode: mode,
                        model: effectiveModel
                    )
                }
                
                for try await event in stream {
                    guard !Task.isCancelled else { break }
                    
                    switch event.type {
                    case .stageChanged(let stage):
                        self.setStatus(stage)
                    case .tokenYielded(let token):
                        // Batch tokens: re-rendering a growing Text per token is O(n²).
                        pending += token
                        if clock.now - lastFlush >= flushInterval {
                            self.outputText += pending
                            pending = ""
                            lastFlush = clock.now
                        }
                    case .finished(let finalResult):
                        pending = ""
                        self.outputText = finalResult
                        self.setStatus(L10n.t("Prompt concluído com sucesso!"), kind: .success)
                        if !finalResult.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            _ = self.savePromptToLibrary(
                                input: input,
                                output: finalResult,
                                preset: preset,
                                mode: mode,
                                model: effectiveModel
                            )
                        }
                    }
                }
            } catch {
                if !Task.isCancelled && self.currentGenerationID == generationID {
                    self.errorMessage = error.localizedDescription
                    self.setStatus(L10n.t("Falha na geração"), kind: .error)
                }
            }
            
            // A newer generation (or a cancel) owns the state now.
            guard self.currentGenerationID == generationID else { return }
            if !pending.isEmpty {
                self.outputText += pending
            }
            self.isGenerating = false
            self.generationTask = nil
            self.currentGenerationID = nil
        }
    }
    
    public func dismissError() {
        errorMessage = nil
    }

    /// Updates the status line and its semantic kind (used for icon/color).
    public func setStatus(_ message: String, kind: StatusKind = .info) {
        statusMessage = message
        statusKind = kind
    }
    
    public func copyOutput() {
        guard !outputText.isEmpty else { return }
        clipboardManager.copyToClipboard(outputText)
        copiedToast = true
        
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            self.copiedToast = false
        }
    }
    
    // MARK: - Settings Persistence
    
    public func updateSelectedModel(_ model: String) {
        selectedModel = model
        persistSelectedModel()
        warmUpSelectedModel()
    }
    
    public func updateSelectedPreset(_ preset: HarnessPreset) {
        selectedPreset = preset
        persistSelectedPreset()
    }
    
    public func updateSelectedMode(_ mode: HarnessMode) {
        selectedMode = mode
        persistSelectedMode()
    }

    public func updateSelectedOpenWeightModel(_ model: String?) {
        selectedOpenWeightModel = model
        persistSelectedOpenWeightModel()
    }

    /// Aplica a recomendação de hardware como modelo Gemma ativo (quando o usuário
    /// ainda não escolheu um modelo explicitamente).
    public func applyHardwareRecommendation() {
        let rec = GemmaHardwareAdvisor.recommend()
        self.selectedGemmaModel = rec.model
        self.persistSelectedGemmaModel()
        if self.selectedModel.isEmpty {
            self.selectedModel = rec.model
            self.persistSelectedModel()
        }
        self.setStatus(L10n.t("Modelo recomendado para este Mac: %@", rec.model), kind: .info)
    }
    
    // MARK: - Prompt Library

    public func libraryItems(matching query: String) -> [PromptLibraryItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return library }
        return library
            .compactMap { item -> (item: PromptLibraryItem, match: FuzzyMatch)? in
                guard let match = item.fuzzyMatch(trimmed) else { return nil }
                return (item, match)
            }
            .sorted { lhs, rhs in
                if lhs.match.score != rhs.match.score {
                    return lhs.match.score > rhs.match.score
                }
                return lhs.item.updatedAt > rhs.item.updatedAt
            }
            .map(\.item)
    }

    @discardableResult
    public func savePromptToLibrary(
        input: String,
        output: String,
        preset: HarnessPreset,
        mode: HarnessMode,
        model: String
    ) -> PromptLibraryItem? {
        let trimmedOutput = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedOutput.isEmpty else { return nil }

        let item = PromptLibraryItem(
            input: input,
            output: trimmedOutput,
            presetID: preset.id,
            modeRawValue: mode.rawValue,
            model: model
        )
        library.removeAll { $0.input == item.input && $0.output == item.output }
        library.insert(item, at: 0)
        if library.count > maxLibraryItems {
            library.removeLast(library.count - maxLibraryItems)
        }
        persistLibrary()
        return item
    }

    public func deleteLibraryItem(id: UUID) {
        library.removeAll { $0.id == id }
        persistLibrary()
    }

    public func updateLibraryItem(_ item: PromptLibraryItem) {
        guard let index = library.firstIndex(where: { $0.id == item.id }) else { return }
        var updated = item
        updated.title = updated.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if updated.title.isEmpty {
            updated.title = PromptLibraryItem.makeTitle(from: updated.input)
        }
        updated.updatedAt = Date()
        library[index] = updated
        library.sort { $0.updatedAt > $1.updatedAt }
        persistLibrary()
    }

    public func loadLibraryItem(_ item: PromptLibraryItem) {
        inputText = item.input
        outputText = item.output
        if let preset = item.preset {
            updateSelectedPreset(preset)
        }
        if let mode = item.mode {
            updateSelectedMode(mode)
        }
        if availableModels.contains(where: { $0.name == item.model }) {
            updateSelectedModel(item.model)
        }
    }

    public func clearLibrary() {
        library.removeAll()
        persistLibrary()
    }

    private func persistLibrary() {
        let snapshot = library
        let key = libraryStorageKey
        let encryptionService = EncryptionService.shared
        Self.libraryPersistenceQueue.async {
            do {
                let data = try JSONEncoder().encode(snapshot)
                let encrypted = try encryptionService.encrypt(data)
                UserDefaults.standard.set(encrypted, forKey: key)
            } catch {
                // Non-critical persistence failure
            }
        }
    }

    private func loadPersistedLibrary() {
        Self.libraryPersistenceQueue.sync {}
        guard let encryptedData = settingsStorage.data(forKey: libraryStorageKey) else { return }
        do {
            let data = try EncryptionService.shared.decrypt(encryptedData)
            library = try JSONDecoder().decode([PromptLibraryItem].self, from: data)
        } catch {
            library = []
            settingsStorage.removeObject(forKey: libraryStorageKey)
        }
    }

    private func mergeLibraryItems(_ items: [PromptLibraryItem]) {
        guard !items.isEmpty else { return }
        var seen = Set(library.map(\.id))
        let newItems = items.filter { seen.insert($0.id).inserted }
        guard !newItems.isEmpty else { return }
        library = Array((library + newItems).sorted { $0.updatedAt > $1.updatedAt }.prefix(maxLibraryItems))
        persistLibrary()
    }

    // MARK: - Export/Import
    
    public struct ExportData: Codable {
        let version: String
        let exportedAt: Date
        let prompts: [PromptExport]
        let clipboardHistory: [ClipboardItem]
        let settings: SettingsExport
        let library: [PromptLibraryItem]?
        
        struct PromptExport: Codable {
            let input: String
            let output: String
            let preset: String
            let mode: String
            let model: String
            let createdAt: Date
        }
        
        struct SettingsExport: Codable {
            let selectedModel: String
            let selectedPreset: String
            let selectedMode: String
        }
    }
    
    public func exportData(
        encrypted: Bool = true,
        includePrompts: Bool = true,
        includeClipboard: Bool = true
    ) throws -> Data {
        let prompts = (!includePrompts || (outputText.isEmpty && inputText.isEmpty)) ? [] : [
            ExportData.PromptExport(
                input: inputText,
                output: outputText,
                preset: selectedPreset.id,
                mode: selectedMode.rawValue,
                model: selectedModel,
                createdAt: Date()
            )
        ]
        
        let settings = ExportData.SettingsExport(
            selectedModel: selectedModel,
            selectedPreset: selectedPreset.id,
            selectedMode: selectedMode.rawValue
        )
        
        let export = ExportData(
            version: "1.0",
            exportedAt: Date(),
            prompts: prompts,
            clipboardHistory: includeClipboard ? clipboardManager.history : [],
            settings: settings,
            library: includePrompts ? library : nil
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let plainData = try encoder.encode(export)
        
        if encrypted {
            let encryptionService = EncryptionService.shared
            let payload = try encryptionService.encryptToPayload(plainData)
            let payloadEncoder = JSONEncoder()
            payloadEncoder.dateEncodingStrategy = .iso8601
            payloadEncoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            return try payloadEncoder.encode(payload)
        }
        
        return plainData
    }
    
    public func importData(_ data: Data, encrypted: Bool = true) throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let export: ExportData
        
        if encrypted {
            // Try to decrypt first
            let encryptionService = EncryptionService.shared
            let payload = try decoder.decode(EncryptionService.EncryptedPayload.self, from: data)
            let decryptedData = try encryptionService.decryptFromPayload(payload)
            export = try decoder.decode(ExportData.self, from: decryptedData)
        } else {
            export = try decoder.decode(ExportData.self, from: data)
        }
        
        // Import clipboard history (merge, avoiding duplicates) without overwriting
        // whatever the user currently has on the system pasteboard.
        clipboardManager.mergeItems(export.clipboardHistory)

        // Import the prompt library (merge, avoiding duplicate IDs).
        mergeLibraryItems(export.library ?? [])
        
        // Import settings
        if let preset = HarnessPreset.presets.first(where: { $0.id == export.settings.selectedPreset }) {
            updateSelectedPreset(preset)
        }
        if let mode = HarnessMode(rawValue: export.settings.selectedMode) {
            updateSelectedMode(mode)
        }
        // Apply the model only if it's installed here; otherwise keep the current one.
        if availableModels.contains(where: { $0.name == export.settings.selectedModel }) {
            updateSelectedModel(export.settings.selectedModel)
        }
        
        // Import latest prompt if available
        if let latestPrompt = export.prompts.last {
            self.inputText = latestPrompt.input
            self.outputText = latestPrompt.output
        }
    }
}