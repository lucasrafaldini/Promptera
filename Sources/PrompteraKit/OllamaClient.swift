import Foundation

public enum OllamaError: LocalizedError {
    case invalidURL
    case connectionFailed(String)
    case serverError(Int, String)
    case decodingError(String)
    case modelNotFound(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "URL do servidor Ollama inválida."
        case .connectionFailed(let details):
            return "Não foi possível conectar ao Ollama (\(details)). Verifique se o serviço está ativo (execute 'ollama serve')."
        case .serverError(let code, let msg):
            return "Erro no servidor Ollama [\(code)]: \(msg)"
        case .decodingError(let msg):
            return "Erro ao processar resposta do Ollama: \(msg)"
        case .modelNotFound(let name):
            return "Modelo '\(name)' não encontrado no Ollama local."
        }
    }
}

public actor OllamaClient {
    public var baseURL: URL
    private let session: URLSession

    /// How long Ollama keeps the model resident in (unified) memory after a request.
    /// Longer than Ollama's 5-minute default so follow-up generations skip the model load.
    public static let keepAlive = "30m"

    private struct StreamChunk: Decodable {
        let response: String?
        let done: Bool?
    }
    
    public init(baseURL: URL = URL(string: "http://127.0.0.1:11434")!) {
        self.baseURL = baseURL
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 120
        config.timeoutIntervalForResource = 300
        self.session = URLSession(configuration: config)
    }
    
    public func setBaseURL(_ url: URL) {
        self.baseURL = url
    }
    
    public func isAvailable() async -> Bool {
        let url = baseURL.appendingPathComponent("api/tags")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 2.0
        do {
            let (_, response) = try await session.data(for: request)
            if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) {
                return true
            }
            return false
        } catch {
            return false
        }
    }
    
    public func fetchAvailableModels() async throws -> [OllamaModelInfo] {
        let url = baseURL.appendingPathComponent("api/tags")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw OllamaError.connectionFailed("Sem resposta HTTP válida")
            }
            guard (200...299).contains(http.statusCode) else {
                throw OllamaError.serverError(http.statusCode, String(data: data, encoding: .utf8) ?? "")
            }
            
            struct TagsResponse: Decodable {
                struct ModelEntry: Decodable {
                    let name: String
                    let size: Int64?
                    let modified_at: String?
                }
                let models: [ModelEntry]
            }
            
            let decoded = try JSONDecoder().decode(TagsResponse.self, from: data)
            return decoded.models.map { entry in
                OllamaModelInfo(name: entry.name, size: entry.size, modifiedAt: entry.modified_at)
            }
        } catch let err as OllamaError {
            throw err
        } catch {
            throw OllamaError.connectionFailed(error.localizedDescription)
        }
    }
    
    public func streamGenerate(
        model: String,
        prompt: String,
        system: String? = nil,
        temperature: Double = 0.7
    ) -> AsyncThrowingStream<String, Error> {
        return AsyncThrowingStream { continuation in
            let task = Task {
                let url = baseURL.appendingPathComponent("api/generate")
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                
                var payload: [String: Any] = [
                    "model": model,
                    "prompt": prompt,
                    "stream": true,
                    "keep_alive": OllamaClient.keepAlive,
                    "options": [
                        "temperature": temperature
                    ]
                ]
                if let system = system, !system.isEmpty {
                    payload["system"] = system
                }
                
                do {
                    request.httpBody = try JSONSerialization.data(withJSONObject: payload)
                    let (asyncBytes, response) = try await session.bytes(for: request)
                    
                    guard let http = response as? HTTPURLResponse else {
                        continuation.finish(throwing: OllamaError.connectionFailed("Sem resposta HTTP"))
                        return
                    }
                    guard (200...299).contains(http.statusCode) else {
                        continuation.finish(throwing: OllamaError.serverError(http.statusCode, "Falha na chamada"))
                        return
                    }
                    
                    let decoder = JSONDecoder()
                    for try await line in asyncBytes.lines {
                        guard !Task.isCancelled else { break }
                        guard !line.isEmpty else { continue }
                        
                        if let chunk = try? decoder.decode(StreamChunk.self, from: Data(line.utf8)) {
                            if let piece = chunk.response, !piece.isEmpty {
                                continuation.yield(piece)
                            }
                            if chunk.done == true {
                                break
                            }
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            
            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }
    
    /// Loads the model into memory ahead of time (an empty prompt makes Ollama load
    /// the weights and return immediately), so the first real generation starts fast.
    public func warmUp(model: String) async {
        let url = baseURL.appendingPathComponent("api/generate")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let payload: [String: Any] = ["model": model, "keep_alive": OllamaClient.keepAlive]
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        _ = try? await session.data(for: request)
    }
    
    public func generateComplete(
        model: String,
        prompt: String,
        system: String? = nil,
        temperature: Double = 0.7
    ) async throws -> String {
        var accumulated = ""
        for try await token in streamGenerate(model: model, prompt: prompt, system: system, temperature: temperature) {
            accumulated += token
        }
        return accumulated
    }
}
