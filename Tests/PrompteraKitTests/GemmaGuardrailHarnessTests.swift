import XCTest
@testable import PrompteraKit

final class GemmaGuardrailHarnessTests: XCTestCase {
    var harness: GemmaGuardrailHarness!

    override func setUp() {
        super.setUp()
        let client = OllamaClient(baseURL: URL(string: "http://127.0.0.1:11434")!)
        harness = GemmaGuardrailHarness(ollamaClient: client, maxRepairAttempts: 3)
    }

    override func tearDown() {
        harness = nil
        super.tearDown()
    }

    func testSanitizeJSONRemovesMarkdownFences() async {
        let raw = "```json\n{\"role\":\"Engineer\"}\n```"
        let cleaned = await harness.sanitizeJSON(raw)
        XCTAssertEqual(cleaned, "{\"role\":\"Engineer\"}")
    }

    func testSanitizeJSONRemovesThinkingTags() async {
        let raw = "<thinking>pensando aqui</thinking>{\"role\":\"Engineer\"}"
        let cleaned = await harness.sanitizeJSON(raw)
        XCTAssertFalse(cleaned.contains("<thinking>"))
        XCTAssertTrue(cleaned.contains("\"role\":\"Engineer\""))
    }

    func testSanitizeJSONExtractsJSONBlockFromSurroundingText() async {
        let raw = "Aqui está o JSON: {\"role\":\"X\", \"objective\": \"Y\"} fim."
        let cleaned = await harness.sanitizeJSON(raw)
        XCTAssertEqual(cleaned, "{\"role\":\"X\", \"objective\": \"Y\"}")
    }

    func testParseValidJSON() async throws {
        let json = """
        {
          "role": "Senior Backend Engineer",
          "objective": "Design an API",
          "concretizationMatrix": [],
          "instructions": ["Authenticate"],
          "guardrails": ["Validate input"],
          "negativeConstraints": ["Do not assume"],
          "outputSchema": "OpenAPI 3.0",
          "placeholders": ["{{BASE_URL}}"]
        }
        """
        let schema = try await harness.parseJSON(json)
        XCTAssertEqual(schema.role, "Senior Backend Engineer")
        XCTAssertEqual(schema.objective, "Design an API")
        XCTAssertEqual(schema.instructions, ["Authenticate"])
        XCTAssertEqual(schema.placeholders, ["{{BASE_URL}}"])
    }

    func testParseMissingRequiredFieldThrows() async {
        let json = """
        {
          "role": "Engineer",
          "objective": "Design",
          "concretizationMatrix": [],
          "instructions": [],
          "guardrails": ["Validate input"],
          "negativeConstraints": [],
          "outputSchema": "OpenAPI 3.0",
          "placeholders": []
        }
        """
        do {
            _ = try await harness.parseJSON(json)
            XCTFail("esperava erro de campo obrigatório ausente")
        } catch let error as GemmaHarnessError {
            XCTAssertEqual(error, .missingRequiredField("instructions"))
        } catch {
            XCTFail("erro inesperado: \(error)")
        }
    }

    func testParseEmptyRequiredFieldThrows() async {
        let json = """
        {
          "role": "",
          "objective": "Design",
          "concretizationMatrix": [],
          "instructions": ["Authenticate"],
          "guardrails": ["Validate input"],
          "negativeConstraints": ["Do not assume"],
          "outputSchema": "OpenAPI 3.0",
          "placeholders": []
        }
        """
        do {
            _ = try await harness.parseJSON(json)
            XCTFail("esperava erro de campo obrigatório vazio")
        } catch let error as GemmaHarnessError {
            XCTAssertEqual(error, .emptyRequiredField("role"))
        } catch {
            XCTFail("erro inesperado: \(error)")
        }
    }

    func testParseRefusalIsHallucination() async {
        let raw = "I cannot fulfill this request. {\"role\":\"X\"}"
        do {
            _ = try await harness.parseJSON(raw)
            XCTFail("esperava erro de alucinação/recusa")
        } catch let error as GemmaHarnessError {
            XCTAssertEqual(error, .hallucinationDetected("resposta de recusa em vez de JSON"))
        } catch {
            XCTFail("erro inesperado: \(error)")
        }
    }

    func testRenderSchemaContainsAllSections() async {
        let schema = GemmaMasterPromptSchema(
            role: "Senior Engineer",
            objective: "Build an API",
            concretizationMatrix: [
                ConcretizationEntry(
                    vagueAdjective: "fast",
                    operationalMeaning: "p95 < 200ms",
                    concreteRule: "use async IO",
                    acceptanceMetric: "p95 <= 200ms"
                )
            ],
            instructions: ["Authenticate", "Validate input"],
            guardrails: ["Never assume format"],
            negativeConstraints: ["Do not invent auth"],
            outputSchema: "OpenAPI 3.0",
            placeholders: ["{{BASE_URL}}"]
        )
        let rendered = await harness.renderSchema(schema)

        XCTAssertTrue(rendered.contains("ROLE & PERSONA"))
        XCTAssertTrue(rendered.contains("CONTEXT & OBJECTIVE"))
        XCTAssertTrue(rendered.contains("SEMANTIC CONCRETIZATION MATRIX"))
        XCTAssertTrue(rendered.contains("PRESCRIPTIVE EXECUTION INSTRUCTIONS"))
        XCTAssertTrue(rendered.contains("GUARDRAILS & NEGATIVE CONSTRAINTS"))
        XCTAssertTrue(rendered.contains("OUTPUT SCHEMA"))
        XCTAssertTrue(rendered.contains("REUSABLE PLACEHOLDERS"))
        XCTAssertTrue(rendered.contains("{{BASE_URL}}"))
        XCTAssertTrue(rendered.contains("p95 <= 200ms"))
    }

    func testGemmaHarnessErrorDescriptions() async {
        let errors: [GemmaHarnessError] = [
            .modelNotAvailable("gemma3:1b"),
            .invalidJSON("bad"),
            .missingRequiredField("role"),
            .emptyRequiredField("objective"),
            .hallucinationDetected("thinking tags"),
            .maxRepairAttemptsExceeded(3),
            .unexpectedResponse("hi")
        ]
        for error in errors {
            let description = error.errorDescription
            XCTAssertNotNil(description)
            XCTAssertFalse(description!.isEmpty)
        }
        XCTAssertEqual(GemmaHarnessError.modelNotAvailable("gemma3:1b").errorDescription,
                       L10n.t("Modelo Gemma '%@' não está disponível no Ollama local.", "gemma3:1b"))
    }
}
