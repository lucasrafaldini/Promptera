import Foundation
import AppKit
import PrompteraKit

@main
struct PrompteraCLI {
    static func main() async {
        let args = CommandLine.arguments.dropFirst()
        
        let ollama = OllamaClient()
        let harness = PromptHarness(ollamaClient: ollama)
        
        print("🪄 Promptera CLI — Meta-Prompt Harness para macOS (Apple Silicon M4)")
        print("-------------------------------------------------------------------")
        
        let isAvailable = await ollama.isAvailable()
        guard isAvailable else {
            print("❌ Erro: Servidor Ollama não está rodando em http://127.0.0.1:11434")
            print("   Execute 'ollama serve' no terminal para iniciá-lo.")
            exit(1)
        }
        
        do {
            let models = try await ollama.fetchAvailableModels()
            guard !models.isEmpty else {
                print("❌ Nenhum modelo encontrado no Ollama local.")
                exit(1)
            }
            
            // Pick default model
            let defaultModel = models.first(where: { $0.name.contains("qwen2.5-coder:7b") })?.name
                ?? models.first(where: { $0.name.contains("llama3.1") })?.name
                ?? models.first!.name
            
            var inputPrompt: String = ""
            
            if args.contains("--clipboard") || args.contains("-c") {
                if let clip = NSPasteboard.general.string(forType: .string), !clip.isEmpty {
                    inputPrompt = clip
                    print("📋 Entrada capturada do Clipboard (\(clip.count) caracteres)")
                } else {
                    print("⚠️ Clipboard vazio.")
                    exit(1)
                }
            } else if !args.isEmpty {
                inputPrompt = args.joined(separator: " ")
            } else {
                print("\n💡 Dica: Você pode passar o texto diretamente:")
                print("   promptera \"Criar um microserviço de autenticação JWT em Go\"")
                print("   promptera --clipboard")
                print("\nDigite sua ideia ou objetivo de prompt (pressione Enter para gerar):")
                print("> ", terminator: "")
                fflush(stdout)
                
                guard let line = readLine(), !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    print("Entrada vazia. Encerrando.")
                    exit(0)
                }
                inputPrompt = line
            }
            
            print("\n🤖 Modelo selecionado: \(defaultModel)")
            print("⚙️ Modo: Loop Oxair (Gera → Critica → Refina)")
            print("🚀 Executando Harness...\n")
            
            let stream = await harness.executeHarnessStream(
                rawInput: inputPrompt,
                preset: HarnessPreset.presets[0],
                mode: .iterativeLoop,
                model: defaultModel
            )
            
            var finalResult = ""
            for try await event in stream {
                switch event.type {
                case .stageChanged(let stage):
                    print("\n[\(stage)]\n")
                case .tokenYielded(let token):
                    print(token, terminator: "")
                    fflush(stdout)
                case .finished(let result):
                    finalResult = result
                }
            }
            
            print("\n\n📋 Copiando Master Prompt final para o Clipboard...")
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(finalResult, forType: .string)
            print("✅ Copiado com sucesso para o Clipboard!")
            
        } catch {
            print("\n❌ Erro: \(error.localizedDescription)")
            exit(1)
        }
    }
}
