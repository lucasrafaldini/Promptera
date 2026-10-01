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
        XCTAssertEqual(state.statusMessage, "Pronto")
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
        XCTAssertEqual(state.statusMessage, "Geração cancelada")
    }

    func testGeneratePromptEmptyInput() {
        state = PrompteraState(ollamaClient: mockClient)
        state.inputText = ""

        state.generatePrompt()

        XCTAssertNotNil(state.errorMessage)
        XCTAssertTrue(state.errorMessage?.contains("Digite uma ideia") == true)
    }

    func testGeneratePromptNoModel() {
        state = PrompteraState(ollamaClient: mockClient)
        state.inputText = "Test input"
        state.selectedModel = ""

        state.generatePrompt()

        XCTAssertNotNil(state.errorMessage)
        XCTAssertTrue(state.errorMessage?.contains("Selecione um modelo") == true)
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