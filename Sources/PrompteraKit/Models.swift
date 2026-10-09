import Foundation

public struct ClipboardItem: Identifiable, Codable, Equatable, Hashable, Sendable {
    public let id: UUID
    public let content: String
    public let timestamp: Date

    /// Derived values are computed once at creation instead of on every SwiftUI render
    /// (clipboard items can be very large, and these walk the whole string).
    public let preview: String
    public let characterCount: Int
    public let lineCount: Int

    private enum CodingKeys: String, CodingKey {
        case id, content, timestamp
    }

    public init(id: UUID = UUID(), content: String, timestamp: Date = Date()) {
        self.id = id
        self.content = content
        self.timestamp = timestamp
        self.preview = Self.makePreview(content)
        self.characterCount = content.count
        self.lineCount = content.reduce(into: 1) { count, ch in if ch.isNewline { count += 1 } }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decode(UUID.self, forKey: .id),
            content: try container.decode(String.self, forKey: .content),
            timestamp: try container.decode(Date.self, forKey: .timestamp)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(content, forKey: .content)
        try container.encode(timestamp, forKey: .timestamp)
    }

    public static func == (lhs: ClipboardItem, rhs: ClipboardItem) -> Bool {
        lhs.id == rhs.id && lhs.content == rhs.content && lhs.timestamp == rhs.timestamp
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    /// Case- and diacritic-insensitive match without allocating lowercased copies.
    public func matches(_ query: String) -> Bool {
        content.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) != nil
    }

    private static func makePreview(_ content: String) -> String {
        // Only look at the head of the string: avoids trimming megabytes of text.
        let head = content.prefix(400).trimmingCharacters(in: .whitespacesAndNewlines)
        let oneLine = head.replacingOccurrences(of: "\n", with: " ")
        if oneLine.count <= 100 && content.count <= 400 {
            return oneLine
        }
        return String(oneLine.prefix(100)) + "..."
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
