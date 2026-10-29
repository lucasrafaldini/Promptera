<p align="center"><img src="Resources/AppIcon.png" width="128" alt="Promptera"></p>

# 🪄 Promptera

**Promptera** é um aplicativo nativo para macOS que vive diretamente no seu **Menu Bar**, integrando um gerenciador de **Histórico de Clipboard (Copiar-Colar)** com um **Harness de Engenharia de Prompts** baseado na metodologia do artigo de referência (*Oxair*: *"How to Create Your Own AI Prompt Generator That Works Forever"*).

O Promptera foi projetado para rodar **100% local e privado** com aceleração de hardware **Metal** no seu processador **Apple Silicon (M4)** utilizando modelos locais via **Ollama**.

[![CI](https://github.com/lucasrafaldini/promptera/workflows/CI/badge.svg)](https://github.com/lucasrafaldini/promptera/actions)
[![Release](https://github.com/lucasrafaldini/promptera/workflows/Release/badge.svg)](https://github.com/lucasrafaldini/promptera/actions)
[![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-macOS%2014%2B-lightgrey.svg)](https://apple.com/macos)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

**🌐 Idiomas / Languages / Idiomas:** [English](README.md) • [Português](README.pt.md) • [Español](README.es.md)

---

## 📸 Capturas de Tela

Baixe o `.dmg` mais recente em [Releases](https://github.com/lucasrafaldini/Promptera/releases/latest).

| | |
|---|---|
| ![Gerador — Aurora (escuro)](docs/screenshots/01-gerador-aurora-escuro.png) | ![Histórico de clipboard — Oceano (claro)](docs/screenshots/03-clipboard-oceano-claro.png) |
| *Gerador — Aurora (escuro)* | *Histórico de clipboard — Oceano (claro)* |
| ![Configurações com 5 temas de cores — Pôr do Sol (escuro)](docs/screenshots/04-configuracoes-temas-por-do-sol-escuro.png) | ![Gerador — Aurora (claro)](docs/screenshots/02-gerador-aurora-claro.png) |
| *Configurações com 5 temas de cores — Pôr do Sol (escuro)* | *Gerador — Aurora (claro)* |

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
- Busca fuzzy em tempo real: ordena os melhores resultados primeiro, ignora maiúsculas/acentos e destaca os caracteres encontrados
- 1-clique para carregar qualquer item como contexto para gerar o prompt
- 1-clique para copiar o Master Prompt gerado de volta para o clipboard
- Ações via menu de contexto (clique direito)
- Persistência local criptografada entre sessões

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

### 4. Foco no Gemma + Apple Silicon M4
- **Setup fácil via o próprio Promptera:** assistente de primeira execução guia a instalação do Ollama e o download do modelo Gemma (`gemma3:1b`, leve e eficaz) — você já começa a gerar prompts em poucos cliques.
- Detecta e conecta ao servidor local Ollama (`http://127.0.0.1:11434`)
- Seleção automática dos melhores modelos para M4 (Gemma priorizado, depois `qwen2.5-coder:7b`, `llama3.1`, `phi4-mini`, `deepseek-coder-v2`)
- Streaming de tokens em tempo real
- 100% local — nenhum dado sai do seu Mac

### 5. Gemma Guardrail Harness (anti-delírio)
Como o Gemma é um modelo pequeno, o Promptera inclui um **harness de guardrails dedicado** para que ele nunca divirja na geração de prompts:
- **Saída estruturada forçada em JSON** via `format: "json"` do Ollama — nenhum texto solto fora do esquema.
- **Few-shot em Inglês** (língua do vendor) com exemplo de bom prompt.
- **Temperatura baixa (0.3)** para saídas determinísticas.
- **Validação rígida** dos campos obrigatórios (papel, objetivo, instruções, guardrails, schema de saída, placeholders).
- **Detecção de alucinação** (tags de pensamento, mensagens de recusa, JSON malformado).
- **Auto-reparo:** se o Gemma sair do esquema, o harness reenvia com o erro, até 3 tentativas.
- O Master Prompt final é renderizado em **Inglês (língua do vendor dos LLMs alvo)**, com opção de versão em Português.

### 6. Configurações Persistentes
- Modelo, preset e modo salvos automaticamente
- URL do Ollama configurável
- Exportação/Importação completa (JSON)
  - Prompts gerados e biblioteca de prompts
  - Histórico de clipboard
  - Configurações

### 7. Biblioteca de Prompts
- Cada geração bem-sucedida é salva automaticamente
- Aba **Biblioteca** dedicada com busca fuzzy, edição, exclusão e “carregar no gerador”
- Cada item guarda a entrada original, o Master Prompt, o preset, o modo e o modelo
- Armazenada criptografada e incluída na exportação/importação

### 8. Acessibilidade, Idiomas e Temas
- Labels, hints, traits e ações personalizadas de VoiceOver nas telas principais
- Interface em **português**, **inglês** e **espanhol**, trocável nas Configurações sem reiniciar
- Cinco temas de cores, aparência clara/escura/sistema e cor de destaque personalizada

### 9. Atualizações Automáticas
- Atualizador [Sparkle 2](https://sparkle-project.org) com appcasts assinados em Ed25519
- Verificação automática opcional e “Verificar Atualizações” nas Configurações

### 10. Interface de Linha de Comando (CLI)
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
- [Ollama](https://ollama.ai) (o assistente do Promptera ajuda a instalar e iniciar)
- Modelo recomendado: `ollama pull gemma3:1b` (leve e eficaz) — ou `gemma3:4b` para mais qualidade

### 1. Inicie o Promptera e conclua o setup
O Promptera traz um **assistente de configuração na primeira execução** que:
1. Verifica se o Ollama está instalado (se não estiver, aponta para o download).
2. Verifica se o Ollama está rodando (`ollama serve` / app Ollama).
3. Faz o pull do modelo Gemma (`gemma3:1b`) direto pela interface.
4. Ativa o **Gemma Guardrail Harness** e você já começa a gerar prompts.

```bash
# Opção A: Build e run direto
swift run PrompteraApp

# Opção B: Build do .app nativo
./scripts/build_app.sh
open build/Promptera.app
```

### 2. (Opcional) Instalar o Ollama manualmente
```bash
# Baixe em https://ollama.ai/download, depois inicie o servidor:
ollama serve
# Baixe o Gemma (leve e eficaz):
ollama pull gemma3:1b
```

### 3. (Opcional) Instalar em /Applications
```bash
cp -R build/Promptera.app /Applications/
```

As releases são compiladas, assinadas e notarizadas pelo workflow descrito em
[`docs/RELEASING.md`](docs/RELEASING.md), incluindo a geração do appcast do Sparkle.

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

A suíte tem atualmente **94 testes**, cobrindo clipboard, busca fuzzy,
internacionalização, biblioteca de prompts, criptografia e o harness Oxair.

---

## 🛠️ Estrutura do Código

```
promptera/
├── Package.swift                     # Configuração do Swift Package (Sparkle + resources)
├── Sources/
│   ├── PrompteraKit/                 # Biblioteca Core (reutilizável)
│   │   ├── Models.swift              # Modelos, presets e itens da biblioteca
│   │   ├── ClipboardManager.swift    # Monitoramento e ranking do NSPasteboard
│   │   ├── FuzzyMatcher.swift        # Pontuação da busca fuzzy
│   │   ├── Localization.swift        # AppLanguage, LanguageStore e L10n
│   │   ├── DesignSystem.swift        # Temas, aparência e cor de destaque
│   │   ├── EncryptionService.swift   # Persistência local criptografada
│   │   ├── OllamaClient.swift        # Cliente HTTP com streaming
│   │   ├── PromptHarness.swift       # Motor de meta-prompting (Oxair)
│   │   ├── PrompteraState.swift      # Estado reativo @MainActor
│   │   └── Resources/                # en.lproj, pt.lproj, es.lproj
│   ├── PrompteraApp/                 # App macOS (SwiftUI MenuBar)
│   │   ├── PrompteraApp.swift        # Entrada MenuBarExtra
│   │   ├── UpdateController.swift    # Wrapper do Sparkle
│   │   └── Views/
│   │       ├── MainMenuView.swift    # Janela principal, configurações e abas
│   │       ├── PromptGeneratorView.swift # Editor, presets e streaming
│   │       ├── PromptLibraryView.swift   # Prompts salvos, busca e editor
│   │       └── ClipboardHistoryView.swift # Histórico de cópia/cola
│   └── PrompteraCLI/                 # Interface CLI de terminal
│       └── main.swift                # Executável de linha de comando
├── Tests/
│   └── PrompteraKitTests/            # 94 testes (unitários + E2E)
├── scripts/
│   ├── build_app.sh                  # Script de build para Promptera.app
│   ├── sign_app.sh                   # Assinatura com Developer ID
│   └── notarize.sh                   # Notarização e stapling
├── docs/RELEASING.md                 # Guia de release, assinatura e Sparkle
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
| `⏎` / `⎋` | Salvar / cancelar no editor da biblioteca |

---

## 🤝 Contribuindo

Adoramos contribuições! Veja nosso [Guia de Contribuição](CONTRIBUTING.md) para começar.

### Good First Issues
- [Atalho global de teclado](https://github.com/lucasrafaldini/Promptera/issues/3)
- [Múltiplos provedores LLM](https://github.com/lucasrafaldini/Promptera/issues/6)
- [Novos presets de domínio](https://github.com/lucasrafaldini/Promptera/issues?q=label%3Aenhancement)

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

- 🐛 [Reportar Bug](https://github.com/lucasrafaldini/promptera/issues/new?template=bug_report.md)
- 💡 [Solicitar Feature](https://github.com/lucasrafaldini/promptera/issues/new?template=feature_request.md)
- 💬 [Discussões](https://github.com/lucasrafaldini/promptera/discussions)

---

**Feito com ❤️ para a comunidade de desenvolvedores Apple Silicon**