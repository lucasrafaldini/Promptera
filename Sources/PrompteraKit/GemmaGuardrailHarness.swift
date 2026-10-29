import Foundation

// MARK: - Resultado da geração com Gemma

/// Resultado final do harness guardrail do Gemma.
/// O Master Prompt é produzido na língua do vendor (Inglês) por padrão,
/// com uma versão opcional em Português.
public struct GemmaGenerationResult: Sendable, Equatable {
    public let schema: GemmaMasterPromptSchema
    public let masterPromptEnglish: String      // Língua do vendor (target LLMs)
    public let masterPromptPortuguese: String?  // Versão opcional em PT-BR
    public let validationAttempts: Int          // Quantas tentativas foram necessárias
    public let wasRepaired: Bool                // true se houve auto-reparo de alucinação/erro
    public let modelUsed: String

    public init(
        schema: GemmaMasterPromptSchema,
        masterPromptEnglish: String,
        masterPromptPortuguese: String? = nil,
        validationAttempts: Int = 1,
        wasRepaired: Bool = false,
        modelUsed: String
    ) {
        self.schema = schema
        self.masterPromptEnglish = masterPromptEnglish
        self.masterPromptPortuguese = masterPromptPortuguese
        self.validationAttempts = validationAttempts
        self.wasRepaired = wasRepaired
        self.modelUsed = modelUsed
    }
}

/// Esquema rígido que o Gemma deve preencher. Todas as chaves são obrigatórias.
public struct GemmaMasterPromptSchema: Codable, Sendable, Equatable {
    public let role: String
    public let objective: String
    public let concretizationMatrix: [ConcretizationEntry]
    public let instructions: [String]
    public let guardrails: [String]
    public let negativeConstraints: [String]
    public let outputSchema: String
    public let placeholders: [String]

    public init(
        role: String,
        objective: String,
        concretizationMatrix: [ConcretizationEntry] = [],
        instructions: [String] = [],
        guardrails: [String] = [],
        negativeConstraints: [String] = [],
        outputSchema: String = "",
        placeholders: [String] = []
    ) {
        self.role = role
        self.objective = objective
        self.concretizationMatrix = concretizationMatrix
        self.instructions = instructions
        self.guardrails = guardrails
        self.negativeConstraints = negativeConstraints
        self.outputSchema = outputSchema
        self.placeholders = placeholders
    }
}

public struct ConcretizationEntry: Codable, Sendable, Equatable {
    public let vagueAdjective: String
    public let operationalMeaning: String
    public let concreteRule: String
    public let acceptanceMetric: String

    public init(
        vagueAdjective: String,
        operationalMeaning: String,
        concreteRule: String,
        acceptanceMetric: String
    ) {
        self.vagueAdjective = vagueAdjective
        self.operationalMeaning = operationalMeaning
        self.concreteRule = concreteRule
        self.acceptanceMetric = acceptanceMetric
    }
}

// MARK: - Erros do harness

public enum GemmaHarnessError: LocalizedError, Equatable, Sendable {
    case modelNotAvailable(String)
    case invalidJSON(String)
    case missingRequiredField(String)
    case emptyRequiredField(String)
    case hallucinationDetected(String)
    case maxRepairAttemptsExceeded(Int)
    case unexpectedResponse(String)

    public var errorDescription: String? {
        switch self {
        case .modelNotAvailable(let name):
            return L10n.t("Modelo Gemma '%@' não está disponível no Ollama local.", name)
        case .invalidJSON(let detail):
            return L10n.t("O Gemma retornou uma resposta fora do JSON esperado (%@).", detail)
        case .missingRequiredField(let field):
            return L10n.t("O Gemma omitiu o campo obrigatório '%@'.", field)
        case .emptyRequiredField(let field):
            return L10n.t("O Gemma deixou o campo obrigatório '%@' vazio.", field)
        case .hallucinationDetected(let detail):
            return L10n.t("Alucinação detectada no Gemma: %@.", detail)
        case .maxRepairAttemptsExceeded(let attempts):
            return L10n.t("O Gemma não conseguiu produzir um prompt válido após %d tentativas de reparo.", attempts)
        case .unexpectedResponse(let detail):
            return L10n.t("Resposta inesperada do Gemma: %@", detail)
        }
    }
}

// MARK: - Gemma Guardrail Harness

/// Harness dedicado ao Gemma (modelo pequeno).
///
/// Estratégia para evitar delírios, dado o tamanho reduzido do Gemma:
/// 1. Força saída estruturada em JSON via `format: "json"` do Ollama.
/// 2. System prompt em Inglês (língua do vendor) com instruções curtas e few-shot.
/// 3. Validação rígida do JSON (campos obrigatórios, não vazios, tipos corretos).
/// 4. Detecção de alucinação (tags de pensamento, marca de recusa, texto fora do JSON).
/// 5. Auto-reparo: reenvia com descrição do erro, até `maxRepairAttempts` vezes.
/// 6. Temperatura baixa (0.3) para saídas determinísticas.
public actor GemmaGuardrailHarness {
    private let ollamaClient: OllamaClient

    /// Número máximo de tentativas de auto-reparo quando o Gemma sai do esquema.
    public let maxRepairAttempts: Int

    /// Temperatura usada com o Gemma (baixa = menos criatividade = menos alucinação).
    public let temperature: Double = 0.3

    public init(ollamaClient: OllamaClient, maxRepairAttempts: Int = 3) {
        self.ollamaClient = ollamaClient
        self.maxRepairAttempts = maxRepairAttempts
    }

    // MARK: - System prompt (língua do vendor: Inglês)

    /// Instruções de sistema do Gemma. Escrito em Inglês porque o Gemma é um modelo
    /// de língua inglesa e responde muito mais fielmente a instruções em Inglês.
    /// O Master Prompt gerado também sai em Inglês (língua do vendor dos LLMs alvo).
    private static let systemPrompt = """
    You are the Promptera Gemma Guardrail Harness, a precise prompt-engineering specialist running on a small Gemma model.

    Your job: turn the user's raw need into a professional, production-ready MASTER PROMPT in ENGLISH (the vendor language of the target LLMs such as Claude, GPT, Gemini, Llama).

    STRICT RULES:
    1. You MUST reply with ONLY a single JSON object that matches the schema below.
    2. No markdown code fences, no thinking tags, no extra prose before or after the JSON.
    3. All field values must be in ENGLISH.
    4. Never refuse. Never say you cannot do this. Always produce the JSON.
    5. Be concrete. Ban vague adjectives: fast, clean, robust, scalable, secure, modern, elegant, simple, persuasive, complete, professional, intuitive.
       For every vague adjective, replace it with operational rules and a measurable acceptance criterion.

    REQUIRED JSON SCHEMA (exact keys, all required):
    {
      "role": "string - exact role and persona",
      "objective": "string - explicit mission and boundaries",
      "concretizationMatrix": [
        { "vagueAdjective": "string", "operationalMeaning": "string", "concreteRule": "string", "acceptanceMetric": "string" }
      ],
      "instructions": ["string", ...],
      "guardrails": ["string", ...],
      "negativeConstraints": ["string", ...],
      "outputSchema": "string - strict structural specification",
      "placeholders": ["string", ...]
    }

    FEW-SHOT EXAMPLE:
    User need: "I need a fast API to sync files."
    JSON:
    {
      "role": "Senior Backend Engineer",
      "objective": "Design a file-synchronization API with retry logic and structured logging",
      "concretizationMatrix": [
        { "vagueAdjective": "fast", "operationalMeaning": "p95 latency under 200ms for file-metadata endpoints", "concreteRule": "Use connection pooling, async I/O and batch metadata operations", "acceptanceMetric": "p95 latency <= 200ms under 100 concurrent requests" }
      ],
      "instructions": ["Authenticate every request", "Validate all input schemas", "Retry failed uploads with exponential backoff"],
      "guardrails": ["Never assume file formats", "Log every operation in structured JSON"],
      "negativeConstraints": ["Do not invent authentication schemes", "Do not use vague terms without metrics", "Do not skip input validation"],
      "outputSchema": "OpenAPI 3.0 with paths /sync and /status",
      "placeholders": ["{{SOURCE_DIR}}", "{{DEST_DIR}}", "{{RETRY_MAX_ATTEMPTS}}"]
    }
    """

    // MARK: - Execução

    public func executeHarnessStream(
        rawInput: String,
        preset: HarnessPreset,
        mode: HarnessMode,
        model: String,
        includePortugueseVersion: Bool = false
    ) -> AsyncThrowingStream<HarnessExecutionEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    continuation.yield(HarnessExecutionEvent(type: .stageChanged(L10n.t("Conectando ao Gemma local %@...", model))))

                    let available = await ollamaClient.isModelInstalled(model)
                    guard available else {
                        continuation.finish(throwing: GemmaHarnessError.modelNotAvailable(model))
                        return
                    }

                    continuation.yield(HarnessExecutionEvent(type: .stageChanged(L10n.t("Gerando JSON estruturado com o Gemma..."))))

                    let userPrompt = buildUserPrompt(rawInput: rawInput, preset: preset, mode: mode)

                    var fullJSON = ""
                    for try await token in await ollamaClient.streamGenerate(
                        model: model,
                        prompt: userPrompt,
                        system: Self.systemPrompt,
                        temperature: temperature,
                        format: "json"
                    ) {
                        guard !Task.isCancelled else { break }
                        fullJSON += token
                        continuation.yield(HarnessExecutionEvent(type: .tokenYielded(token)))
                    }

                    continuation.yield(HarnessExecutionEvent(type: .stageChanged(L10n.t("Validando e reparando saída do Gemma..."))))

                    let result = try await generateWithRepair(
                        rawJSON: fullJSON,
                        model: model,
                        includePortugueseVersion: includePortugueseVersion
                    )

                    let finalPrompt = renderMasterPrompt(result: result, includePortuguese: includePortugueseVersion)

                    continuation.yield(HarnessExecutionEvent(type: .finished(finalPrompt)))
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

    /// Gera com auto-reparo: valida o JSON, e se inválido, reenvia com correção até o limite.
    private func generateWithRepair(
        rawJSON: String,
        model: String,
        includePortugueseVersion: Bool
    ) async throws -> GemmaGenerationResult {
        var currentJSON = sanitizeJSON(rawJSON)
        var attempts = 1
        var wasRepaired = false

        while true {
            do {
                let schema = try parseJSON(currentJSON)
                let portugueseSchema: GemmaMasterPromptSchema?
                if includePortugueseVersion {
                    portugueseSchema = try await translateSchemaToPortuguese(schema: schema, model: model)
                } else {
                    portugueseSchema = nil
                }
                return GemmaGenerationResult(
                    schema: schema,
                    masterPromptEnglish: renderSchema(schema),
                    masterPromptPortuguese: portugueseSchema.map { renderSchema($0) },
                    validationAttempts: attempts,
                    wasRepaired: wasRepaired,
                    modelUsed: model
                )
            } catch let error as GemmaHarnessError {
                if attempts >= maxRepairAttempts {
                    throw GemmaHarnessError.maxRepairAttemptsExceeded(maxRepairAttempts)
                }
                wasRepaired = true
                attempts += 1
                currentJSON = try await repairJSON(currentJSON, error: error, model: model)
            } catch {
                throw error
            }
        }
    }

    func parseJSON(_ text: String) throws -> GemmaMasterPromptSchema {
        // Detecção de alucinação: recusa explícita no texto bruto (antes de extrair o bloco JSON),
        // pois o texto de recusa fica fora do JSON e seria descartado pela extração.
        let rawLower = text.lowercased()
        let refusalKeywords = ["não consigo", "i cannot", "i'm sorry", "desculpe", "não posso", "as an ai"]
        if refusalKeywords.contains(where: rawLower.contains) {
            throw GemmaHarnessError.hallucinationDetected("resposta de recusa em vez de JSON")
        }

        let cleaned = sanitizeJSON(text)
        let lower = cleaned.lowercased()
        if lower.contains("<thinking>") || lower.contains("<|") {
            // Tags de pensamento são removidas pelo sanitizeJSON, mas se permanecerem
            // sinaliza que o modelo desviou do contrato de JSON.
            throw GemmaHarnessError.hallucinationDetected("tags de pensamento detectadas")
        }

        guard let data = cleaned.data(using: .utf8) else {
            throw GemmaHarnessError.invalidJSON("não foi possível converter para dados UTF-8")
        }

        let decoder = JSONDecoder()
        do {
            let schema = try decoder.decode(GemmaMasterPromptSchema.self, from: data)
            try validateSchema(schema)
            return schema
        } catch let decError as DecodingError {
            throw GemmaHarnessError.invalidJSON(decError.localizedDescription)
        } catch let err as GemmaHarnessError {
            throw err
        } catch {
            throw GemmaHarnessError.invalidJSON(error.localizedDescription)
        }
    }

    func validateSchema(_ schema: GemmaMasterPromptSchema) throws {
        if schema.role.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw GemmaHarnessError.emptyRequiredField("role")
        }
        if schema.objective.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw GemmaHarnessError.emptyRequiredField("objective")
        }
        if schema.instructions.isEmpty {
            throw GemmaHarnessError.missingRequiredField("instructions")
        }
        if schema.guardrails.isEmpty {
            throw GemmaHarnessError.missingRequiredField("guardrails")
        }
        if schema.outputSchema.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw GemmaHarnessError.missingRequiredField("outputSchema")
        }
        for (index, entry) in schema.concretizationMatrix.enumerated() {
            if entry.vagueAdjective.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
               entry.operationalMeaning.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
               entry.concreteRule.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
               entry.acceptanceMetric.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                throw GemmaHarnessError.emptyRequiredField("concretizationMatrix[\(index)]")
            }
        }
    }

    /// Tradução opcional do esquema para Português (segunda passagem no Gemma).
    private func translateSchemaToPortuguese(schema: GemmaMasterPromptSchema, model: String) async throws -> GemmaMasterPromptSchema {
        let translateSystem = """
        You are a professional technical translator. Translate the following JSON schema fields from English to Brazilian Portuguese.
        Reply with ONLY a single JSON object using the same keys. Do not translate the {{placeholders}}. Keep JSON valid.
        """
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let sourceJSON = (try? String(data: encoder.encode(schema), encoding: .utf8)) ?? "{}"

        let userPrompt = """
        Translate to Brazilian Portuguese:
        \(sourceJSON)
        """

        var translated = ""
        for try await token in await ollamaClient.streamGenerate(
            model: model,
            prompt: userPrompt,
            system: translateSystem,
            temperature: 0.3,
            format: "json"
        ) {
            guard !Task.isCancelled else { break }
            translated += token
        }

        let cleaned = sanitizeJSON(translated)
        guard let data = cleaned.data(using: .utf8) else {
            // Se a tradução falhar, seguimos só com o inglês.
            return schema
        }
        return (try? JSONDecoder().decode(GemmaMasterPromptSchema.self, from: data)) ?? schema
    }

    /// Reenvia para o Gemma com a descrição do erro, pedindo correção do JSON.
    private func repairJSON(_ invalidJSON: String, error: GemmaHarnessError, model: String) async throws -> String {
        let repairSystem = """
        You are a JSON repair assistant. The previous JSON output was invalid.
        Reply with ONLY a single corrected JSON object matching the required schema. No extra text.
        """
        let repairPrompt = """
        PREVIOUS INVALID OUTPUT:
        \(invalidJSON)

        ERROR TO FIX:
        \(error.errorDescription ?? "unknown error")

        Return ONLY the corrected JSON object.
        """

        var repaired = ""
        for try await token in await ollamaClient.streamGenerate(
            model: model,
            prompt: repairPrompt,
            system: repairSystem,
            temperature: 0.3,
            format: "json"
        ) {
            guard !Task.isCancelled else { break }
            repaired += token
        }
        return sanitizeJSON(repaired)
    }

    func sanitizeJSON(_ text: String) -> String {
        var result = text
        // Remove blocos de markdown ```json ... ```
        result = result.replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
        // Remove tags de pensamento (NSRegularExpression porque .dotMatchesLineSeparators
        // não é uma opção de NSString.CompareOptions).
        if let regex = try? NSRegularExpression(pattern: "<thinking>.*?</thinking>|<\\|.*?\\|>", options: [.dotMatchesLineSeparators]) {
            result = regex.stringByReplacingMatches(
                in: result,
                range: NSRange(result.startIndex..., in: result),
                withTemplate: ""
            )
        }
        // Extrai o maior bloco entre a primeira '{' e o último '}' (tolerância a texto ao redor).
        if let first = result.firstIndex(of: "{"),
           let last = result.lastIndex(of: "}"),
           first < last {
            result = String(result[first...last])
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Montagem do prompt de usuário

    private func buildUserPrompt(rawInput: String, preset: HarnessPreset, mode: HarnessMode) -> String {
        var prompt = """
        [USER NEED / RAW INPUT]
        """
        prompt += """
        \"\"\"
        \(rawInput.trimmingCharacters(in: .whitespacesAndNewlines))
        \"\"\"

        [DOMAIN GUIDANCE: \(preset.title)]
        \(preset.domainGuidance)

        [MODE]
        \(modeDescription(mode))

        [TASK]
        Produce a professional Master Prompt in ENGLISH based on the user need above.
        Follow the required JSON schema exactly. Replace every vague adjective with operational rules and measurable acceptance criteria.
        All values in ENGLISH.
        """
        return prompt
    }

    private func modeDescription(_ mode: HarnessMode) -> String {
        switch mode {
        case .standard:
            return "Direct Master Prompt: a single structured, production-ready prompt."
        case .iterativeLoop:
            return "Oxair loop: draft, audit vague adjectives and hidden assumptions, then deliver the hardened Master Prompt."
        case .modularTemplate:
            return "Reusable template with {{placeholders}} and a fill-in guide."
        }
    }

    // MARK: - Renderização do Master Prompt (língua do vendor: Inglês)

    private func renderMasterPrompt(result: GemmaGenerationResult, includePortuguese: Bool) -> String {
        var md = ""
        md += "# MASTER PROMPT (English — vendor language)\n\n"
        md += renderSchema(result.schema)
        if let pt = result.masterPromptPortuguese, includePortuguese {
            md += "\n\n---\n\n# MASTER PROMPT (Português — versão opcional)\n\n"
            md += pt
        }
        md += "\n\n> Generated by Promptera Gemma Guardrail Harness. "
        if result.wasRepaired {
            md += "Auto-reparo ativado após \(result.validationAttempts) tentativa(s). "
        }
        md += "Modelo: \(result.modelUsed)."
        return md
    }

    func renderSchema(_ schema: GemmaMasterPromptSchema) -> String {
        var md = ""
        md += "## ROLE & PERSONA\n\(schema.role)\n\n"
        md += "## CONTEXT & OBJECTIVE\n\(schema.objective)\n\n"

        if !schema.concretizationMatrix.isEmpty {
            md += "## SEMANTIC CONCRETIZATION MATRIX (De-adjectivization)\n"
            md += "| Vague term | Operational meaning | Concrete rule | Acceptance metric |\n"
            md += "|---|---|---|---|\n"
            for entry in schema.concretizationMatrix {
                md += "| \(escapeTable(entry.vagueAdjective)) | \(escapeTable(entry.operationalMeaning)) | \(escapeTable(entry.concreteRule)) | \(escapeTable(entry.acceptanceMetric)) |\n"
            }
            md += "\n"
        }

        md += "## PRESCRIPTIVE EXECUTION INSTRUCTIONS\n"
        for (index, instruction) in schema.instructions.enumerated() {
            md += "\(index + 1). \(instruction)\n"
        }
        md += "\n"

        md += "## GUARDRAILS & NEGATIVE CONSTRAINTS\n"
        for g in schema.guardrails {
            md += "- \(g)\n"
        }
        for n in schema.negativeConstraints {
            md += "- \(n)\n"
        }
        md += "\n"

        md += "## OUTPUT SCHEMA\n\(schema.outputSchema)\n\n"

        if !schema.placeholders.isEmpty {
            md += "## REUSABLE PLACEHOLDERS\n"
            for p in schema.placeholders {
                md += "- \(p)\n"
            }
            md += "\n"
        }

        return md
    }

    private func escapeTable(_ text: String) -> String {
        text.replacingOccurrences(of: "|", with: "\\|")
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
