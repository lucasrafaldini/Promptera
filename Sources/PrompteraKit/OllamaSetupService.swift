import AppKit

/// Serviço leve de detecção e lançamento do Ollama local.
///
/// O Promptera não instala o Ollama por si só (isso dependeria de
/// privilégios do usuário). Cabe aqui detectar se o Ollama já está
/// presente, apontar para a página de download e tentar abri-lo.
public enum OllamaSetupService {
    public static let ollamaAppURL = URL(fileURLWithPath: "/Applications/Ollama.app")
    public static let ollamaDownloadURL = URL(string: "https://ollama.com/download")!

    /// O Ollama está instalado no Mac (app ou CLI no PATH).
    public static func isOllamaInstalled() -> Bool {
        if FileManager.default.fileExists(atPath: ollamaAppURL.path) {
            return true
        }
        return ollamaCLIPath != nil
    }

    /// Abre o Ollama.app se estiver instalado; caso contrário, abre a página de download.
    public static func launchOrOpenDownload() {
        if FileManager.default.fileExists(atPath: ollamaAppURL.path) {
            NSWorkspace.shared.open(ollamaAppURL)
        } else {
            NSWorkspace.shared.open(ollamaDownloadURL)
        }
    }

    /// Abre a página de download do Ollama no navegador.
    public static func openDownloadPage() {
        NSWorkspace.shared.open(ollamaDownloadURL)
    }

    /// Caminho do binário `ollama` no PATH, se existir.
    private static var ollamaCLIPath: String? {
        for candidate in ["/usr/local/bin/ollama", "/opt/homebrew/bin/ollama", "/opt/Ollama/bin/ollama"] {
            if FileManager.default.isExecutableFile(atPath: candidate) {
                return candidate
            }
        }
        return nil
    }
}
