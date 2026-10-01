import XCTest
@testable import PrompteraKit

final class ModelsTests: XCTestCase {
    func testClipboardItemInitialization() {
        let id = UUID()
        let content = "Test content"
        let timestamp = Date()

        let item = ClipboardItem(id: id, content: content, timestamp: timestamp)

        XCTAssertEqual(item.id, id)
        XCTAssertEqual(item.content, content)
        XCTAssertEqual(item.timestamp, timestamp)
    }

    func testClipboardItemDefaultInitialization() {
        let item = ClipboardItem(content: "Auto-generated")

        XCTAssertNotNil(item.id)
        XCTAssertEqual(item.content, "Auto-generated")
        XCTAssertNotNil(item.timestamp)
    }

    func testClipboardItemEquatable() {
        let timestamp = Date()
        let item1 = ClipboardItem(id: UUID(), content: "Same", timestamp: timestamp)
        let item2 = ClipboardItem(id: UUID(), content: "Same", timestamp: timestamp)
        let item3 = ClipboardItem(id: UUID(), content: "Different", timestamp: timestamp)

        // Equatable compares all properties including id and timestamp
        XCTAssertNotEqual(item1, item2) // Different IDs
        XCTAssertNotEqual(item1, item3) // Different content
        
        // Same ID and content but different timestamp
        let item4 = ClipboardItem(id: UUID(), content: "Same", timestamp: Date(timeIntervalSinceNow: 100))
        XCTAssertNotEqual(item1, item4)
    }

    func testClipboardItemHashable() {
        let timestamp = Date()
        let item1 = ClipboardItem(id: UUID(), content: "Test", timestamp: timestamp)
        let item2 = ClipboardItem(id: UUID(), content: "Test", timestamp: timestamp)
        let item3 = ClipboardItem(id: UUID(), content: "Other", timestamp: timestamp)

        var set = Set<ClipboardItem>()
        set.insert(item1)
        set.insert(item2)
        set.insert(item3)

        // Each has unique ID, so all 3 are distinct
        XCTAssertEqual(set.count, 3)
    }

    func testOllamaModelInfoInitialization() {
        let model = OllamaModelInfo(name: "test-model", size: 1073741824, modifiedAt: "2024-01-01T00:00:00Z")

        XCTAssertEqual(model.id, "test-model")
        XCTAssertEqual(model.name, "test-model")
        XCTAssertEqual(model.size, 1073741824)
        XCTAssertEqual(model.modifiedAt, "2024-01-01T00:00:00Z")
    }

    func testOllamaModelInfoFormattedSize() {
        let modelWithSize = OllamaModelInfo(name: "large", size: 7_516_192_768)
        let modelWithoutSize = OllamaModelInfo(name: "unknown", size: nil)

        XCTAssertEqual(modelWithSize.formattedSize, "7.0 GB")
        XCTAssertEqual(modelWithoutSize.formattedSize, "")
    }

    func testOllamaModelInfoEquatable() {
        let model1 = OllamaModelInfo(name: "model", size: 100, modifiedAt: "date")
        let model2 = OllamaModelInfo(name: "model", size: 200, modifiedAt: "other")
        let model3 = OllamaModelInfo(name: "other", size: 100, modifiedAt: "date")

        // Equatable compares all properties
        XCTAssertNotEqual(model1, model2) // Different size
        XCTAssertNotEqual(model1, model3) // Different name
        
        // Same values
        let model4 = OllamaModelInfo(name: "model", size: 100, modifiedAt: "date")
        XCTAssertEqual(model1, model4)
    }

    func testHarnessModeAllCases() {
        let allModes = HarnessMode.allCases

        XCTAssertEqual(allModes.count, 3)
        XCTAssertTrue(allModes.contains(.standard))
        XCTAssertTrue(allModes.contains(.iterativeLoop))
        XCTAssertTrue(allModes.contains(.modularTemplate))
    }

    func testHarnessModeRawValues() {
        XCTAssertEqual(HarnessMode.standard.rawValue, "Direto (Master Prompt)")
        XCTAssertEqual(HarnessMode.iterativeLoop.rawValue, "Loop Oxair (Gera → Critica → Refina)")
        XCTAssertEqual(HarnessMode.modularTemplate.rawValue, "Modular (Com Variáveis {{...}})")
    }

    func testHarnessModeDescriptions() {
        XCTAssertTrue(HarnessMode.standard.description.contains("Master Prompt"))
        XCTAssertTrue(HarnessMode.iterativeLoop.description.contains("Oxair"))
        XCTAssertTrue(HarnessMode.modularTemplate.description.contains("template reutilizável"))
    }

    func testHarnessPresetInitialization() {
        let preset = HarnessPreset(
            id: "test",
            title: "Test Preset",
            icon: "star",
            description: "Test description",
            domainGuidance: "Test guidance"
        )

        XCTAssertEqual(preset.id, "test")
        XCTAssertEqual(preset.title, "Test Preset")
        XCTAssertEqual(preset.icon, "star")
        XCTAssertEqual(preset.description, "Test description")
        XCTAssertEqual(preset.domainGuidance, "Test guidance")
    }

    func testHarnessPresetEquatableAndHashable() {
        let preset1 = HarnessPreset(id: "same", title: "Title", icon: "icon", description: "desc", domainGuidance: "guidance")
        let preset2 = HarnessPreset(id: "same", title: "Different", icon: "icon", description: "desc", domainGuidance: "guidance")
        let preset3 = HarnessPreset(id: "different", title: "Title", icon: "icon", description: "desc", domainGuidance: "guidance")

        // Equatable compares all properties
        XCTAssertNotEqual(preset1, preset2) // Different title
        XCTAssertNotEqual(preset1, preset3) // Different id
        
        // Same values
        let preset4 = HarnessPreset(id: "same", title: "Title", icon: "icon", description: "desc", domainGuidance: "guidance")
        XCTAssertEqual(preset1, preset4)

        var set = Set<HarnessPreset>()
        set.insert(preset1)
        set.insert(preset2)
        set.insert(preset3)

        // All have different properties, so all 3 are distinct
        XCTAssertEqual(set.count, 3)
    }

    func testHarnessPresetPresetsCount() {
        XCTAssertEqual(HarnessPreset.presets.count, 5)
    }

    func testHarnessPresetPresetIds() {
        let ids = HarnessPreset.presets.map { $0.id }

        XCTAssertTrue(ids.contains("universal"))
        XCTAssertTrue(ids.contains("coding"))
        XCTAssertTrue(ids.contains("system_design"))
        XCTAssertTrue(ids.contains("reasoning"))
        XCTAssertTrue(ids.contains("copywriting"))
    }

    func testHarnessPresetPresetTitles() {
        let titles = HarnessPreset.presets.map { $0.title }

        XCTAssertTrue(titles.contains("Universal (Master)"))
        XCTAssertTrue(titles.contains("Engenharia de Software"))
        XCTAssertTrue(titles.contains("System Design & DevOps"))
        XCTAssertTrue(titles.contains("Análise & Raciocínio Profundo"))
        XCTAssertTrue(titles.contains("Copywriting & Conteúdo"))
    }
}