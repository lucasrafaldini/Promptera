<p align="center"><img src="Resources/AppIcon.png" width="128" alt="Promptera"></p>

# 🪄 Promptera

**Promptera** es una aplicación nativa para macOS que vive directamente en tu **Menu Bar**, integrando un gestor de **Historial de Clipboard (Copiar-Pegar)** con un **Harness de Ingeniería de Prompts** basado en la metodología del artículo de referencia (*Oxair*: *"How to Create Your Own AI Prompt Generator That Works Forever"*).

Promptera está diseñado para ejecutarse **100% local y privado** con aceleración de hardware **Metal** en tu procesador **Apple Silicon (M4)** utilizando modelos locales vía **Ollama**.

[![CI](https://github.com/lucasrafaldini/promptera/workflows/CI/badge.svg)](https://github.com/lucasrafaldini/promptera/actions)
[![Release](https://github.com/lucasrafaldini/promptera/workflows/Release/badge.svg)](https://github.com/lucasrafaldini/promptera/actions)
[![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-macOS%2014%2B-lightgrey.svg)](https://apple.com/macos)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

**🌐 Idiomas / Languages / Idiomas:** [English](README.md) • [Português](README.pt.md) • [Español](README.es.md)

---

## 📸 Capturas de Pantalla

Descarga el `.dmg` más reciente en [Releases](https://github.com/lucasrafaldini/Promptera/releases/latest).

| | |
|---|---|
| ![Generador — Aurora (oscuro)](docs/screenshots/01-gerador-aurora-escuro.png) | ![Historial de clipboard — Océano (claro)](docs/screenshots/03-clipboard-oceano-claro.png) |
| *Generador — Aurora (oscuro)* | *Historial de clipboard — Océano (claro)* |
| ![Configuración con 5 temas de color — Atardecer (oscuro)](docs/screenshots/04-configuracoes-temas-por-do-sol-escuro.png) | ![Generador — Aurora (claro)](docs/screenshots/02-gerador-aurora-claro.png) |
| *Configuración con 5 temas de color — Atardecer (oscuro)* | *Generador — Aurora (claro)* |

---

## 🌟 Características Principales

### 1. Acceso Directo desde Menu Bar
- Icono elegante en la barra de menús de macOS (`MenuBarExtra` nativo)
- Sin contaminación en el Dock (`LSUIElement = true`)
- Interfaz SwiftUI rápida y responsiva con soporte Dark/Light Mode
- Transiciones animadas entre pestañas

### 2. Historial de Clipboard Integrado
- Monitorización continua en segundo plano de `NSPasteboard`
- Historial buscable de recortes recientes de texto y código
- Búsqueda difusa en tiempo real: ordena primero los mejores resultados, ignora mayúsculas/acentos y resalta los caracteres encontrados
- 1-clic para cargar cualquier ítem como contexto para generar el prompt
- 1-clic para copiar el Master Prompt generado de vuelta al clipboard
- Acciones vía menú contextual (clic derecho)
- Persistencia local cifrada entre sesiones

### 3. Harness de Creación de Prompts (Metodología Oxair)
- **Loop Oxair (Genera → Critica → Refina):** La IA genera un borrador, audita sus propios fallos y premisas implícitas, y sintetiza un Master Prompt blindado
- **Modo Modular:** Añade variables dinámicas (`{{variable}}`) para transformar el prompt en template reutilizable
- **Modo Directo:** Master Prompt estructurado en una sola pasada
- **Presets de Dominio:** Configuraciones listas para:
  - 🛠️ **Ingeniería de Software** — Arquitectura, refactorización, tests, documentación
  - 🏗️ **System Design & DevOps** — Sistemas distribuidos, bases de datos, microservicios
  - 🧠 **Análisis Profundo & Raciocinio** — Problemas complejos, síntesis, toma de decisiones
  - ✍️ **Copywriting & Contenido** — Copy persuasivo, artículos, documentación
  - ✨ **Universal (Master)** — Cualquier objetivo general

### 4. Optimizado para Apple Silicon M4
- Detecta y conecta al servidor local Ollama (`http://127.0.0.1:11434`)
- Selección automática de los mejores modelos para M4 (`qwen2.5-coder:7b`, `llama3.1`, `phi4-mini`, `deepseek-coder-v2`)
- Streaming de tokens en tiempo real
- 100% local — ningún dato sale de tu Mac

### 5. Configuraciones Persistentes
- Modelo, preset y modo guardados automáticamente
- URL de Ollama configurable
- Exportación/Importación completa (JSON)
  - Prompts generados y biblioteca de prompts
  - Historial de clipboard
  - Configuraciones

### 6. Biblioteca de Prompts
- Cada generación exitosa se guarda automáticamente
- Pestaña **Biblioteca** dedicada con búsqueda difusa, edición, eliminación y “cargar en el generador”
- Cada elemento conserva la entrada original, el Master Prompt, el preset, el modo y el modelo
- Almacenada cifrada e incluida en la exportación/importación

### 7. Accesibilidad, Idiomas y Temas
- Etiquetas, pistas, traits y acciones personalizadas de VoiceOver en las pantallas principales
- Interfaz en **español**, **inglés** y **portugués**, cambiable en Configuración sin reiniciar
- Cinco temas de color, apariencia clara/oscura/sistema y color de acento personalizado

### 8. Actualizaciones Automáticas
- Actualizador [Sparkle 2](https://sparkle-project.org) con appcasts firmados en Ed25519
- Comprobación automática opcional y “Buscar Actualizaciones” en Configuración

### 9. Interfaz de Línea de Comandos (CLI)
```bash
# Generar a partir del texto proporcionado:
swift run promptera "Crear un microservicio de autenticación JWT en Go"

# O usar el contenido actual del clipboard:
swift run promptera --clipboard
```

---

## 🚀 Cómo Ejecutar

### Prerrequisitos
- macOS 14.0+ (Sonoma)
- [Ollama](https://ollama.ai) instalado
- Modelos recomendados: `ollama pull qwen2.5-coder:7b llama3.1 phi4-mini`

### 1. Iniciar Ollama
```bash
ollama serve
```

### 2. Abrir la App en Menu Bar
```bash
# Opción A: Build y run directo
swift run PrompteraApp

# Opción B: Build del .app nativo
./scripts/build_app.sh
open build/Promptera.app
```

### 3. (Opcional) Instalar en /Applications
```bash
cp -R build/Promptera.app /Applications/
```

Las releases se compilan, firman y notarizan con el workflow descrito en
[`docs/RELEASING.md`](docs/RELEASING.md), incluida la generación del appcast de Sparkle.

---

## 🧪 Tests

```bash
# Todos los tests (unitarios + E2E)
swift test

# Solo tests unitarios rápidos
swift test --filter "PrompteraKitTests"

# Con cobertura (requiere llvm-cov)
swift test --enable-code-coverage
xcrun llvm-cov export -format="lcov" .build/debug/PrompteraKitTests.xctest/Contents/MacOS/PrompteraKitTests -instr-profile .build/debug/codecov/default.profdata > coverage.lcov
```

La suite tiene actualmente **94 tests**, cubriendo portapapeles, búsqueda difusa,
internacionalización, biblioteca de prompts, cifrado y el harness Oxair.

---

## 🛠️ Estructura del Código

```
promptera/
├── Package.swift                     # Configuración Swift Package (Sparkle + resources)
├── Sources/
│   ├── PrompteraKit/                 # Librería Core (reutilizable)
│   │   ├── Models.swift              # Modelos, presets e ítems de biblioteca
│   │   ├── ClipboardManager.swift    # Monitorización y ranking de NSPasteboard
│   │   ├── FuzzyMatcher.swift        # Puntuación de búsqueda difusa
│   │   ├── Localization.swift        # AppLanguage, LanguageStore y L10n
│   │   ├── DesignSystem.swift        # Temas, apariencia y color de acento
│   │   ├── EncryptionService.swift   # Persistencia local cifrada
│   │   ├── OllamaClient.swift        # Cliente HTTP con streaming
│   │   ├── PromptHarness.swift       # Motor de meta-prompting (Oxair)
│   │   ├── PrompteraState.swift      # Estado reactivo @MainActor
│   │   └── Resources/                # en.lproj, pt.lproj, es.lproj
│   ├── PrompteraApp/                 # App macOS (SwiftUI MenuBar)
│   │   ├── PrompteraApp.swift        # Entry point MenuBarExtra
│   │   ├── UpdateController.swift    # Wrapper de Sparkle
│   │   └── Views/
│   │       ├── MainMenuView.swift    # Ventana principal, ajustes y pestañas
│   │       ├── PromptGeneratorView.swift # Editor, presets y streaming
│   │       ├── PromptLibraryView.swift   # Prompts guardados, búsqueda y editor
│   │       └── ClipboardHistoryView.swift # Historial de copiar/pegar
│   └── PrompteraCLI/                 # Interfaz CLI de terminal
│       └── main.swift                # Ejecutable de línea de comandos
├── Tests/
│   └── PrompteraKitTests/            # 94 tests (unitarios + E2E)
├── scripts/
│   ├── build_app.sh                  # Script de build para Promptera.app
│   ├── sign_app.sh                   # Firma con Developer ID
│   └── notarize.sh                   # Notarización y stapling
├── docs/RELEASING.md                 # Guía de release, firma y Sparkle
├── .github/
│   ├── workflows/                    # CI/CD GitHub Actions
│   └── ISSUE_TEMPLATE/               # Plantillas de issues
└── build/
    └── Promptera.app                 # App compilado
```

---

## ⌨️ Atajos de Teclado

| Atajo | Acción |
|-------|--------|
| `⌘⏎` | Generar Master Prompt |
| `⎋` | Cancelar generación |
| `⏎` / `⎋` | Guardar / cancelar en el editor de la biblioteca |

---

## 🤝 Contribuir

¡Nos encantan las contribuciones! Consulta nuestra [Guía de Contribución](CONTRIBUTING.md) para empezar.

### Good First Issues
- [Atajo global de teclado](https://github.com/lucasrafaldini/Promptera/issues/3)
- [Múltiples proveedores LLM](https://github.com/lucasrafaldini/Promptera/issues/6)
- [Nuevos presets de dominio](https://github.com/lucasrafaldini/Promptera/issues?q=label%3Aenhancement)

### Hacktoberfest
¡Este proyecto participa en **Hacktoberfest**! Los issues marcados con `hacktoberfest` son ideales para contribuciones durante el evento.

---

## 📄 Licencia

Licencia MIT - ver [LICENSE](LICENSE) para detalles.

---

## 🙏 Agradecimientos

- **Oxair** por la metodología de ingeniería de prompts
- **Ollama** por la inferencia local increíble
- **Apple** por Silicon y frameworks nativos
- **Comunidad Swift** por las herramientas open source

---

## 📞 Soporte

- 🐛 [Reportar Bug](https://github.com/lucasrafaldini/promptera/issues/new?template=bug_report.md)
- 💡 [Solicitar Feature](https://github.com/lucasrafaldini/promptera/issues/new?template=feature_request.md)
- 💬 [Discusiones](https://github.com/lucasrafaldini/promptera/discussions)

---

**Hecho con ❤️ para la comunidad de desarrolladores Apple Silicon**