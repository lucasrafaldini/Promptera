import XCTest
import AppKit
@testable import PrompteraKit

@MainActor
final class ImprovementsTests: XCTestCase {
    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "promptera_clipboard_history")
        super.tearDown()
    }

    func testClipboardItemCodableRoundTripKeepsDerivedValues() throws {
        let item = ClipboardItem(content: "Linha 1\nLinha 2")
        let data = try JSONEncoder().encode(item)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(Set(json.keys), ["id", "content", "timestamp"], "Derived values must not be persisted")

        let decoded = try JSONDecoder().decode(ClipboardItem.self, from: data)
        XCTAssertEqual(decoded, item)
        XCTAssertEqual(decoded.lineCount, 2)
        XCTAssertEqual(decoded.preview, "Linha 1 Linha 2")
    }

    func testClipboardItemMatchIsCaseAndDiacriticInsensitive() {
        let item = ClipboardItem(content: "Configuração de Produção")
        XCTAssertTrue(item.matches("producao"))
        XCTAssertTrue(item.matches("CONFIGURA"))
        XCTAssertFalse(item.matches("staging"))
    }

    func testMergeItemsDoesNotTouchSystemPasteboard() {
        let manager = ClipboardManager(maxHistoryItems: 10)
        manager.clearHistory()
        manager.copyToClipboard("atual")
        let changeCount = NSPasteboard.general.changeCount

        manager.mergeItems([
            ClipboardItem(content: "importado", timestamp: Date(timeIntervalSinceNow: -60)),
            ClipboardItem(content: "atual"),
        ])

        XCTAssertEqual(NSPasteboard.general.changeCount, changeCount)
        XCTAssertEqual(manager.history.map(\.content), ["atual", "importado"])
        manager.clearHistory()
    }

    func testExportWithoutClipboardOmitsHistory() throws {
        let state = PrompteraState(ollamaClient: OllamaClient(baseURL: URL(string: "http://127.0.0.1:9")!))
        state.clipboardManager.copyToClipboard("segredo")
        state.inputText = "ideia"

        let data = try state.exportData(encrypted: false, includeClipboard: false)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual((json["clipboardHistory"] as? [Any])?.count, 0)
        XCTAssertEqual((json["prompts"] as? [Any])?.count, 1)
        state.clipboardManager.clearHistory()
    }

    func testThemeStorePersistsChoices() {
        let suite = "promptera-theme-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = ThemeStore(defaults: defaults)
        XCTAssertEqual(store.theme, .aurora)
        XCTAssertEqual(store.appearance, .system)

        store.theme = .ocean
        store.appearance = .dark

        let reloaded = ThemeStore(defaults: defaults)
        XCTAssertEqual(reloaded.theme, .ocean)
        XCTAssertEqual(reloaded.appearance, .dark)
    }

    func testEveryThemeHasThreeStops() {
        for theme in PrompteraTheme.allCases {
            XCTAssertEqual(theme.colors.count, 3, theme.rawValue)
        }
    }
}
