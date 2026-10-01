import XCTest
@testable import PrompteraKit

final class OllamaClientTests: XCTestCase {
    var client: OllamaClient!

    override func setUp() {
        super.setUp()
        client = OllamaClient(baseURL: URL(string: "http://127.0.0.1:11434")!)
    }

    override func tearDown() {
        client = nil
        super.tearDown()
    }

    func testInitialization() async {
        XCTAssertNotNil(client)
        let url = await client.baseURL
        XCTAssertEqual(url.absoluteString, "http://127.0.0.1:11434")
    }

    func testSetBaseURL() async {
        let newURL = URL(string: "http://custom-host:11434")!
        await client.setBaseURL(newURL)

        let url = await client.baseURL
        XCTAssertEqual(url.absoluteString, "http://custom-host:11434")
    }

    func testOllamaErrorDescriptions() {
        let invalidURL = OllamaError.invalidURL
        let connectionFailed = OllamaError.connectionFailed("timeout")
        let serverError = OllamaError.serverError(500, "Internal Error")
        let decodingError = OllamaError.decodingError("malformed JSON")
        let modelNotFound = OllamaError.modelNotFound("missing-model")

        XCTAssertEqual(invalidURL.errorDescription, "URL do servidor Ollama inválida.")
        XCTAssertTrue(connectionFailed.errorDescription?.contains("timeout") == true)
        XCTAssertTrue(serverError.errorDescription?.contains("500") == true)
        XCTAssertTrue(decodingError.errorDescription?.contains("malformed JSON") == true)
        XCTAssertTrue(modelNotFound.errorDescription?.contains("missing-model") == true)
    }

    func testOllamaErrorLocalizedError() {
        let error = OllamaError.connectionFailed("test")
        XCTAssertNotNil(error.errorDescription)
    }
}

final class PromptHarnessTests: XCTestCase {
    var client: OllamaClient!
    var harness: PromptHarness!

    override func setUp() {
        super.setUp()
        client = OllamaClient(baseURL: URL(string: "http://127.0.0.1:11434")!)
        harness = PromptHarness(ollamaClient: client)
    }

    override func tearDown() {
        harness = nil
        client = nil
        super.tearDown()
    }

    func testBuildGenerationPromptStandardMode() async {
        let preset = HarnessPreset.presets[0]
        let (system, userPrompt) = await harness.buildGenerationPrompt(
            rawInput: "Create a REST API",
            preset: preset,
            mode: .standard
        )

        XCTAssertTrue(system.contains("Meta-Prompt Architect"))
        XCTAssertTrue(system.contains("CONCRETIZAÇÃO SEMÂNTICA"))
        XCTAssertTrue(userPrompt.contains("Create a REST API"))
        XCTAssertTrue(userPrompt.contains("MASTER PROMPT COM CONCRETIZAÇÃO"))
        XCTAssertTrue(userPrompt.contains("TABELA DE DES-ADJETIVAÇÃO"))
    }

    func testBuildGenerationPromptIterativeLoopMode() async {
        let preset = HarnessPreset.presets[0]
        let (system, userPrompt) = await harness.buildGenerationPrompt(
            rawInput: "Create a REST API",
            preset: preset,
            mode: .iterativeLoop
        )

        XCTAssertTrue(system.contains("Meta-Prompt Architect"))
        XCTAssertTrue(userPrompt.contains("Create a REST API"))
        XCTAssertTrue(userPrompt.contains("METODOLOGIA OXAIR APRIMORADA"))
        XCTAssertTrue(userPrompt.contains("ETAPA 1: Rascunho"))
        XCTAssertTrue(userPrompt.contains("ETAPA 2: Auditoria"))
        XCTAssertTrue(userPrompt.contains("ETAPA 3: Master Prompt Final"))
    }

    func testBuildGenerationPromptModularTemplateMode() async {
        let preset = HarnessPreset.presets[0]
        let (system, userPrompt) = await harness.buildGenerationPrompt(
            rawInput: "Create a REST API",
            preset: preset,
            mode: .modularTemplate
        )

        XCTAssertTrue(system.contains("Meta-Prompt Architect"))
        XCTAssertTrue(userPrompt.contains("Create a REST API"))
        XCTAssertTrue(userPrompt.contains("TEMPLATE PERPÉTUO"))
        XCTAssertTrue(userPrompt.contains("variáveis"))
    }

    func testBuildGenerationPromptUsesPresetGuidance() async {
        let codingPreset = HarnessPreset.presets.first { $0.id == "coding" }!
        let (_, userPrompt) = await harness.buildGenerationPrompt(
            rawInput: "Test input",
            preset: codingPreset,
            mode: .standard
        )

        XCTAssertTrue(userPrompt.contains(codingPreset.domainGuidance))
        XCTAssertTrue(userPrompt.contains(codingPreset.title))
    }

    func testHarnessExecutionEventTypes() {
        let stageEvent = HarnessExecutionEvent(type: .stageChanged("Test stage"))
        let tokenEvent = HarnessExecutionEvent(type: .tokenYielded("Test token"))
        let finishedEvent = HarnessExecutionEvent(type: .finished("Test result"))

        XCTAssertEqual("\(stageEvent.type)", "stageChanged(\"Test stage\")")
        XCTAssertEqual("\(tokenEvent.type)", "tokenYielded(\"Test token\")")
        XCTAssertEqual("\(finishedEvent.type)", "finished(\"Test result\")")
    }

    func testBaseSystemPromptContainsRequiredElements() {
        let systemPrompt = PromptHarness.baseSystemPrompt

        XCTAssertTrue(systemPrompt.contains("Meta-Prompt Architect"))
        XCTAssertTrue(systemPrompt.contains("CONCRETIZAÇÃO SEMÂNTICA"))
        XCTAssertTrue(systemPrompt.contains("DES-ADJETIVAÇÃO"))
        XCTAssertTrue(systemPrompt.contains("Papel & Persona"))
        XCTAssertTrue(systemPrompt.contains("Contexto & Objetivo Central"))
        XCTAssertTrue(systemPrompt.contains("Matriz de Concretização Semântica"))
        XCTAssertTrue(systemPrompt.contains("Instruções Prescritivas"))
        XCTAssertTrue(systemPrompt.contains("Guardrails & Anti-padrões"))
        XCTAssertTrue(systemPrompt.contains("Formato & Schema de Saída"))
        XCTAssertTrue(systemPrompt.contains("Placeholders Reutilizáveis"))
    }
}