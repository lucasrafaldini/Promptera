import XCTest
@testable import PrompteraKit

final class PrompteraKitTests: XCTestCase {
    func testPresetsExist() {
        XCTAssertFalse(HarnessPreset.presets.isEmpty)
        let universal = HarnessPreset.presets.first(where: { $0.id == "universal" })
        XCTAssertNotNil(universal)
    }
    
    func testHarnessPromptConstruction() async {
        let client = OllamaClient()
        let harness = PromptHarness(ollamaClient: client)
        
        let preset = HarnessPreset.presets[0]
        let (system, userPrompt) = await harness.buildGenerationPrompt(
            rawInput: "Quero um gerador de swagger",
            preset: preset,
            mode: .iterativeLoop
        )
        
        XCTAssertTrue(system.contains("Meta-Prompt Architect"))
        XCTAssertTrue(userPrompt.contains("Quero um gerador de swagger"))
        XCTAssertTrue(userPrompt.contains("METODOLOGIA OXAIR"))
    }
    
    @MainActor
    func testClipboardManager() {
        let manager = ClipboardManager(maxHistoryItems: 5)
        manager.clearHistory()
        XCTAssertTrue(manager.history.isEmpty)
        
        manager.copyToClipboard("Teste de conteúdo para clipboard")
        XCTAssertEqual(manager.history.count, 1)
        XCTAssertEqual(manager.latestItem?.content, "Teste de conteúdo para clipboard")
    }
}
