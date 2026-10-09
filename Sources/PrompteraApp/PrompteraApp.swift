import SwiftUI
import AppKit
import PrompteraKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        if let directory = ScreenshotRenderer.outputDirectory {
            ScreenshotRenderer.run(into: directory)
            NSApp.terminate(nil)
            return
        }
        // Set app as accessory (lives exclusively in the Menu Bar, no dock icon)
        NSApp.setActivationPolicy(.accessory)
        ThemeStore.shared.applyAppearance()
    }
}

@main
struct PrompteraApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    // Owned by the App (not the popover view) so clipboard monitoring starts at
    // launch instead of the first time the menu is opened.
    @StateObject private var state = ScreenshotRenderer.outputDirectory == nil
        ? PrompteraState()
        : PrompteraState(clipboardManager: ClipboardManager(persistent: false), autoRefresh: false)

    var body: some Scene {
        MenuBarExtra {
            MainMenuView(state: state)
        } label: {
            Image(nsImage: MenuBarIcon.image(generating: state.isGenerating))
        }
        .menuBarExtraStyle(.window)
    }
}
