import Foundation
import SwiftUI
import Combine

@MainActor
public final class PrompteraState: ObservableObject {
    @Published public var availableModels: [OllamaModelInfo] = []
    @Published public var selectedModel: String = ""
    @Published public var selectedPreset: HarnessPreset = HarnessPreset.presets[0]
    @Published public var selectedMode: HarnessMode = .iterativeLoop
    @Published public var inputText: String = ""
    @Published public var outputText: String = ""
    @Published public var statusMessage: String = "Pronto"
    @Published public var isGenerating: Bool = false
    @Published public var errorMessage: String? = nil
    @Published public var copiedToast: Bool = false
    @Published public var isOllamaConnected: Bool = false
    public var isRefreshingModels: Bool { activeRefreshes > 0 }
    @Published private var activeRefreshes = 0
    
    public let clipboardManager: ClipboardManager
    public let ollamaClient: OllamaClient
    public let promptHarness: PromptHarness
    
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
    
    public init(
        clipboardManager: ClipboardManager? = nil,
        ollamaClient: OllamaClient = OllamaClient(),
        autoRefresh: Bool = true
    ) {
        let cm = clipboardManager ?? ClipboardManager()
        self.clipboardManager = cm
        self.ollamaClient = ollamaClient
        self.promptHarness = PromptHarness(ollamaClient: ollamaClient)
        
        // Load persisted settings, then refresh using the saved server URL
        // (sequenced, so the first request never goes to the default URL by mistake).
        let savedURL = loadPersistedSettings()
        guard autoRefresh else { return }
        
        Task {
            if let savedURL {
                await ollamaClient.setBaseURL(savedURL)
            }
            await refreshModels()
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
        statusMessage = "Verificando modelos locais..."
        let available = await ollamaClient.isAvailable()
        self.isOllamaConnected = available
        
        guard available else {
            self.errorMessage = "Ollama offline. Execute 'ollama serve' no terminal."
            self.statusMessage = "Desconectado do Ollama"
            return
        }
        
        do {
            let models = try await ollamaClient.fetchAvailableModels()
            self.availableModels = models
            self.errorMessage = nil
            
            // Prefer optimal models for M4 hardware
            let preferredPriorities = [
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
            
            self.statusMessage = "Pronto (\(models.count) modelos locais)"
        } catch {
            self.errorMessage = "Falha ao carregar modelos: \(error.localizedDescription)"
            self.statusMessage = "Erro de conexão"
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
        statusMessage = "Geração cancelada"
    }
    
    public func generatePrompt() {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Digite uma ideia ou selecione um item do clipboard para começar."
            return
        }
        guard !selectedModel.isEmpty else {
            errorMessage = "Selecione um modelo local do Ollama."
            return
        }
        
        isGenerating = true
        errorMessage = nil
        outputText = ""
        statusMessage = "Iniciando harness..."
        
        generationTask?.cancel()
        let generationID = UUID()
        currentGenerationID = generationID
        let input = inputText
        let preset = selectedPreset
        let mode = selectedMode
        let model = selectedModel
        let flushInterval = streamFlushInterval
        
        generationTask = Task {
            let clock = ContinuousClock()
            var pending = ""
            var lastFlush = clock.now
            
            do {
                let stream = await promptHarness.executeHarnessStream(
                    rawInput: input,
                    preset: preset,
                    mode: mode,
                    model: model
                )
                
                for try await event in stream {
                    guard !Task.isCancelled else { break }
                    
                    switch event.type {
                    case .stageChanged(let stage):
                        self.statusMessage = stage
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
                        self.statusMessage = "Prompt concluído com sucesso!"
                    }
                }
            } catch {
                if !Task.isCancelled && self.currentGenerationID == generationID {
                    self.errorMessage = error.localizedDescription
                    self.statusMessage = "Falha na geração"
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
    
    // MARK: - Export/Import
    
    public struct ExportData: Codable {
        let version: String
        let exportedAt: Date
        let prompts: [PromptExport]
        let clipboardHistory: [ClipboardItem]
        let settings: SettingsExport
        
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
            settings: settings
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