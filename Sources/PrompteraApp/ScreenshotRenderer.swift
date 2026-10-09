import SwiftUI
import AppKit
import PrompteraKit

/// Renders marketing screenshots of the popover with demo data, then quits.
/// Run with: PROMPTERA_SCREENSHOTS=<output-dir> Promptera.app/Contents/MacOS/PrompteraApp
/// Nothing from the user's real clipboard history or settings is used or modified.
@MainActor
enum ScreenshotRenderer {
    static let outputDirectory: URL? = ProcessInfo.processInfo.environment["PROMPTERA_SCREENSHOTS"]
        .map { URL(fileURLWithPath: $0, isDirectory: true) }

    private struct Shot {
        let name: String
        let tab: PrompteraTab
        let theme: PrompteraTheme
        let appearance: NSAppearance.Name
    }

    private static let shots: [Shot] = [
        Shot(name: "01-gerador-aurora-escuro", tab: .generator, theme: .aurora, appearance: .darkAqua),
        Shot(name: "02-gerador-aurora-claro", tab: .generator, theme: .aurora, appearance: .aqua),
        Shot(name: "03-clipboard-oceano-claro", tab: .clipboard, theme: .ocean, appearance: .aqua),
        Shot(name: "04-configuracoes-temas-por-do-sol-escuro", tab: .settings, theme: .sunset, appearance: .darkAqua),
        Shot(name: "05-gerador-floresta-escuro", tab: .generator, theme: .forest, appearance: .darkAqua),
    ]

    static func run(into directory: URL) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let themeStore = ThemeStore.shared
        let originalTheme = themeStore.theme
        let originalAppearance = themeStore.appearance

        let demoDefaults = UserDefaults(suiteName: "promptera.screenshots")!

        for shot in shots {
            // ThemeStore persists on set, so the user's choice is restored below.
            themeStore.theme = shot.theme
            demoDefaults.set(shot.tab.rawValue, forKey: "promptera_selected_tab")

            let state = makeDemoState()
            let root = MainMenuView(state: state).defaultAppStorage(demoDefaults)
            let hosting = NSHostingView(rootView: root)
            hosting.frame = NSRect(x: 0, y: 0, width: 600, height: 600)

            let window = KeyableWindow(contentRect: hosting.frame, styleMask: [.borderless], backing: .buffered, defer: false)
            window.appearance = NSAppearance(named: shot.appearance)
            window.contentView = hosting
            // On screen (AppKit won't make an off-screen window key) but invisible.
            window.alphaValue = 0
            window.ignoresMouseEvents = true
            window.setFrameOrigin(.zero)
            // Key, like the real popover, so prominent buttons get the theme tint.
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            RunLoop.main.run(until: Date().addingTimeInterval(1.0))
            hosting.layoutSubtreeIfNeeded()

            if let panel = capture(hosting) {
                let framed = frame(panel, theme: shot.theme, dark: shot.appearance == .darkAqua)
                write(panel, to: directory.appendingPathComponent("\(shot.name)-raw.png"))
                write(framed, to: directory.appendingPathComponent("\(shot.name).png"))
            }
            window.orderOut(nil)
        }

        themeStore.theme = originalTheme
        themeStore.appearance = originalAppearance
        demoDefaults.removePersistentDomain(forName: "promptera.screenshots")
    }

    // MARK: - Demo data

    private static func makeDemoState() -> PrompteraState {
        let clipboard = ClipboardManager(persistent: false)
        let now = Date()
        clipboard.mergeItems([
            ClipboardItem(content: "func fetchUser(id: UUID) async throws -> User {\n    let (data, _) = try await session.data(from: endpoint(id))\n    return try decoder.decode(User.self, from: data)\n}", timestamp: now.addingTimeInterval(-60)),
            ClipboardItem(content: "Preciso de um script em Python que sincronize um bucket S3 com uma pasta local, com retry exponencial e logs estruturados em JSON.", timestamp: now.addingTimeInterval(-240)),
            ClipboardItem(content: "SELECT customer_id, SUM(total) AS revenue\nFROM orders\nWHERE created_at >= NOW() - INTERVAL '30 days'\nGROUP BY customer_id\nORDER BY revenue DESC\nLIMIT 20;", timestamp: now.addingTimeInterval(-900)),
            ClipboardItem(content: "Escreva um post para o LinkedIn anunciando o lançamento da nossa API pública, tom confiante e sem clichês.", timestamp: now.addingTimeInterval(-1800)),
            ClipboardItem(content: "docker compose up -d --build && docker compose logs -f api", timestamp: now.addingTimeInterval(-3600)),
        ])

        let state = PrompteraState(
            clipboardManager: clipboard,
            ollamaClient: OllamaClient(baseURL: URL(string: "http://127.0.0.1:9")!),
            autoRefresh: false
        )
        state.availableModels = [
            OllamaModelInfo(name: "qwen2.5-coder:7b", size: 4_683_087_332),
            OllamaModelInfo(name: "llama3.1:latest", size: 4_920_753_328),
            OllamaModelInfo(name: "phi4-mini:latest", size: 2_491_876_774),
        ]
        state.isOllamaConnected = true
        state.selectedModel = "qwen2.5-coder:7b"
        state.selectedMode = .iterativeLoop
        state.selectedPreset = HarnessPreset.presets.first { $0.id == "coding" } ?? HarnessPreset.presets[0]
        state.inputText = "Preciso de um script em Python que sincronize um bucket S3 com uma pasta local, com retry exponencial e logs estruturados em JSON."
        state.outputText = """
        # ROLE & PERSONA
        Você é um Engenheiro de Software Sênior especialista em Python 3.12, AWS (boto3) e sistemas resilientes.

        # CONTEXTO & MISSÃO
        Implementar um sincronizador S3 ⇄ pasta local idempotente, executável via CLI.

        # TABELA DE DES-ADJETIVAÇÃO
        | Termo vago | Significado técnico | Regra estrita | Métrica de aceite |
        |---|---|---|---|
        | "retry exponencial" | Backoff 2^n com jitter | máx. 5 tentativas, teto 30 s | 0 falhas em 100 erros 503 simulados |
        | "logs estruturados" | 1 objeto JSON por linha | campos ts, level, key, bytes | `jq` valida 100% das linhas |
        """
        state.statusMessage = "Prompt concluído com sucesso!"
        return state
    }

    // MARK: - Rendering

    /// Captures at 2x (Retina) regardless of the offscreen window's backing scale.
    private static func capture(_ view: NSView) -> CGImage? {
        let scale = 2
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(view.bounds.width) * scale,
            pixelsHigh: Int(view.bounds.height) * scale,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ) else { return nil }
        rep.size = view.bounds.size
        view.cacheDisplay(in: view.bounds, to: rep)
        return rep.cgImage
    }

    /// Places the panel on a soft brand-gradient backdrop with rounded corners and a shadow.
    private static func frame(_ panel: CGImage, theme: PrompteraTheme, dark: Bool) -> CGImage {
        let scale = CGFloat(panel.width) / 600
        let canvas = CGSize(width: 1000 * scale, height: 800 * scale)
        let ctx = CGContext(
            data: nil, width: Int(canvas.width), height: Int(canvas.height), bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        let appearance = NSAppearance(named: dark ? .darkAqua : .aqua)!
        var colors: [CGColor] = []
        appearance.performAsCurrentDrawingAppearance {
            colors = theme.colors.map { NSColor($0).usingColorSpace(.sRGB)!.cgColor }
        }
        let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors as CFArray, locations: [0, 0.5, 1])!
        ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: canvas.height), end: CGPoint(x: canvas.width, y: 0), options: [])

        let rect = CGRect(x: (canvas.width - 600 * scale) / 2, y: (canvas.height - 600 * scale) / 2, width: 600 * scale, height: 600 * scale)
        let path = CGPath(roundedRect: rect, cornerWidth: 14 * scale, cornerHeight: 14 * scale, transform: nil)
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -18 * scale), blur: 50 * scale, color: CGColor(gray: 0, alpha: 0.45))
        ctx.addPath(path)
        ctx.setFillColor(CGColor(gray: dark ? 0.15 : 1, alpha: 1))
        ctx.fillPath()
        ctx.restoreGState()
        ctx.saveGState()
        ctx.addPath(path)
        ctx.clip()
        ctx.draw(panel, in: rect)
        ctx.restoreGState()
        return ctx.makeImage()!
    }

    private final class KeyableWindow: NSWindow {
        override var canBecomeKey: Bool { true }
        override var canBecomeMain: Bool { true }
        // Render at Retina scale even on a 1x display.
        override var backingScaleFactor: CGFloat { 2 }
    }

    private static func write(_ image: CGImage, to url: URL) {
        let rep = NSBitmapImageRep(cgImage: image)
        try? rep.representation(using: .png, properties: [:])?.write(to: url)
    }
}
