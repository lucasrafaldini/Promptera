# Guia de Contribuição

Obrigado por considerar contribuir para o **Promptera**! 🎉

Este projeto é um **Meta-Prompt Harness** nativo para macOS que vive na Menu Bar, integrando gerenciamento de clipboard com engenharia de prompts baseada na metodologia Oxair.

---

## 🚀 Como Contribuir

### 1. Reportar Bugs
- Use o template de **Bug Report** nas Issues
- Inclua: versão do macOS, passos para reproduzir, logs de erro
- Verifique se o bug já não foi reportado

### 2. Sugerir Funcionalidades
- Use o template de **Feature Request**
- Descreva o problema que a funcionalidade resolve
- Considere a filosofia do projeto: local-first, privacidade, Apple Silicon

### 3. Pull Requests
1. **Fork** o repositório
2. Crie uma **branch** descritiva: `feat/nova-funcionalidade` ou `fix/correcao-bug`
3. Faça commits **atômicos** e claros
4. Execute os testes: `swift test`
5. Abra o PR com descrição detalhada

---

## 🛠️ Configuração do Ambiente

### Pré-requisitos
- macOS 14.0+ (Sonoma)
- Xcode 15+ ou Swift 5.9+ command line tools
- [Ollama](https://ollama.ai) instalado e rodando (`ollama serve`)

### Instalação
```bash
git clone https://github.com/lucasrafaldini/Promptera.git
cd promptera
swift build
```

### Executar Testes
```bash
swift test
```

### Build do App
```bash
./scripts/build_app.sh
open build/Promptera.app
```

---

## 📁 Estrutura do Projeto

```
promptera/
├── Package.swift                 # Swift Package config
├── Sources/
│   ├── PrompteraKit/             # Biblioteca core (reutilizável)
│   │   ├── Models.swift          # Modelos de dados e biblioteca de prompts
│   │   ├── ClipboardManager.swift # Monitoramento NSPasteboard e ranking fuzzy
│   │   ├── FuzzyMatcher.swift    # Busca fuzzy
│   │   ├── Localization.swift    # Idiomas e L10n
│   │   ├── DesignSystem.swift    # Temas, aparência e cores
│   │   ├── EncryptionService.swift # Persistência criptografada
│   │   ├── OllamaClient.swift    # Cliente HTTP com streaming
│   │   ├── PromptHarness.swift   # Motor de meta-prompting (Oxair)
│   │   ├── PrompteraState.swift  # Estado reativo @MainActor
│   │   └── Resources/            # en.lproj, pt.lproj, es.lproj
│   ├── PrompteraApp/             # App macOS (SwiftUI MenuBar)
│   │   ├── PrompteraApp.swift    # Entry point MenuBarExtra
│   │   ├── UpdateController.swift # Wrapper do Sparkle
│   │   └── Views/                # Views SwiftUI
│   └── PrompteraCLI/             # Interface de linha de comando
│       └── main.swift
├── Tests/
│   └── PrompteraKitTests/        # Testes unitários + E2E
├── scripts/
│   ├── build_app.sh              # Script de empacotamento .app
│   ├── sign_app.sh               # Assinatura Developer ID
│   └── notarize.sh               # Notarização e stapling
├── docs/RELEASING.md             # Guia de release e Sparkle
└── build/
    └── Promptera.app             # App compilado
```

---

## 🎯 Áreas para Contribuição

### 🔥 Prioridade Alta (Good First Issues)
- [x] Melhorar acessibilidade (VoiceOver, navegação por teclado)
- [x] Adicionar suporte a mais idiomas (i18n)
- [ ] Melhorar tratamento de erros de rede
- [ ] Adicionar atalhos de teclado globais
- [x] Implementar busca fuzzy no clipboard

### 🌟 Melhorias de UX
- [ ] Animações mais fluidas nas transições de aba
- [x] Tema personalizável (cores, fontes)
- [x] Histórico de prompts gerados
- [x] Templates de prompt salvos pelo usuário
- [ ] Preview em tempo real do prompt formatado

### 🧠 Core / Engine
- [ ] Otimizar streaming de tokens
- [ ] Adicionar cache de respostas do Ollama
- [ ] Suporte a múltiplos provedores (LM Studio, etc.)
- [ ] Métricas de qualidade do prompt gerado

### 📦 Distribuição
- [ ] Homebrew formula
- [ ] Mac App Store build
- [x] Sparkle framework para auto-update
- [x] Scripts de assinatura e notarização (`scripts/sign_app.sh`, `scripts/notarize.sh`)
- [ ] Configurar os secrets e publicar uma release assinada/notarizada

---

## 🧪 Padrões de Código

### Swift
- **Swift 5.9+** com concorrência moderna (`async/await`, `actor`)
- **SwiftUI** nativo para views
- **@MainActor** para estado de UI
- **Swift Testing** (XCTest) para testes

### Commits
```
feat: adiciona exportação de prompts
fix: corrige vazamento de memória no ClipboardManager
docs: atualiza README com novos atalhos
test: adiciona testes E2E para fluxo completo
refactor: simplifica PromptHarness
perf: otimiza busca no histórico
```

### Testes
- Testes unitários para cada componente isolado
- Testes E2E com mock server para fluxos completos
- Cobertura mínima alvo: 80%

---

## 🏷️ Labels de Issues

| Label | Descrição |
|-------|-----------|
| `good first issue` | Ideal para iniciantes |
| `help wanted` | Precisa de contribuição da comunidade |
| `bug` | Algo não funciona |
| `enhancement` | Nova funcionalidade ou melhoria |
| `documentation` | Melhorias na documentação |
| `hacktoberfest` | Issues marcadas para Hacktoberfest |

---

## 📝 Checklist do PR

- [ ] Testes passam (`swift test`)
- [ ] Build compila sem warnings (`swift build`)
- [ ] Código segue style guide do projeto
- [ ] Documentação atualizada (se aplicável)
- [ ] CHANGELOG.md atualizado (se aplicável)
- [ ] Commits são atômicos e descritivos

---

## 🤝 Código de Conduta

Este projeto adere ao [Contributor Covenant](CODE_OF_CONDUCT.md). Ao participar, você concorda em manter um ambiente respeitoso e inclusivo.

---

## 💬 Comunicação

- **Issues**: Para bugs, features, discussões técnicas
- **Discussions**: Para perguntas gerais, ideias, showcase
- **PRs**: Para revisão de código colaborativa

---

## 🙏 Reconhecimento

Todos os contribuidores serão listados no README e no CHANGELOG. Contribuições significativas ganham destaque especial!

---

**Happy Hacking!** 🪄✨