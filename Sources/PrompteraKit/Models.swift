import Foundation

public struct ClipboardItem: Identifiable, Codable, Equatable, Hashable {
    public let id: UUID
    public let content: String
    public let timestamp: Date
    
    public init(id: UUID = UUID(), content: String, timestamp: Date = Date()) {
        self.id = id
        self.content = content
        self.timestamp = timestamp
    }
    
    public var preview: String {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count <= 100 {
            return trimmed.replacingOccurrences(of: "\n", with: " ")
        }
        let prefix = String(trimmed.prefix(100))
        return prefix.replacingOccurrences(of: "\n", with: " ") + "..."
    }
    
    public var characterCount: Int {
        content.count
    }
    
    public var lineCount: Int {
        content.components(separatedBy: .newlines).count
    }
}

public struct OllamaModelInfo: Identifiable, Codable, Equatable {
    public var id: String { name }
    public let name: String
    public let size: Int64?
    public let modifiedAt: String?
    
    public init(name: String, size: Int64? = nil, modifiedAt: String? = nil) {
        self.name = name
        self.size = size
        self.modifiedAt = modifiedAt
    }
    
    public var formattedSize: String {
        guard let size = size else { return "" }
        let gigabytes = Double(size) / (1024 * 1024 * 1024)
        return String(format: "%.1f GB", gigabytes)
    }
}

public enum HarnessMode: String, CaseIterable, Identifiable, Codable {
    case standard = "Direto (Master Prompt)"
    case iterativeLoop = "Loop Oxair (Gera → Critica → Refina)"
    case modularTemplate = "Modular (Com Variáveis {{...}})"
    
    public var id: String { rawValue }
    
    public var description: String {
        switch self {
        case .standard:
            return "Cria um Master Prompt completo, estruturado e com guardrails a partir da sua ideia."
        case .iterativeLoop:
            return "Metodologia Oxair: rascunha o prompt, executa auto-crítica de falhas/premissas e entrega a versão blindada."
        case .modularTemplate:
            return "Gera um template reutilizável para o seu prompt com variáveis dinâmicas e guia de preenchimento."
        }
    }
}

public struct HarnessPreset: Identifiable, Equatable, Hashable {
    public let id: String
    public let title: String
    public let icon: String
    public let description: String
    public let domainGuidance: String
    
    public init(id: String, title: String, icon: String, description: String, domainGuidance: String) {
        self.id = id
        self.title = title
        self.icon = icon
        self.description = description
        self.domainGuidance = domainGuidance
    }
    
    public static let presets: [HarnessPreset] = [
        HarnessPreset(
            id: "universal",
            title: "Universal (Master)",
            icon: "sparkles",
            description: "Para qualquer objetivo geral: estrutura papel, contexto, regras e formato.",
            domainGuidance: "Foque em clareza, decomposição do objetivo, formato estruturado e critérios de sucesso mensuráveis."
        ),
        HarnessPreset(
            id: "coding",
            title: "Engenharia de Software",
            icon: "chevron.left.forwardslash.chevron.right",
            description: "Arquitetura, refatoração, implementação limpa, testes e documentação de código.",
            domainGuidance: "Defina o nível de senioridade, exija princípios SOLID/DRY, tratamento de exceções robusto, tipagem estrita e sem suposições não verificadas."
        ),
        HarnessPreset(
            id: "system_design",
            title: "System Design & DevOps",
            icon: "server.rack",
            description: "Design de sistemas distribuídos, bancos de dados, microsserviços e infraestrutura.",
            domainGuidance: "Exija diagramas conceituais (Mermaid/ASCII), trade-offs de latência/consistência, escalabilidade, segurança e tolerância a falhas."
        ),
        HarnessPreset(
            id: "reasoning",
            title: "Análise & Raciocínio Profundo",
            icon: "brain.head.profile",
            description: "Resolução de problemas complexos, síntese de documentos, deduções e tomada de decisão.",
            domainGuidance: "Exija Chain of Thought (pensamento passo a passo), exploração de contra-argumentos, matriz de prós/contras e mitigação de vieses."
        ),
        HarnessPreset(
            id: "copywriting",
            title: "Copywriting & Conteúdo",
            icon: "text.quote",
            description: "Copy de alta conversão, artigos técnicos, posts persuasivos e documentação.",
            domainGuidance: "Defina voz/tom, público-alvo, gatilhos de interesse, estrutura de narrativa (AIDA/PAS) e proibições de clichês de IA."
        )
    ]
}
