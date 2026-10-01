import XCTest
@testable import PrompteraKit

@MainActor
final class ClipboardManagerTests: XCTestCase {
    var manager: ClipboardManager!

    override func setUp() {
        super.setUp()
        manager = ClipboardManager(maxHistoryItems: 10)
    }

    override func tearDown() {
        manager.clearHistory()
        manager = nil
        super.tearDown()
    }

    func testInitialState() {
        XCTAssertTrue(manager.history.isEmpty)
        XCTAssertTrue(manager.filteredHistory.isEmpty)
        XCTAssertNil(manager.latestItem)
        // isMonitoring starts as true because startMonitoring() is called in init
    }

    func testCopyToClipboardAddsItem() {
        let testContent = "Hello, World!"
        manager.copyToClipboard(testContent)

        XCTAssertEqual(manager.history.count, 1)
        XCTAssertEqual(manager.history.first?.content, testContent)
        XCTAssertNotNil(manager.latestItem)
    }

    func testDuplicateContentNotAdded() {
        let testContent = "Duplicate test"
        manager.copyToClipboard(testContent)
        manager.copyToClipboard(testContent)

        XCTAssertEqual(manager.history.count, 1)
    }

    func testHistoryLimitEnforced() {
        for i in 0..<15 {
            manager.copyToClipboard("Item \(i)")
        }

        XCTAssertEqual(manager.history.count, 10)
        XCTAssertEqual(manager.history.first?.content, "Item 14")
        XCTAssertEqual(manager.history.last?.content, "Item 5")
    }

    func testRemoveItem() {
        manager.copyToClipboard("Item 1")
        manager.copyToClipboard("Item 2")
        let idToRemove = manager.history.first(where: { $0.content == "Item 1" })?.id

        XCTAssertNotNil(idToRemove)
        manager.removeItem(id: idToRemove!)

        XCTAssertEqual(manager.history.count, 1)
        XCTAssertEqual(manager.history.first?.content, "Item 2")
    }

    func testClearHistory() {
        manager.copyToClipboard("Item 1")
        manager.copyToClipboard("Item 2")
        manager.clearHistory()

        XCTAssertTrue(manager.history.isEmpty)
    }

    func testSearchQueryFiltersHistory() {
        manager.copyToClipboard("Swift code example")
        manager.copyToClipboard("Python script")
        manager.copyToClipboard("SwiftUI view")

        manager.searchQuery = "swift"

        XCTAssertEqual(manager.filteredHistory.count, 2)
        XCTAssertTrue(manager.filteredHistory.allSatisfy { $0.content.lowercased().contains("swift") })
    }

    func testSearchQueryCaseInsensitive() {
        manager.copyToClipboard("Test Content")

        manager.searchQuery = "TEST"

        XCTAssertEqual(manager.filteredHistory.count, 1)
    }

    func testSearchQueryClearedShowsAll() {
        manager.copyToClipboard("Item 1")
        manager.copyToClipboard("Item 2")
        manager.searchQuery = "Item 1"

        XCTAssertEqual(manager.filteredHistory.count, 1)

        manager.searchQuery = ""

        XCTAssertEqual(manager.filteredHistory.count, 2)
    }

    func testClipboardItemPreview() {
        let shortContent = "Short"
        let longContent = String(repeating: "A", count: 150)

        let shortItem = ClipboardItem(content: shortContent)
        let longItem = ClipboardItem(content: longContent)

        XCTAssertEqual(shortItem.preview, "Short")
        XCTAssertTrue(longItem.preview.hasSuffix("..."))
        XCTAssertEqual(longItem.preview.count, 103)
    }

    func testClipboardItemCharacterAndLineCount() {
        let content = "Line 1\nLine 2\nLine 3"
        let item = ClipboardItem(content: content)

        XCTAssertEqual(item.characterCount, content.count)
        XCTAssertEqual(item.lineCount, 3)
    }

    func testStartStopMonitoring() {
        // isMonitoring starts as true because startMonitoring() is called in init
        XCTAssertTrue(manager.isMonitoring)

        manager.stopMonitoring()
        XCTAssertFalse(manager.isMonitoring)

        manager.startMonitoring()
        XCTAssertTrue(manager.isMonitoring)
    }

    func testMultipleStartMonitoringCalls() {
        manager.startMonitoring()
        manager.startMonitoring()

        XCTAssertTrue(manager.isMonitoring)
    }

    func testPersistedHistory() {
        let testContent = "Persisted item"
        manager.copyToClipboard(testContent)

        let newManager = ClipboardManager(maxHistoryItems: 10)
        XCTAssertEqual(newManager.history.count, 1)
        XCTAssertEqual(newManager.history.first?.content, testContent)
    }
}