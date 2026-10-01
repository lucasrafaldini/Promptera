import Foundation

public struct HarnessExecutionEvent: Sendable {
    public enum EventType: Sendable {
        case stageChanged(String)
        case tokenYielded(String)
        case finished(String)
    }
    public let type: EventType
}

public actor PromptHarness {
    private let ollamaClient: OllamaClient
    
    public init(ollamaClient: OllamaClient) {
        self.ollamaClient = ollamaClient
    }
    
    // System instructions for the Meta-Prompt Architect with Semantic Concretization Engine
    public static let baseSystemPrompt = """
    Você é o Meta-Prompt Architect do Promptera, especialista em engenharia de prompts de alta precisão e semântica computacional.
    Sua missão é transformar ideias brutas, notas ou códigos em MASTER PROMPTS de nível profissional, blindados, reutilizáveis e cirurgicamente explícitos.
    
    =============================================================================
    PROTOCOLO CENTRAL: CONCRETIZAÇÃO SEMÂNTICA & DES-ADJETIVAÇÃO OBRIGATÓRIA
    =============================================================================
    O maior causador de falhas, alucinações e superficialidade em IAs são ADJETIVOS VAGOS e SUBJETIVOS.
    Exemplos de adjetivos proibidos em sua forma pura:
    - "rápido", "limpo", "robusto", "escalável", "seguro", "moderno", "elegante",
      "didático", "simples", "persuasivo", "completo", "intuitivo", "profissional".
    
    REGRA DE OURO DA CONCRETIZAÇÃO:
    Para CADA adjetivo, qualificador ou expectativa qualitativa presente na ideia do usuário, você DEVE desconstruí-lo na língua em 3 camadas operacionais inequívocas:
    1. **Significado Operacional:** O que exatamente esse termo significa neste contexto técnico/específico?
    2. **Mecanismo & Regras Concretas:** Quais ações prescritivas, padrões arquiteturais ou técnicas gramaticais executam esse adjetivo?
    3. **Critério de Aceite Falsificável (Métrica):** Qual teste, métrica quantitativa ou evidência comprova de forma objetiva que a condição foi atendida?
    
    Todo Master Prompt de excelência gerado deve conter:
    1. **Papel & Persona (Role):** Especialidade exata, profundidade e postura.
    2. **Contexto & Objetivo Central (Objective):** Declaração explícita de missão e limites.
    3. **Matriz de Concretização Semântica (Des-adjetivação):** Tabela mapeando cada adjetivo vago para regras e métricas operacionais concretas.
    4. **Instruções Prescritivas Passo a Passo (Instructions):** Usando verbos de ação imperativos, sem ambiguidades.
    5. **Guardrails & Anti-padrões Estritos (Negative Constraints):** O que a IA NUNCA deve fazer, palavras proibidas e armadilhas a evitar.
    6. **Formato & Schema de Saída (Output Schema):** Especificação estrutural rigorosa (seções, JSON schema, blocos de código).
    7. **Placeholders Reutilizáveis:** Onde couber, sintaxe `{{variavel}}`.
    
    Responda em Português claro, assertivo e técnico (ou no idioma de entrada se for explicitamente em Inglês).
    """
    
    public func buildGenerationPrompt(
        rawInput: String,
        preset: HarnessPreset,
        mode: HarnessMode
    ) -> (system: String, userPrompt: String) {
        let system = PromptHarness.baseSystemPrompt
        
        var prompt = """
        [DIRETIVA DE DOMÍNIO: \(preset.title)]
        Orientação de Domínio: \(preset.domainGuidance)
        
        [ENTRADA ORIGINAL DO USUÁRIO / CLIPBOARD]:
        \"\"\"
        \(rawInput.trimmingCharacters(in: .whitespacesAndNewlines))
        \"\"\"
        
        [DIRETRIZ DE DES-ADJETIVAÇÃO]:
        Identifique todos os adjetivos implícitos ou explícitos na entrada acima (por exemplo: se o usuário pediu 'código bom', 'texto chamativo', 'api rápida', 'explicação simples').
        Concretize e substitua cada adjetivo vago por especificações técnicas e linguísticas explícitas.
        """
        
        switch mode {
        case .standard:
            prompt += """
            
            [TAREFA - MASTER PROMPT COM CONCRETIZAÇÃO]:
            Com base na entrada e nas diretivas, elabore o Master Prompt definitivo pronto para ser copiado e colado em um modelo de ponta (Claude, ChatGPT, Gemini, Llama).
            
            ESTRUTURA OBRIGATÓRIA DO MASTER PROMPT:
            # ROLE & PERSONA
            # CONTEXTO & MISSÃO
            # TABELA DE DES-ADJETIVAÇÃO & CRITÉRIOS OPERACIONAIS (Mapeie cada adjetivo para: Significado Técnico | Regra Estrita | Métrica de Aceite)
            # INSTRUÇÕES PRESCRITIVAS DE EXECUÇÃO
            # GUARDRAILS & RESTRIÇÕES NEGATIVAS
            # ESQUEMA DE SAÍDA (OUTPUT SCHEMA)
            # PLACEHOLDERS REUTILIZÁVEIS (se aplicável)
            
            Inicie diretamente com o Master Prompt, pronto para uso.
            """
            
        case .modularTemplate:
            prompt += """
            
            [TAREFA - HARNESS DE TEMPLATE PERPÉTUO COM DES-ADJETIVAÇÃO]:
            Crie um Template de Prompt Reutilizável com variáveis `{{...}}`.
            
            Inclua:
            1. O Master Prompt em bloco de código pronto para cópia, contendo a **Matriz de Concretização de Adjetivos** para guiar a IA executora a nunca aceitar generalidades.
            2. Lista explicativa de todas as variáveis e como preenchê-las com vocabulário concreto e des-adjetivado.
            """
            
        case .iterativeLoop:
            prompt += """
            
            [TAREFA - METODOLOGIA OXAIR APRIMORADA (GERAÇÃO → AUDITORIA DE ADJETIVOS → MASTER PROMPT BLINDADO)]:
            Execute o ciclo completo em 3 etapas transparentes:
            
            ### ETAPA 1: Rascunho Inicial Estruturado
            Construa a primeira versão do prompt capturando a intenção do usuário.
            
            ### ETAPA 2: Auditoria de Adjetivos Vagos & Análise de Vulnerabilidades (Auto-Crítica)
            Realize uma dissecação crítica detalhada:
            - **Caça aos Adjetivos Vagos:** Liste explicitamente cada adjetivo ou expressão subjetiva presente no rascunho ou na ideia original (ex: 'robusto', 'fácil', 'limpo', 'otimizado', 'didático', 'atraente').
            - **Análise de Ambiguidade:** Explique exatamente como um LLM comum interpretaria erroneamente ou alucinaria com base em cada um desses adjetivos.
            - **Premissas Ocultas & Falhas de Borda:** Quais casos extremos, formatos ou limitações ficaram de fora?
            
            ### ETAPA 3: Master Prompt Final Blindado (Super-Concretizado)
            Apresente a versão definitiva e polida pronta para produção:
            - Inclua a **Tabela de Des-adjetivação Semântica** (traduzindo os adjetivos da Etapa 2 em métricas palpáveis e regras inequívocas).
            - Guardrails rígidos, instruções imperativas e schema de saída milimétrico.
            """
        }
        
        return (system, prompt)
    }
    
    public func executeHarnessStream(
        rawInput: String,
        preset: HarnessPreset,
        mode: HarnessMode,
        model: String,
        temperature: Double = 0.65
    ) -> AsyncThrowingStream<HarnessExecutionEvent, Error> {
        let (system, prompt) = buildGenerationPrompt(rawInput: rawInput, preset: preset, mode: mode)
        
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    continuation.yield(HarnessExecutionEvent(type: .stageChanged("Conectando ao modelo local \(model)...")))
                    
                    switch mode {
                    case .standard, .modularTemplate:
                        continuation.yield(HarnessExecutionEvent(type: .stageChanged("Executando concretização semântica e sintetizando Master Prompt...")))
                        var fullText = ""
                        for try await token in await ollamaClient.streamGenerate(
                            model: model,
                            prompt: prompt,
                            system: system,
                            temperature: temperature
                        ) {
                            guard !Task.isCancelled else { break }
                            fullText += token
                            continuation.yield(HarnessExecutionEvent(type: .tokenYielded(token)))
                        }
                        continuation.yield(HarnessExecutionEvent(type: .finished(fullText)))
                        continuation.finish()
                        
                    case .iterativeLoop:
                        continuation.yield(HarnessExecutionEvent(type: .stageChanged("Ciclo Oxair: Rascunho → Auditoria de Adjetivos → Refinamento Concreto...")))
                        var fullText = ""
                        for try await token in await ollamaClient.streamGenerate(
                            model: model,
                            prompt: prompt,
                            system: system,
                            temperature: temperature
                        ) {
                            guard !Task.isCancelled else { break }
                            fullText += token
                            continuation.yield(HarnessExecutionEvent(type: .tokenYielded(token)))
                        }
                        continuation.yield(HarnessExecutionEvent(type: .finished(fullText)))
                        continuation.finish()
                    }
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
