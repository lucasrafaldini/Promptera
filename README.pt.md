# 🪄 Promptera

**Promptera** é um aplicativo nativo para macOS que vive diretamente no seu **Menu Bar**, integrando um gerenciador de **Histórico de Clipboard (Copiar-Colar)** com um **Harness de Engenharia de Prompts** baseado na metodologia do artigo de referência (*Oxair*: *"How to Create Your Own AI Prompt Generator That Works Forever"*).

O Promptera foi projetado para rodar **100% local e privado** com aceleração de hardware **Metal** no seu processador **Apple Silicon (M4)** utilizando modelos locais via **Ollama**.

[![CI](https://github.com/seu-usuario/promptera/workflows/CI/badge.svg)](https://github.com/seu-usuario/promptera/actions)
[![Release](https://github.com/seu-usuario/promptera/workflows/Release/badge.svg)](https://github.com/seu-usuario/promptera/actions)
[![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-macOS%2014%2B-lightgrey.svg)](https://apple.com/macos)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

**🌐 Idiomas / Languages / Idiomas:** [English](README.md) • [Português](README.pt.md) • [Español](README.es.md)

---

## 🌟 Recursos Principais

### 1. Acesso Direto pelo Menu Bar
- Ícone elegante na barra de menus do macOS (`MenuBarExtra` nativo)
- Sem poluição no Dock (`LSUIElement = true`)
- Interface rápida e responsiva em SwiftUI nativo com suporte a Dark/Light Mode
- Transições animadas entre abas

### 2. Histórico de Clipboard Integrado
- Monitoramento contínuo em segundo plano do `NSPasteboard`
- Histórico pesquisável de recortes recentes de texto e código
- Busca fuzzy em tempo real
- 1-clique para carregar qualquer item como contexto para gerar o prompt
- 1-clique para copiar o Master Prompt gerado de volta para o clipboard
- Ações via menu de contexto (clique direito)
- Persistência automática entre sessões

### 3. Harness de Criação de Prompts (Metodologia Oxair)
- **Loop Oxair (Gera → Critica → Refina):** A IA gera um rascunho, audita suas próprias falhas e premissas implícitas, e sintetiza um Master Prompt blindado
- **Modo Modular:** Adiciona variáveis dinâmicas (`{{variavel}}`) para transformar o prompt em template reutilizável
- **Modo Direto:** Master Prompt estruturado em uma passada
- **Presets de Domínio:** Configurações prontas para:
  - 🛠️ **Engenharia de Software** — Arquitetura, refatoração, testes, documentação
  - 🏗️ **System Design & DevOps** — Sistemas distribuídos, bancos, microsserviços
  - 🧠 **Análise & Raciocínio Profundo** — Problemas complexos, síntese, decisão
  - ✍️ **Copywriting & Conteúdo** — Copy persuasivo, artigos, documentação
  - ✨ **Universal (Master)** — Qualquer objetivo geral

### 4. Otimizado para Apple Silicon M4
- Detecta e conecta ao servidor local Ollama (`http://127.0.0.1:11434`)
- Seleção automática dos melhores modelos para M4 (`qwen2.5-coder:7b`, `llama3.1`, `phi4-mini`, `deepseek-coder-v2`)
- Streaming de tokens em tempo real
- 100% local — nenhum dado sai do seu Mac

### 5. Configurações Persistentes
- Modelo, preset e modo salvos automaticamente
- URL do Ollama configurável
- Exportação/Importação completa (JSON)
  - Prompts gerados
  - Histórico de clipboard
  - Configurações

### 6. Interface de Linha de Comando (CLI)
```bash
# Gerar a partir do texto informado:
swift run promptera "Criar um microserviço de autenticação JWT em Go"

# Ou usar o conteúdo atual do clipboard:
swift run promptera --clipboard
```

---

## 🚀 Como Executar

### Pré-requisitos
- macOS 14.0+ (Sonoma)
- [Ollama](https://ollama.ai) instalado
- Modelos recomendados: `ollama pull qwen2.5-coder:7b llama3.1 phi4-mini`

### 1. Iniciar o Ollama
```bash
ollama serve
```

### 2. Abrir o App no Menu Bar
```bash
# Opção A: Build e run direto
swift run PrompteraApp

# Opção B: Build do .app nativo
./scripts/build_app.sh
open build/Promptera.app
```

### 3. (Opcional) Instalar em /Applications
```bash
cp -R build/Promptera.app /Applications/
```

---

## 🧪 Testes

```bash
# Todos os testes (unitários + E2E)
swift test

# Apenas testes unitários rápidos
swift test --filter "PrompteraKitTests"

# Com cobertura (requer llvm-cov)
swift test --enable-code-coverage
xcrun llvm-cov export -format="lcov" .build/debug/PrompteraKitTests.xctest/Contents/MacOS/PrompteraKitTests -instr-profile .build/debug/codecov/default.profdata > coverage.lcov
```

---

## 🛠️ Estrutura do Código

```
promptera/
├── Package.swift                     # Configuração do Swift Package
├── Sources/
│   ├── PrompteraKit/                 # Biblioteca Core (reutilizável)
│   │   ├── Models.swift              # Modelos de dados e presets
│   │   ├── ClipboardManager.swift    # Monitoramento de NSPasteboard
│   │   ├── OllamaClient.swift        # Cliente HTTP com streaming
│   │   ├── PromptHarness.swift       # Motor de meta-prompting (Oxair)
│   │   └── PrompteraState.swift      # Estado reativo @MainActor
│   ├── PrompteraApp/                 # App macOS (SwiftUI MenuBar)
│   │   ├── PrompteraApp.swift        # Entrada MenuBarExtra
│   │   └── Views/
│   │       ├── MainMenuView.swift    # Janela principal com abas
│   │       ├── PromptGeneratorView.swift # Editor, presets e streaming
│   │       └── ClipboardHistoryView.swift # Histórico de cópia/cola
│   └── PrompteraCLI/                 # Interface CLI de terminal
│       └── main.swift                # Executável de linha de comando
├── Tests/
│   └── PrompteraKitTests/            # 63 testes (unitários + E2E)
├── scripts/
│   └── build_app.sh                  # Script de build para Promptera.app
├── .github/
│   ├── workflows/                    # CI/CD GitHub Actions
│   └── ISSUE_TEMPLATE/               # Templates de issues
└── build/
    └── Promptera.app                 # Aplicativo compilado
```

---

## ⌨️ Atalhos de Teclado

| Atalho | Ação |
|--------|------|
| `⌘⏎` | Gerar Master Prompt |
| `⎋` | Cancelar geração |
| `⌘U` | Usar item do clipboard selecionado |
| `⌘⌫` | Limpar entrada |
| `⌘C` | Copiar prompt gerado |

---

## 🤝 Contribuindo

Adoramos contribuições! Veja nosso [Guia de Contribuição](CONTRIBUTING.md) para começar.

### Good First Issues
- [Melhorar acessibilidade](https://github.com/seu-usuario/promptera/issues?q=label%3A%22good+first+issue%22)
- [Adicionar i18n](https://github.com/seu-usuario/promptera/issues?q=label%3A%22good+first+issue%22)
- [Novos presets de domínio](https://github.com/seu-usuario/promptera/issues?q=label%3A%22enhancement%22)

### Hacktoberfest
Este projeto participa do **Hacktoberfest**! Issues marcadas com `hacktoberfest` são ideais para contribuições durante o evento.

---

## 📄 Licença

MIT License - veja [LICENSE](LICENSE) para detalhes.

---

## 🙏 Agradecimentos

- **Oxair** pela metodologia de engenharia de prompts
- **Ollama** pela inferência local incrível
- **Apple** pelo Silicon e frameworks nativos
- **Comunidade Swift** pelas ferramentas open source

---

## 📞 Suporte

- 🐛 [Reportar Bug](https://github.com/seu-usuario/promptera/issues/new?template=bug_report.md)
- 💡 [Solicitar Feature](https://github.com/seu-usuario/promptera/issues/new?template=feature_request.md)
- 💬 [Discussões](https://github.com/seu-usuario/promptera/discussions)

---

**Feito com ❤️ para a comunidade de desenvolvedores Apple Silicon**