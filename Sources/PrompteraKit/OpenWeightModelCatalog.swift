import Foundation

/// Um modelo open weight / open source (Hugging Face ou Ollama) que o usuário
/// pode baixar e usar no Promptera, com indicação de adequação ao hardware local
/// e nível de risco (memória + tendência a alucinação/delírio).
public struct OpenWeightModel: Identifiable, Codable, Sendable, Equatable, Hashable {
    /// Nome amigável (ex: "Gemma 3 1B").
    public let displayName: String
    /// Tag para baixar no Ollama (ex: "gemma3:1b") ou repo do Hugging Face.
    public let ollamaTag: String?
    /// Repositório no Hugging Face (ex: "google/gemma-3-1b-it").
    public let huggingFaceRepo: String?
    /// Família do modelo.
    public let family: Family
    /// Número aproximado de parâmetros.
    public let parameters: String
    /// Memória estimada necessária para rodar com conforto (GB).
    public let estimatedMemoryGB: Double
    /// Descrição curta do uso recomendado.
    public let description: String
    /// URL da página no Hugging Face (se houver).
    public let huggingFaceURL: URL?

    public enum Family: String, CaseIterable, Codable, Sendable {
        case gemma = "Gemma"
        case llama = "Llama"
        case qwen = "Qwen"
        case phi = "Phi"
        case deepseek = "Deepseek"
        case mistral = "Mistral"
    }

    public var id: String { ollamaTag ?? huggingFaceRepo ?? displayName }

    /// Nível de risco de executar este modelo no hardware local atual.
    /// Combina pressão de memória e tendência a alucinações do modelo.
    public enum RiskLevel: String, CaseIterable, Identifiable, Codable, Sendable {
        case low = "Baixo"
        case medium = "Médio"
        case high = "Alto"

        public var id: String { rawValue }
    }

    /// Resultado da avaliação de adequação deste modelo ao hardware local.
    public struct Suitability: Sendable, Equatable {
        /// Score de 0.0 (inadequado) a 1.0 (muito adequado).
        public let score: Double
        /// Nível de risco (memória + alucinação).
        public let risk: RiskLevel
        /// Texto explicativo amigável.
        public let rationale: String
        /// Se cabe com folga na memória disponível.
        public let fitsComfortably: Bool
    }

    public init(
        displayName: String,
        ollamaTag: String?,
        huggingFaceRepo: String?,
        family: Family,
        parameters: String,
        estimatedMemoryGB: Double,
        description: String,
        huggingFaceURL: URL? = nil
    ) {
        self.displayName = displayName
        self.ollamaTag = ollamaTag
        self.huggingFaceRepo = huggingFaceRepo
        self.family = family
        self.parameters = parameters
        self.estimatedMemoryGB = estimatedMemoryGB
        self.description = description
        self.huggingFaceURL = huggingFaceURL
    }

    private enum CodingKeys: String, CodingKey {
        case displayName, ollamaTag, huggingFaceRepo, family, parameters, estimatedMemoryGB, description, huggingFaceURL
    }

    /// Avalia a adequação e o risco deste modelo ao hardware informado.
    public func suitability(availableMemoryGB: Double) -> OpenWeightModel.Suitability {
        // Reserva conservadora para sistema + app Promptera.
        let budgetGB = availableMemoryGB - 4.0
        let fits = budgetGB >= estimatedMemoryGB

        let memoryScore: Double
        if fits {
            memoryScore = 1.0 - min((estimatedMemoryGB / max(budgetGB, 1)) * 0.6, 0.6)
        } else {
            let deficit = estimatedMemoryGB - budgetGB
            memoryScore = max(0.0, 0.4 - (deficit / estimatedMemoryGB) * 0.4)
        }

        // Tendência a alucinação: modelos menores = maior risco de delírio.
        let hallucinationRisk: Double
        let paramValue = Double(parameters.replacingOccurrences(of: "B", with: "")) ?? 1
        if paramValue <= 2 {
            hallucinationRisk = 0.6
        } else if paramValue <= 8 {
            hallucinationRisk = 0.35
        } else {
            hallucinationRisk = 0.15
        }

        let score = (memoryScore * 0.6) + ((1.0 - hallucinationRisk) * 0.4)

        let risk: OpenWeightModel.RiskLevel
        if !fits {
            risk = .high
        } else if paramValue <= 2 {
            risk = .medium
        } else if paramValue <= 8 {
            risk = .low
        } else {
            risk = .low
        }

        let rationale: String
        if !fits {
            rationale = L10n.t("Não cabe com folga na memória disponível.") + " (\(String(format: "%.0f", availableMemoryGB)) GB). " + L10n.t("Risco de lentidão ou travamento.")
        } else if paramValue <= 2 {
            rationale = L10n.t("Modelo pequeno: maior risco de alucinação/delírio em prompts complexos.")
        } else {
            rationale = L10n.t("Bom equilíbrio entre memória e qualidade para este hardware.")
        }

        return Suitability(
            score: min(max(score, 0), 1),
            risk: risk,
            rationale: rationale,
            fitsComfortably: fits
        )
    }
}

/// Catálogo dos modelos open weight mais populares para geração de prompts.
public enum OpenWeightModelCatalog {
    // MARK: - Catálogo

    public static let models: [OpenWeightModel] = [
        // Gemma (foco principal do Promptera)
        OpenWeightModel(
            displayName: "Gemma 3 1B",
            ollamaTag: "gemma3:1b",
            huggingFaceRepo: "google/gemma-3-1b-it",
            family: .gemma,
            parameters: "1B",
            estimatedMemoryGB: 1.5,
            description: "Leve, eficaz e o foco principal do Promptera. Ideal para Apple Silicon com memória limitada.",
            huggingFaceURL: URL(string: "https://huggingface.co/google/gemma-3-1b-it")
        ),
        OpenWeightModel(
            displayName: "Gemma 3 4B",
            ollamaTag: "gemma3:4b",
            huggingFaceRepo: "google/gemma-3-4b-it",
            family: .gemma,
            parameters: "4B",
            estimatedMemoryGB: 5.0,
            description: "Equilíbrio entre qualidade e consumo. Recomendado para 16 GB+ de memória unificada.",
            huggingFaceURL: URL(string: "https://huggingface.co/google/gemma-3-4b-it")
        ),
        OpenWeightModel(
            displayName: "Gemma 3 12B",
            ollamaTag: "gemma3:12b",
            huggingFaceRepo: "google/gemma-3-12b-it",
            family: .gemma,
            parameters: "12B",
            estimatedMemoryGB: 14.0,
            description: "Maior qualidade, menor alucinação. Requer 24 GB+ de memória unificada.",
            huggingFaceURL: URL(string: "https://huggingface.co/google/gemma-3-12b-it")
        ),
        // Llama
        OpenWeightModel(
            displayName: "Llama 3.2 1B",
            ollamaTag: "llama3.2:1b",
            huggingFaceRepo: "meta-llama/Llama-3.2-1B-Instruct",
            family: .llama,
            parameters: "1B",
            estimatedMemoryGB: 1.5,
            description: "Modelo leve da Meta, rápido e de baixo consumo.",
            huggingFaceURL: URL(string: "https://huggingface.co/meta-llama/Llama-3.2-1B-Instruct")
        ),
        OpenWeightModel(
            displayName: "Llama 3.2 3B",
            ollamaTag: "llama3.2:3b",
            huggingFaceRepo: "meta-llama/Llama-3.2-3B-Instruct",
            family: .llama,
            parameters: "3B",
            estimatedMemoryGB: 3.0,
            description: "Bom equilíbrio para tarefas gerais em hardware modesto.",
            huggingFaceURL: URL(string: "https://huggingface.co/meta-llama/Llama-3.2-3B-Instruct")
        ),
        OpenWeightModel(
            displayName: "Llama 3.1 8B",
            ollamaTag: "llama3.1:8b",
            huggingFaceRepo: "meta-llama/Llama-3.1-8B-Instruct",
            family: .llama,
            parameters: "8B",
            estimatedMemoryGB: 8.0,
            description: "Modelo de propósito geral da Meta, qualidade sólida.",
            huggingFaceURL: URL(string: "https://huggingface.co/meta-llama/Llama-3.1-8B-Instruct")
        ),
        OpenWeightModel(
            displayName: "Llama 3.1 70B",
            ollamaTag: "llama3.1:70b",
            huggingFaceRepo: "meta-llama/Llama-3.1-70B-Instruct",
            family: .llama,
            parameters: "70B",
            estimatedMemoryGB: 40.0,
            description: "Alta qualidade, mas exige grande quantidade de memória (40 GB+).",
            huggingFaceURL: URL(string: "https://huggingface.co/meta-llama/Llama-3.1-70B-Instruct")
        ),
        // Qwen
        OpenWeightModel(
            displayName: "Qwen 2.5 0.5B",
            ollamaTag: "qwen2.5:0.5b",
            huggingFaceRepo: "Qwen/Qwen2.5-0.5B-Instruct",
            family: .qwen,
            parameters: "0.5B",
            estimatedMemoryGB: 1.0,
            description: "Extremamente leve, adequado a hardware muito limitado.",
            huggingFaceURL: URL(string: "https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct")
        ),
        OpenWeightModel(
            displayName: "Qwen 2.5 1.5B",
            ollamaTag: "qwen2.5:1.5b",
            huggingFaceRepo: "Qwen/Qwen2.5-1.5B-Instruct",
            family: .qwen,
            parameters: "1.5B",
            estimatedMemoryGB: 2.0,
            description: "Leve e rápido, bom para tarefas simples de prompt.",
            huggingFaceURL: URL(string: "https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct")
        ),
        OpenWeightModel(
            displayName: "Qwen 2.5 7B",
            ollamaTag: "qwen2.5-coder:7b",
            huggingFaceRepo: "Qwen/Qwen2.5-7B-Instruct",
            family: .qwen,
            parameters: "7B",
            estimatedMemoryGB: 7.0,
            description: "Forte em código e raciocínio; recomendado para engenharia de software.",
            huggingFaceURL: URL(string: "https://huggingface.co/Qwen/Qwen2.5-7B-Instruct")
        ),
        OpenWeightModel(
            displayName: "Qwen 2.5 32B",
            ollamaTag: "qwen2.5:32b",
            huggingFaceRepo: "Qwen/Qwen2.5-32B-Instruct",
            family: .qwen,
            parameters: "32B",
            estimatedMemoryGB: 20.0,
            description: "Alta capacidade de raciocínio, requer 24 GB+ de memória.",
            huggingFaceURL: URL(string: "https://huggingface.co/Qwen/Qwen2.5-32B-Instruct")
        ),
        // Phi
        OpenWeightModel(
            displayName: "Phi-4 Mini",
            ollamaTag: "phi4-mini:latest",
            huggingFaceRepo: "microsoft/Phi-4-mini-instruct",
            family: .phi,
            parameters: "3.8B",
            estimatedMemoryGB: 4.0,
            description: "Modelo compacto da Microsoft com bom raciocínio.",
            huggingFaceURL: URL(string: "https://huggingface.co/microsoft/Phi-4-mini-instruct")
        ),
        // Deepseek
        OpenWeightModel(
            displayName: "Deepseek Coder V2 16B",
            ollamaTag: "deepseek-coder-v2:16b",
            huggingFaceRepo: "deepseek-ai/DeepSeek-Coder-V2-Instruct",
            family: .deepseek,
            parameters: "16B",
            estimatedMemoryGB: 12.0,
            description: "Especialista em código, requer 16 GB+ de memória.",
            huggingFaceURL: URL(string: "https://huggingface.co/deepseek-ai/DeepSeek-Coder-V2-Instruct")
        ),
        // Mistral
        OpenWeightModel(
            displayName: "Mistral 7B",
            ollamaTag: "mistral:7b",
            huggingFaceRepo: "mistralai/Mistral-7B-Instruct-v0.3",
            family: .mistral,
            parameters: "7B",
            estimatedMemoryGB: 7.0,
            description: "Modelo geral eficiente da Mistral AI.",
            huggingFaceURL: URL(string: "https://huggingface.co/mistralai/Mistral-7B-Instruct-v0.3")
        ),
    ]

    /// Retorna os modelos ordenados por adequação ao hardware local (melhor primeiro).
    public static func sortedBySuitability(availableMemoryGB: Double) -> [OpenWeightModel] {
        models.sorted { lhs, rhs in
            lhs.suitability(availableMemoryGB: availableMemoryGB).score >
                rhs.suitability(availableMemoryGB: availableMemoryGB).score
        }
    }
}
