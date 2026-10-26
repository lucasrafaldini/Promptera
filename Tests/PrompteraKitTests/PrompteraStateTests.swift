import XCTest
@testable import PrompteraKit

@MainActor
final class PrompteraStateTests: XCTestCase {
    var state: PrompteraState!
    var mockClient: OllamaClient!

    override func setUp() {
        super.setUp()
        mockClient = OllamaClient(baseURL: URL(string: "http://127.0.0.1:11434")!)
        
        // Clear persisted settings for clean test state
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "promptera_selected_model")
        defaults.removeObject(forKey: "promptera_selected_preset")
        defaults.removeObject(forKey: "promptera_selected_mode")
        defaults.removeObject(forKey: "promptera_ollama_base_url")
        defaults.removeObject(forKey: "promptera_prompt_library")
    }

    override func tearDown() {
        state?.cancelGeneration()
        state = nil
        mockClient = nil
        super.tearDown()
    }

    func testInitialState() {
        state = PrompteraState(ollamaClient: mockClient)

        XCTAssertEqual(state.availableModels, [])
        XCTAssertEqual(state.selectedModel, "")
        XCTAssertEqual(state.selectedPreset.id, HarnessPreset.presets[0].id)
        XCTAssertEqual(state.selectedMode, .iterativeLoop)
        XCTAssertEqual(state.inputText, "")
        XCTAssertEqual(state.outputText, "")
        XCTAssertEqual(state.statusMessage, L10n.t("Pronto"))
        XCTAssertEqual(state.statusKind, .idle)
        XCTAssertFalse(state.isGenerating)
        XCTAssertNil(state.errorMessage)
        XCTAssertFalse(state.copiedToast)
        XCTAssertFalse(state.isOllamaConnected)
    }

    func testUseClipboardItem() {
        state = PrompteraState(ollamaClient: mockClient)
        let item = ClipboardItem(content: "Clipboard content")

        state.useClipboardItem(item)

        XCTAssertEqual(state.inputText, "Clipboard content")
    }

    func testUseLatestClipboard() {
        state = PrompteraState(ollamaClient: mockClient)
        state.clipboardManager.copyToClipboard("Latest clipboard item")

        state.useLatestClipboard()

        XCTAssertEqual(state.inputText, "Latest clipboard item")
    }

    func testUseLatestClipboardEmpty() {
        state = PrompteraState(ollamaClient: mockClient)
        state.clipboardManager.clearHistory()

        state.useLatestClipboard()

        XCTAssertEqual(state.inputText, "")
    }

    func testCancelGeneration() {
        state = PrompteraState(ollamaClient: mockClient)
        state.isGenerating = true

        state.cancelGeneration()

        XCTAssertFalse(state.isGenerating)
        XCTAssertEqual(state.statusMessage, L10n.t("Geração cancelada"))
    }

    func testGeneratePromptEmptyInput() {
        state = PrompteraState(ollamaClient: mockClient)
        state.inputText = ""

        state.generatePrompt()

        XCTAssertEqual(
            state.errorMessage,
            L10n.t("Digite uma ideia ou selecione um item do clipboard para começar.")
        )
    }

    func testGeneratePromptNoModel() {
        state = PrompteraState(ollamaClient: mockClient)
        state.inputText = "Test input"
        state.selectedModel = ""

        state.generatePrompt()

        XCTAssertEqual(state.errorMessage, L10n.t("Selecione um modelo local do Ollama."))
    }

    func testCopyOutput() {
        state = PrompteraState(ollamaClient: mockClient)
        state.outputText = "Generated prompt to copy"

        state.copyOutput()

        XCTAssertTrue(state.copiedToast)
        XCTAssertEqual(state.clipboardManager.latestItem?.content, "Generated prompt to copy")
    }

    func testCopyOutputEmpty() {
        state = PrompteraState(ollamaClient: mockClient)
        state.outputText = ""

        state.copyOutput()

        XCTAssertFalse(state.copiedToast)
    }

    func testCopyOutputToastAutoClears() async {
        state = PrompteraState(ollamaClient: mockClient)
        state.outputText = "Test"

        state.copyOutput()
        XCTAssertTrue(state.copiedToast)

        try? await Task.sleep(nanoseconds: 2_500_000_000)

        XCTAssertFalse(state.copiedToast)
    }

    func testSavePromptToLibrary() {
        state = PrompteraState(ollamaClient: mockClient)

        let item = state.savePromptToLibrary(
            input: "Create a REST API",
            output: "# ROLE\nYou are a backend engineer.",
            preset: HarnessPreset.presets[0],
            mode: .standard,
            model: "llama3.1"
        )

        XCTAssertNotNil(item)
        XCTAssertEqual(state.library.count, 1)
        XCTAssertEqual(item?.title, "Create a REST API")
        XCTAssertEqual(item?.model, "llama3.1")
        XCTAssertEqual(item?.mode, .standard)

        state.deleteLibraryItem(id: item!.id)
        XCTAssertTrue(state.library.isEmpty)
    }

    func testSavePromptToLibraryIgnoresEmptyOutput() {
        state = PrompteraState(ollamaClient: mockClient)

        let item = state.savePromptToLibrary(
            input: "Create a REST API",
            output: "   \n",
            preset: HarnessPreset.presets[0],
            mode: .standard,
            model: "llama3.1"
        )

        XCTAssertNil(item)
        XCTAssertTrue(state.library.isEmpty)
    }

    func testLibrarySearchUsesFuzzyMatching() {
        state = PrompteraState(ollamaClient: mockClient)
        _ = state.savePromptToLibrary(
            input: "Create a REST API",
            output: "Backend prompt",
            preset: HarnessPreset.presets[1],
            mode: .standard,
            model: "llama3.1"
        )
        _ = state.savePromptToLibrary(
            input: "Write marketing copy",
            output: "Copy prompt",
            preset: HarnessPreset.presets[4],
            mode: .modularTemplate,
            model: "llama3.1"
        )

        XCTAssertEqual(state.libraryItems(matching: "rest api").count, 1)
        XCTAssertEqual(state.libraryItems(matching: "markting").count, 1)
        XCTAssertEqual(state.libraryItems(matching: "").count, 2)

        state.clearLibrary()
    }

    func testLoadLibraryItemRestoresPromptState() {
        state = PrompteraState(ollamaClient: mockClient)
        let preset = HarnessPreset.presets[1]
        let item = state.savePromptToLibrary(
            input: "Create a REST API",
            output: "Master prompt",
            preset: preset,
            mode: .modularTemplate,
            model: "llama3.1"
        )!

        state.inputText = ""
        state.outputText = ""
        state.updateSelectedPreset(HarnessPreset.presets[0])
        state.updateSelectedMode(.standard)

        state.loadLibraryItem(item)

        XCTAssertEqual(state.inputText, "Create a REST API")
        XCTAssertEqual(state.outputText, "Master prompt")
        XCTAssertEqual(state.selectedPreset.id, preset.id)
        XCTAssertEqual(state.selectedMode, .modularTemplate)

        state.clearLibrary()
    }
}

final class ClipboardManagerIntegrationTests: XCTestCase {
    @MainActor
    func testClipboardHistoryPersistenceAcrossInstances() {
        let manager1 = ClipboardManager(maxHistoryItems: 5)
        manager1.clearHistory()
        manager1.copyToClipboard("Persistent item 1")
        manager1.copyToClipboard("Persistent item 2")

        let manager2 = ClipboardManager(maxHistoryItems: 5)

        XCTAssertEqual(manager2.history.count, 2)
        XCTAssertEqual(manager2.history[0].content, "Persistent item 2")
        XCTAssertEqual(manager2.history[1].content, "Persistent item 1")
    }

    @MainActor
    func testClipboardHistoryRespectsMaxItemsAcrossInstances() {
        let manager1 = ClipboardManager(maxHistoryItems: 3)
        manager1.clearHistory()
        for i in 1...5 {
            manager1.copyToClipboard("Item \(i)")
        }

        let manager2 = ClipboardManager(maxHistoryItems: 3)

        XCTAssertEqual(manager2.history.count, 3)
        XCTAssertEqual(manager2.history[0].content, "Item 5")
        XCTAssertEqual(manager2.history[2].content, "Item 3")
    }
}