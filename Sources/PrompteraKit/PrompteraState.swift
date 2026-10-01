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
    
    public let clipboardManager: ClipboardManager
    public let ollamaClient: OllamaClient
    public let promptHarness: PromptHarness
    
    private var generationTask: Task<Void, Never>?
    private let settingsStorage = UserDefaults.standard
    private let selectedModelKey = "promptera_selected_model"
    private let selectedPresetKey = "promptera_selected_preset"
    private let selectedModeKey = "promptera_selected_mode"
    private let ollamaBaseURLKey = "promptera_ollama_base_url"
    
    public init(
        clipboardManager: ClipboardManager? = nil,
        ollamaClient: OllamaClient = OllamaClient()
    ) {
        let cm = clipboardManager ?? ClipboardManager()
        self.clipboardManager = cm
        self.ollamaClient = ollamaClient
        self.promptHarness = PromptHarness(ollamaClient: ollamaClient)
        
        // Load persisted settings
        loadPersistedSettings()
        
        Task {
            await refreshModels()
        }
    }
    
    private func loadPersistedSettings() {
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
        if let savedURL = settingsStorage.string(forKey: ollamaBaseURLKey),
           let url = URL(string: savedURL) {
            Task {
                await self.ollamaClient.setBaseURL(url)
            }
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
        Task {
            await ollamaClient.setBaseURL(url)
        }
        settingsStorage.set(url.absoluteString, forKey: ollamaBaseURLKey)
    }
    
    public func refreshModels() async {
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
        generationTask = Task {
            do {
                let stream = await promptHarness.executeHarnessStream(
                    rawInput: inputText,
                    preset: selectedPreset,
                    mode: selectedMode,
                    model: selectedModel
                )
                
                for try await event in stream {
                    guard !Task.isCancelled else { break }
                    
                    switch event.type {
                    case .stageChanged(let stage):
                        self.statusMessage = stage
                    case .tokenYielded(let token):
                        self.outputText += token
                    case .finished(let finalResult):
                        self.outputText = finalResult
                        self.statusMessage = "Prompt concluído com sucesso!"
                    }
                }
            } catch {
                if !Task.isCancelled {
                    self.errorMessage = error.localizedDescription
                    self.statusMessage = "Falha na geração"
                }
            }
            self.isGenerating = false
            self.generationTask = nil
        }
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
    
    public func exportData() throws -> Data {
        let prompts = [
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
            clipboardHistory: clipboardManager.history,
            settings: settings
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(export)
    }
    
    public func importData(_ data: Data) throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let export = try decoder.decode(ExportData.self, from: data)
        
        // Import clipboard history (merge, avoiding duplicates)
        var existingContent = Set(clipboardManager.history.map { $0.content })
        for item in export.clipboardHistory.reversed() {
            if !existingContent.contains(item.content) {
                clipboardManager.copyToClipboard(item.content)
                existingContent.insert(item.content)
            }
        }
        
        // Import settings
        if let preset = HarnessPreset.presets.first(where: { $0.id == export.settings.selectedPreset }) {
            updateSelectedPreset(preset)
        }
        if let mode = HarnessMode(rawValue: export.settings.selectedMode) {
            updateSelectedMode(mode)
        }
        // Note: Model selection requires the model to be available
        if export.settings.selectedModel.isEmpty == false {
            // Will be applied when models are refreshed
        }
        
        // Import latest prompt if available
        if let latestPrompt = export.prompts.last {
            self.inputText = latestPrompt.input
            self.outputText = latestPrompt.output
        }
    }
}