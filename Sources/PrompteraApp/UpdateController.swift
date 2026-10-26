import Foundation
import Sparkle

/// Thin wrapper around Sparkle so the rest of the app does not need to know
/// whether the updater has been started yet.
@MainActor
final class UpdateController {
    static let shared = UpdateController()

    private var controller: SPUStandardUpdaterController?

    private init() {}

    func start() {
        guard controller == nil else { return }
        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }

    func checkForUpdates() {
        start()
        controller?.checkForUpdates(nil)
    }

    var canCheckForUpdates: Bool {
        controller?.updater.canCheckForUpdates ?? false
    }

    var automaticallyChecksForUpdates: Bool {
        get {
            start()
            return controller?.updater.automaticallyChecksForUpdates ?? true
        }
        set {
            start()
            controller?.updater.automaticallyChecksForUpdates = newValue
        }
    }
}
