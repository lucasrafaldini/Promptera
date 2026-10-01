# 🪄 Promptera

**Promptera** is a native macOS app that lives in your **Menu Bar**, integrating a **Clipboard History Manager** with a **Prompt Engineering Harness** based on the Oxair methodology (*"How to Create Your Own AI Prompt Generator That Works Forever"*).

Promptera runs **100% locally and privately** with **Metal** hardware acceleration on your **Apple Silicon (M4)** processor using local models via **Ollama**.

[![CI](https://github.com/seu-usuario/promptera/workflows/CI/badge.svg)](https://github.com/seu-usuario/promptera/actions)
[![Release](https://github.com/seu-usuario/promptera/workflows/Release/badge.svg)](https://github.com/seu-usuario/promptera/actions)
[![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-macOS%2014%2B-lightgrey.svg)](https://apple.com/macos)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

**🌐 Idiomas / Languages / Idiomas:** [English](README.md) • [Português](README.pt.md) • [Español](README.es.md)

---

## 🌟 Key Features

### 1. Direct Menu Bar Access
- Elegant icon in macOS menu bar (`MenuBarExtra` native)
- No Dock pollution (`LSUIElement = true`)
- Fast, responsive SwiftUI interface with Dark/Light Mode support
- Animated tab transitions

### 2. Integrated Clipboard History
- Continuous background monitoring of `NSPasteboard`
- Searchable history of recent text and code snippets
- Real-time fuzzy search
- 1-click to load any item as context for prompt generation
- 1-click to copy generated Master Prompt back to clipboard
- Context menu actions (right-click)
- Automatic persistence between sessions

### 3. Prompt Creation Harness (Oxair Methodology)
- **Oxair Loop (Generate → Critique → Refine):** AI drafts, audits own flaws/implicit assumptions, synthesizes a battle-tested Master Prompt
- **Modular Mode:** Adds dynamic variables (`{{variable}}`) to transform prompt into reusable template
- **Direct Mode:** Structured Master Prompt in single pass
- **Domain Presets:** Ready-to-use configurations for:
  - 🛠️ **Software Engineering** — Architecture, refactoring, tests, documentation
  - 🏗️ **System Design & DevOps** — Distributed systems, databases, microservices
  - 🧠 **Deep Analysis & Reasoning** — Complex problems, synthesis, decision-making
  - ✍️ **Copywriting & Content** — Persuasive copy, articles, documentation
  - ✨ **Universal (Master)** — Any general objective

### 4. Optimized for Apple Silicon M4
- Detects and connects to local Ollama server (`http://127.0.0.1:11434`)
- Auto-selects best models for M4 (`qwen2.5-coder:7b`, `llama3.1`, `phi4-mini`, `deepseek-coder-v2`)
- Real-time token streaming
- 100% local — no data leaves your Mac

### 5. Persistent Settings
- Model, preset, and mode saved automatically
- Configurable Ollama URL
- Full Export/Import (JSON)
  - Generated prompts
  - Clipboard history
  - Settings

### 6. Command Line Interface (CLI)
```bash
# Generate from provided text:
swift run promptera "Create a JWT auth microservice in Go"

# Or use current clipboard content:
swift run promptera --clipboard
```

---

## 🚀 How to Run

### Prerequisites
- macOS 14.0+ (Sonoma)
- [Ollama](https://ollama.ai) installed
- Recommended models: `ollama pull qwen2.5-coder:7b llama3.1 phi4-mini`

### 1. Start Ollama
```bash
ollama serve
```

### 2. Open App in Menu Bar
```bash
# Option A: Build and run directly
swift run PrompteraApp

# Option B: Build native .app
./scripts/build_app.sh
open build/Promptera.app
```

### 3. (Optional) Install to /Applications
```bash
cp -R build/Promptera.app /Applications/
```

---

## 🧪 Tests

```bash
# All tests (unit + E2E)
swift test

# Only fast unit tests
swift test --filter "PrompteraKitTests"

# With coverage (requires llvm-cov)
swift test --enable-code-coverage
xcrun llvm-cov export -format="lcov" .build/debug/PrompteraKitTests.xctest/Contents/MacOS/PrompteraKitTests -instr-profile .build/debug/codecov/default.profdata > coverage.lcov
```

---

## 🛠️ Code Structure

```
promptera/
├── Package.swift                     # Swift Package config
├── Sources/
│   ├── PrompteraKit/                 # Core Library (reusable)
│   │   ├── Models.swift              # Data models and presets
│   │   ├── ClipboardManager.swift    # NSPasteboard monitoring
│   │   ├── OllamaClient.swift        # HTTP client with streaming
│   │   ├── PromptHarness.swift       # Meta-prompting engine (Oxair)
│   │   └── PrompteraState.swift      # Reactive @MainActor state
│   ├── PrompteraApp/                 # macOS App (SwiftUI MenuBar)
│   │   ├── PrompteraApp.swift        # MenuBarExtra entry point
│   │   └── Views/
│   │       ├── MainMenuView.swift    # Main window with tabs
│   │       ├── PromptGeneratorView.swift # Editor, presets, streaming
│   │       └── ClipboardHistoryView.swift # Copy/paste history
│   └── PrompteraCLI/                 # Terminal CLI interface
│       └── main.swift                # Command line executable
├── Tests/
│   └── PrompteraKitTests/            # 63 tests (unit + E2E)
├── scripts/
│   └── build_app.sh                  # Build script for Promptera.app
├── .github/
│   ├── workflows/                    # CI/CD GitHub Actions
│   └── ISSUE_TEMPLATE/               # Issue templates
└── build/
    └── Promptera.app                 # Compiled app
```

---

## ⌨️ Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `⌘⏎` | Generate Master Prompt |
| `⎋` | Cancel generation |
| `⌘U` | Use selected clipboard item |
| `⌘⌫` | Clear input |
| `⌘C` | Copy generated prompt |

---

## 🤝 Contributing

We love contributions! See our [Contributing Guide](CONTRIBUTING.md) to get started.

### Good First Issues
- [Improve accessibility](https://github.com/seu-usuario/promptera/issues?q=label%3A%22good+first+issue%22)
- [Add i18n](https://github.com/seu-usuario/promptera/issues?q=label%3A%22good+first+issue%22)
- [New domain presets](https://github.com/seu-usuario/promptera/issues?q=label%3A%22enhancement%22)

### Hacktoberfest
This project participates in **Hacktoberfest**! Issues tagged with `hacktoberfest` are ideal for contributions during the event.

---

## 📄 License

MIT License - see [LICENSE](LICENSE) for details.

---

## 🙏 Acknowledgments

- **Oxair** for the prompt engineering methodology
- **Ollama** for amazing local inference
- **Apple** for Silicon and native frameworks
- **Swift Community** for open source tools

---

## 📞 Support

- 🐛 [Report Bug](https://github.com/seu-usuario/promptera/issues/new?template=bug_report.md)
- 💡 [Request Feature](https://github.com/seu-usuario/promptera/issues/new?template=feature_request.md)
- 💬 [Discussions](https://github.com/seu-usuario/promptera/discussions)

---

**Made with ❤️ for the Apple Silicon developer community**