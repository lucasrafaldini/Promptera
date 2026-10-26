import XCTest
@testable import PrompteraKit

final class FuzzyMatcherTests: XCTestCase {
    func testSubsequenceMatchIsCaseAndDiacriticInsensitive() {
        let match = FuzzyMatcher.match(query: "cfgp", in: "Configuração de Produção")

        XCTAssertNotNil(match)
        XCTAssertEqual(match?.matchedOffsets.count, 4)
    }

    func testDoesNotMatchWhenCharactersAreMissing() {
        XCTAssertNil(FuzzyMatcher.match(query: "xyz", in: "Configuração de Produção"))
    }

    func testEmptyQueryMatchesEverything() {
        let match = FuzzyMatcher.match(query: "   ", in: "anything")

        XCTAssertEqual(match?.score, 0)
        XCTAssertEqual(match?.matchedOffsets, [])
    }

    func testConsecutiveAndWordBoundaryMatchesRankHigher() {
        let exact = FuzzyMatcher.match(query: "swift", in: "SwiftUI view")
        let scattered = FuzzyMatcher.match(query: "swift", in: "some wide item for testing")

        XCTAssertNotNil(exact)
        XCTAssertNotNil(scattered)
        XCTAssertGreaterThan(exact!.score, scattered!.score)
    }

    func testClipboardItemUsesFuzzyMatching() {
        let item = ClipboardItem(content: "Configuração de Produção")

        XCTAssertTrue(item.matches("cfgprod"))
        XCTAssertTrue(item.matches("producao"))
        XCTAssertFalse(item.matches("staging"))
    }

    @MainActor
    func testClipboardSearchRanksBestMatchFirst() {
        let manager = ClipboardManager(maxHistoryItems: 10)
        manager.clearHistory()
        manager.copyToClipboard("some wide item for testing")
        manager.copyToClipboard("SwiftUI view")

        manager.searchQuery = "swift"

        XCTAssertEqual(manager.filteredHistory.first?.content, "SwiftUI view")
        manager.clearHistory()
    }
}
