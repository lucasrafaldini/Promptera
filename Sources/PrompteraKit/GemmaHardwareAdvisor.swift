import Foundation

/// Resultado da recomendação de modelo Gemma com base no hardware local.
public struct GemmaHardwareRecommendation: Sendable, Equatable {
    /// Modelo Gemma recomendado (tag do Ollama, ex: "gemma3:1b").
    public let model: String
    /// Memória estimada necessária (GB) para rodar com conforto.
    public let estimatedMemoryGB: Double
    /// Memória unificada disponível no Mac (GB).
    public let availableMemoryGB: Double
    /// Por que este modelo foi escolhido.
    public let rationale: String
    /// Nível de risco de execução neste hardware.
    public let riskLevel: RiskLevel
    /// Se o modelo cabe com folga na memória disponível.
    public let fitsComfortably: Bool

    public enum RiskLevel: String, CaseIterable, Identifiable, Sendable {
        case low = "Baixo"
        case medium = "Médio"
        case high = "Alto"

        public var id: String { rawValue }
    }

    public init(
        model: String,
        estimatedMemoryGB: Double,
        availableMemoryGB: Double,
        rationale: String,
        riskLevel: RiskLevel,
        fitsComfortably: Bool
    ) {
        self.model = model
        self.estimatedMemoryGB = estimatedMemoryGB
        self.availableMemoryGB = availableMemoryGB
        self.rationale = rationale
        self.riskLevel = riskLevel
        self.fitsComfortably = fitsComfortably
    }
}

/// Recomenda o modelo Gemma mais adequado ao hardware local (memória unificada
/// e chip Apple Silicon). Quanto mais memória, maior o modelo que cabe com
/// qualidade e menor o risco de delírio/alucinação.
public enum GemmaHardwareAdvisor {
    /// Quantidade aproximada de VRAM/memória necessária por modelo (GB),
    /// considerando overhead do sistema e contexto.
    private static let modelMemoryGB: [String: Double] = [
        "gemma3:1b": 1.5,
        "gemma3:4b": 5.0,
        "gemma3:12b": 14.0,
        "gemma2:2b": 3.0,
        "gemma2:9b": 9.0,
        "gemma2:27b": 28.0,
    ]

    /// Ordem de preferência do menor para o maior.
    private static let allModels: [String] = [
        "gemma3:1b", "gemma3:4b", "gemma3:12b",
        "gemma2:2b", "gemma2:9b", "gemma2:27b",
    ]

    /// Retorna a recomendação de Gemma com base no hardware **local do usuário**
    /// (memória unificada do Mac onde o Promptera está instalado), nunca em um
    /// valor hardcoded de desenvolvimento.
    public static func recommend() -> GemmaHardwareRecommendation {
        let availableGB = Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824
        let chip = SystemInfo.chipName

        // Regra simples e conservadora: reservar ~4 GB para o sistema + app.
        let budgetGB = availableGB - 4.0

        let chosen: String
        let rationale: String
        let riskLevel: GemmaHardwareRecommendation.RiskLevel
        let fitsComfortably: Bool

        if budgetGB >= 16.0 {
            chosen = "gemma3:12b"
            rationale = "\(Int(availableGB)) GB de memória unificada detectados no \(chip): cabe o Gemma 3 12B com folga, ideal para prompts complexos e menor risco de alucinação."
            riskLevel = .low
            fitsComfortably = true
        } else if budgetGB >= 7.0 {
            chosen = "gemma3:4b"
            rationale = "\(Int(availableGB)) GB de memória unificada detectados no \(chip): o Gemma 3 4B é o equilíbrio entre qualidade e consumo."
            riskLevel = .low
            fitsComfortably = true
        } else if budgetGB >= 3.0 {
            chosen = "gemma3:1b"
            rationale = "\(Int(availableGB)) GB de memória unificada detectados no \(chip): o Gemma 3 1B é leve o suficiente para rodar localmente sem comprometer o sistema."
            riskLevel = .medium
            fitsComfortably = true
        } else {
            chosen = "gemma3:1b"
            rationale = "Memória limitada (\(Int(availableGB)) GB) no \(chip): apenas o Gemma 3 1B cabe, mas espere respostas mais simples e maior risco de alucinação."
            riskLevel = .high
            fitsComfortably = false
        }

        let estimated = modelMemoryGB[chosen] ?? 2.0

        return GemmaHardwareRecommendation(
            model: chosen,
            estimatedMemoryGB: estimated,
            availableMemoryGB: availableGB,
            rationale: rationale,
            riskLevel: riskLevel,
            fitsComfortably: fitsComfortably
        )
    }

    /// Retorna todos os modelos Gemma conhecidos com estimativa de memória.
    public static func allGemmaModels() -> [(name: String, estimatedMemoryGB: Double)] {
        allModels.map { ($0, modelMemoryGB[$0] ?? 0) }
    }
}
