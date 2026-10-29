import XCTest
@testable import PrompteraKit

final class GemmaHardwareAdvisorTests: XCTestCase {
    func testRecommendationReturnsValidModel() {
        let rec = GemmaHardwareAdvisor.recommend()
        XCTAssertFalse(rec.model.isEmpty)
        XCTAssertGreaterThan(rec.availableMemoryGB, 0)
        XCTAssertGreaterThan(rec.estimatedMemoryGB, 0)
        XCTAssertFalse(rec.rationale.isEmpty)
    }

    func testRecommendationModelIsKnownGemma() {
        let rec = GemmaHardwareAdvisor.recommend()
        let known = Set(GemmaHardwareAdvisor.allGemmaModels().map { $0.name })
        XCTAssertTrue(known.contains(rec.model))
    }

    func testRiskLevelIsValid() {
        let rec = GemmaHardwareAdvisor.recommend()
        XCTAssertTrue([GemmaHardwareRecommendation.RiskLevel.low,
                       .medium,
                       .high].contains(rec.riskLevel))
    }

    func testAllGemmaModelsHaveMemoryEstimate() {
        for (name, gb) in GemmaHardwareAdvisor.allGemmaModels() {
            XCTAssertGreaterThan(gb, 0, "\(name) deve ter estimativa de memória > 0")
        }
    }
}

final class OpenWeightModelCatalogTests: XCTestCase {
    func testCatalogIsNotEmpty() {
        XCTAssertFalse(OpenWeightModelCatalog.models.isEmpty)
    }

    func testSortedBySuitabilityReturnsAllModels() {
        let availableGB = Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824
        let sorted = OpenWeightModelCatalog.sortedBySuitability(availableMemoryGB: availableGB)
        XCTAssertEqual(sorted.count, OpenWeightModelCatalog.models.count)
    }

    func testSuitabilityScoreInRange() {
        let availableGB = Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824
        for model in OpenWeightModelCatalog.models {
            let s = model.suitability(availableMemoryGB: availableGB)
            XCTAssertGreaterThanOrEqual(s.score, 0)
            XCTAssertLessThanOrEqual(s.score, 1)
        }
    }

    func testGemmaIsFirstOrHighlyRanked() {
        let availableGB = Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824
        let sorted = OpenWeightModelCatalog.sortedBySuitability(availableMemoryGB: availableGB)
        // Gemma 3 1B deve estar entre os mais adequados (memória pequena).
        let gemma1b = sorted.first { $0.ollamaTag == "gemma3:1b" }
        XCTAssertNotNil(gemma1b)
        XCTAssertTrue(gemma1b!.suitability(availableMemoryGB: availableGB).fitsComfortably)
    }
}
