import XCTest
import Foundation
import Network
@testable import PrompteraKit

final class MockOllamaServer {
    private let listener: NWListener
    private var shouldSucceed = true
    private var responseDelay: TimeInterval = 0
    private var modelsResponse: String = """
    {"models": [{"name": "qwen2.5-coder:7b", "size": 7516192768, "modified_at": "2024-01-01T00:00:00Z"}, {"name": "llama3.1:latest", "size": 4946330112, "modified_at": "2024-01-01T00:00:00Z"}]}
    """

    init(port: UInt16 = 0) throws {
        let parameters = NWParameters.tcp
        listener = try NWListener(using: parameters, on: NWEndpoint.Port(rawValue: port)!)
    }

    var port: UInt16 {
        listener.port?.rawValue ?? 0
    }

    var baseURL: URL {
        URL(string: "http://127.0.0.1:\(port)")!
    }

    func start() {
        listener.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                print("Mock Ollama server ready on port \(self?.port ?? 0)")
            case .failed(let error):
                print("Mock Ollama server failed: \(error)")
            default:
                break
            }
        }

        listener.newConnectionHandler = { [weak self] connection in
            self?.handleConnection(connection)
        }

        listener.start(queue: .global())
    }

    func stop() {
        listener.cancel()
    }

    func setModelsResponse(_ json: String) {
        modelsResponse = json
    }

    func setShouldSucceed(_ succeed: Bool) {
        shouldSucceed = succeed
    }

    func setResponseDelay(_ delay: TimeInterval) {
        responseDelay = delay
    }

    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: .global())

        func receiveHandler(_ conn: NWConnection) {
            conn.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
                if let data = data, !data.isEmpty {
                    let request = String(data: data, encoding: .utf8) ?? ""
                    let response = self?.buildResponse(for: request) ?? ""
                    let responseData = response.data(using: .utf8)!

                    if let delay = self?.responseDelay, delay > 0 {
                        Thread.sleep(forTimeInterval: delay)
                    }

                    conn.send(content: responseData, completion: .contentProcessed { _ in
                        conn.cancel()
                    })
                }
                if isComplete || error != nil {
                    conn.cancel()
                } else {
                    receiveHandler(conn)
                }
            }
        }

        receiveHandler(connection)
    }

    private func buildResponse(for request: String) -> String {
        let lines = request.components(separatedBy: "\r\n")
        let firstLine = lines.first ?? ""
        let path = firstLine.components(separatedBy: " ")[safe: 1] ?? ""

        if path == "/api/tags" {
            return httpResponse(status: 200, body: modelsResponse)
        } else if path == "/api/generate" {
            if shouldSucceed {
                let streamingResponse = """
                {"response": "Test ", "done": false}
                {"response": "Master ", "done": false}
                {"response": "Prompt ", "done": false}
                {"response": "Response", "done": true}
                """
                return httpResponse(status: 200, body: streamingResponse, contentType: "application/x-ndjson")
            } else {
                return httpResponse(status: 500, body: "{\"error\": \"Internal server error\"}")
            }
        } else {
            return httpResponse(status: 404, body: "Not Found")
        }
    }

    private func httpResponse(status: Int, body: String, contentType: String = "application/json") -> String {
        let statusText = status == 200 ? "OK" : (status == 404 ? "Not Found" : "Internal Server Error")
        return """
        HTTP/1.1 \(status) \(statusText)\r
        Content-Type: \(contentType)\r
        Content-Length: \(body.utf8.count)\r
        Connection: close\r
        \r
        \(body)
        """
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

@MainActor
final class E2EIntegrationTests: XCTestCase {
    var mockServer: MockOllamaServer!
    var client: OllamaClient!
    var harness: PromptHarness!
    var state: PrompteraState!

    override func setUp() async throws {
        try await super.setUp()
        mockServer = try MockOllamaServer()
        mockServer.start()
        
        // Wait for server to be ready
        try await Task.sleep(nanoseconds: 100_000_000)
        
        client = OllamaClient(baseURL: mockServer.baseURL)
        harness = PromptHarness(ollamaClient: client)
        state = PrompteraState(ollamaClient: client)
    }

    override func tearDown() async throws {
        mockServer?.stop()
        state?.cancelGeneration()
        state = nil
        harness = nil
        client = nil
        mockServer = nil
        try await super.tearDown()
    }

    func testFullHarnessFlowWithMockServer() async throws {
        // Given: Mock server with models
        mockServer.setModelsResponse("""
        {"models": [{"name": "test-model:latest", "size": 1000000000, "modified_at": "2024-01-01T00:00:00Z"}]}
        """)

        // When: Refresh models
        await state.refreshModels()
        
        // Give time for any async operations
        try await Task.sleep(nanoseconds: 100_000_000)

        // Then: Models loaded
        XCTAssertTrue(state.isOllamaConnected)
        XCTAssertEqual(state.availableModels.count, 1)
        // Model selection picks from available models
        XCTAssertFalse(state.selectedModel.isEmpty, "Selected model should not be empty: \(state.selectedModel)")
        XCTAssertTrue(state.availableModels.contains { $0.name == state.selectedModel },
            "Selected model '\(state.selectedModel)' should be in available models: \(state.availableModels.map { $0.name })")

        // When: Generate prompt
        state.inputText = "Create a REST API in Swift"
        state.selectedMode = .standard
        state.selectedPreset = HarnessPreset.presets[0]

        var finalOutput = ""

        state.generatePrompt()

        // Wait for generation to complete
        for _ in 0..<100 {
            try await Task.sleep(nanoseconds: 100_000_000)
            if !state.isGenerating {
                finalOutput = state.outputText
                break
            }
        }

        // Then: Output generated
        XCTAssertFalse(state.isGenerating)
        XCTAssertTrue(finalOutput.contains("Test"))
        XCTAssertTrue(finalOutput.contains("Master"))
        XCTAssertTrue(finalOutput.contains("Prompt"))
        XCTAssertTrue(finalOutput.contains("Response"))
    }

    func testIterativeLoopModeWithMockServer() async throws {
        mockServer.setModelsResponse("""
        {"models": [{"name": "test-model", "size": 1000000000, "modified_at": "2024-01-01T00:00:00Z"}]}
        """)

        await state.refreshModels()

        state.inputText = "Write a test"
        state.selectedMode = .iterativeLoop

        state.generatePrompt()

        for _ in 0..<100 {
            try await Task.sleep(nanoseconds: 100_000_000)
            if !state.isGenerating { break }
        }

        XCTAssertFalse(state.isGenerating)
        XCTAssertTrue(state.outputText.contains("Test"))
    }

    func testModularTemplateModeWithMockServer() async throws {
        mockServer.setModelsResponse("""
        {"models": [{"name": "test-model", "size": 1000000000, "modified_at": "2024-01-01T00:00:00Z"}]}
        """)

        await state.refreshModels()

        state.inputText = "Create template"
        state.selectedMode = .modularTemplate

        state.generatePrompt()

        for _ in 0..<100 {
            try await Task.sleep(nanoseconds: 100_000_000)
            if !state.isGenerating { break }
        }

        XCTAssertFalse(state.isGenerating)
        XCTAssertTrue(state.outputText.contains("Test"))
    }

    func testErrorHandlingWhenOllamaUnavailable() async throws {
        // Models endpoint still works, but generate fails
        mockServer.setShouldSucceed(false)
        mockServer.setModelsResponse("""
        {"models": [{"name": "test-model", "size": 1000000000, "modified_at": "2024-01-01T00:00:00Z"}]}
        """)

        await state.refreshModels()

        // Models still load
        XCTAssertTrue(state.isOllamaConnected)
        XCTAssertEqual(state.availableModels.count, 1)

        // But generation fails
        state.inputText = "Test"
        state.generatePrompt()

        for _ in 0..<50 {
            try await Task.sleep(nanoseconds: 100_000_000)
            if !state.isGenerating { break }
        }

        XCTAssertFalse(state.isGenerating)
        XCTAssertNotNil(state.errorMessage)
        XCTAssertTrue(state.errorMessage?.contains("500") == true)
    }

    func testClipboardIntegrationE2E() async throws {
        mockServer.setModelsResponse("""
        {"models": [{"name": "test-model", "size": 1000000000, "modified_at": "2024-01-01T00:00:00Z"}]}
        """)

        await state.refreshModels()

        // Simulate clipboard content
        state.clipboardManager.copyToClipboard("Swift async/await example")

        // Use clipboard item
        state.useLatestClipboard()

        XCTAssertEqual(state.inputText, "Swift async/await example")

        // Generate from clipboard
        state.generatePrompt()

        for _ in 0..<100 {
            try await Task.sleep(nanoseconds: 100_000_000)
            if !state.isGenerating { break }
        }

        XCTAssertFalse(state.isGenerating)
        XCTAssertTrue(state.outputText.count > 0)
    }

    func testCopyOutputToClipboardE2E() async throws {
        mockServer.setModelsResponse("""
        {"models": [{"name": "test-model", "size": 1000000000, "modified_at": "2024-01-01T00:00:00Z"}]}
        """)

        await state.refreshModels()
        state.inputText = "Test"
        state.generatePrompt()

        for _ in 0..<100 {
            try await Task.sleep(nanoseconds: 100_000_000)
            if !state.isGenerating { break }
        }

        // Copy output
        state.copyOutput()

        XCTAssertTrue(state.copiedToast)
        XCTAssertEqual(state.clipboardManager.latestItem?.content, state.outputText)
    }

    func testMultipleModelsSelection() async throws {
        mockServer.setModelsResponse("""
        {"models": [
            {"name": "model-a", "size": 1000000000, "modified_at": "2024-01-01T00:00:00Z"},
            {"name": "model-b", "size": 2000000000, "modified_at": "2024-01-01T00:00:00Z"},
            {"name": "model-c", "size": 3000000000, "modified_at": "2024-01-01T00:00:00Z"}
        ]}
        """)

        await state.refreshModels()

        XCTAssertEqual(state.availableModels.count, 3)
        
        // Change model
        state.selectedModel = "model-b"
        XCTAssertEqual(state.selectedModel, "model-b")
    }

    func testPresetSelection() async throws {
        mockServer.setModelsResponse("""
        {"models": [{"name": "test-model", "size": 1000000000, "modified_at": "2024-01-01T00:00:00Z"}]}
        """)

        await state.refreshModels()

        // Test each preset
        for preset in HarnessPreset.presets {
            state.selectedPreset = preset
            state.inputText = "Test input"
            state.generatePrompt()

            for _ in 0..<50 {
                try await Task.sleep(nanoseconds: 100_000_000)
                if !state.isGenerating { break }
            }

            XCTAssertFalse(state.isGenerating)
            XCTAssertTrue(state.outputText.count > 0)
            state.outputText = ""
        }
    }

    func testCancelGeneration() async throws {
        mockServer.setModelsResponse("""
        {"models": [{"name": "test-model", "size": 1000000000, "modified_at": "2024-01-01T00:00:00Z"}]}
        """)
        mockServer.setResponseDelay(1.0) // Slow response

        await state.refreshModels()

        state.inputText = "Test"
        state.generatePrompt()

        // Cancel immediately
        try await Task.sleep(nanoseconds: 50_000_000)
        state.cancelGeneration()

        XCTAssertFalse(state.isGenerating)
        XCTAssertEqual(state.statusMessage, "Geração cancelada")
    }
}