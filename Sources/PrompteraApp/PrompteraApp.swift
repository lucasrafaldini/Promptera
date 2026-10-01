import SwiftUI
import AppKit
import PrompteraKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set app as accessory (lives exclusively in the Menu Bar, no dock icon)
        NSApp.setActivationPolicy(.accessory)
    }
}

@main
struct PrompteraApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        MenuBarExtra("Promptera", systemImage: "sparkles.rectangle.stack") {
            MainMenuView()
        }
        .menuBarExtraStyle(.window)
    }
}
