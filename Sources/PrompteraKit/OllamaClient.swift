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
            return L10n.t("URL do servidor Ollama inválida.")
        case .connectionFailed(let details):
            return L10n.t("Não foi possível conectar ao Ollama (%@). Verifique se o serviço está ativo (execute 'ollama serve').", details)
        case .serverError(let code, let msg):
            return L10n.t("Erro no servidor Ollama [%d]: %@", code, msg)
        case .decodingError(let msg):
            return L10n.t("Erro ao processar resposta do Ollama: %@", msg)
        case .modelNotFound(let name):
            return L10n.t("Modelo '%@' não encontrado no Ollama local.", name)
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

    /// Progresso de download de um modelo via `api/pull`.
    public struct PullProgress: Sendable, Equatable {
        public let status: String
        public let completed: Int64
        public let total: Int64?
        /// Fração concluída (0.0 ... 1.0). 1.0 quando o download/extração termina.
        public let fraction: Double
    }

    private struct PullChunk: Decodable {
        let status: String
        let completed: Int64
        let total: Int64?
        let digest: String?
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
        temperature: Double = 0.7,
        format: String? = nil  // ex: "json" para forçar saída estruturada
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
                if let format, !format.isEmpty {
                    payload["format"] = format
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
        temperature: Double = 0.7,
        format: String? = nil
    ) async throws -> String {
        var accumulated = ""
        for try await token in streamGenerate(model: model, prompt: prompt, system: system, temperature: temperature, format: format) {
            accumulated += token
        }
        return accumulated
    }

    // MARK: - Model management (pull / install)

    /// Verifica se um modelo já está instalado no Ollama local (exato ou com tag).
    public func isModelInstalled(_ name: String) async -> Bool {
        do {
            let models = try await fetchAvailableModels()
            return models.contains { $0.name == name || $0.name.hasPrefix(name + ":") }
        } catch {
            return false
        }
    }

    /// Faz o pull (download) de um modelo via `api/pull`, emitindo progresso.
    /// Encerra o stream quando o status chega a "success" ou falha.
    public func pullModel(named model: String) -> AsyncThrowingStream<PullProgress, Error> {
        return AsyncThrowingStream { continuation in
            let task = Task {
                let url = baseURL.appendingPathComponent("api/pull")
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                let payload: [String: Any] = ["model": model, "stream": true]
                request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

                do {
                    let (asyncBytes, response) = try await session.bytes(for: request)

                    guard let http = response as? HTTPURLResponse else {
                        continuation.finish(throwing: OllamaError.connectionFailed("Sem resposta HTTP no pull do modelo"))
                        return
                    }
                    guard (200...299).contains(http.statusCode) else {
                        continuation.finish(throwing: OllamaError.serverError(http.statusCode, "Falha no pull do modelo"))
                        return
                    }

                    let decoder = JSONDecoder()
                    for try await line in asyncBytes.lines {
                        guard !Task.isCancelled else { break }
                        guard !line.isEmpty else { continue }

                        if let chunk = try? decoder.decode(PullChunk.self, from: Data(line.utf8)) {
                            let total = chunk.total ?? 0
                            var fraction: Double
                            if total > 0 {
                                fraction = Double(chunk.completed) / Double(total)
                            } else if chunk.status.lowercased().contains("success") {
                                fraction = 1.0
                            } else {
                                fraction = 0.0
                            }
                            fraction = min(max(fraction, 0.0), 1.0)

                            continuation.yield(PullProgress(
                                status: chunk.status,
                                completed: chunk.completed,
                                total: chunk.total,
                                fraction: fraction
                            ))

                            if chunk.status.lowercased() == "success" {
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
}
