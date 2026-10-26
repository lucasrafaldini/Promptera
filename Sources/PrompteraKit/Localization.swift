import Foundation
import Observation

/// Languages supported by the app. `.system` follows the macOS preference.
public enum AppLanguage: String, CaseIterable, Identifiable, Codable, Sendable {
    case system
    case en
    case pt
    case es

    public var id: String { rawValue }

    /// Locale code used to pick a `.lproj` bundle. `nil` means "follow the system".
    public var code: String? {
        self == .system ? nil : rawValue
    }

    public var displayName: String {
        switch self {
        case .system: return L10n.t("Sistema")
        case .en: return "English"
        case .pt: return "Português"
        case .es: return "Español"
        }
    }
}

/// Persists the user's language preference and resolves the matching bundle at runtime.
@Observable
public final class LanguageStore {
    public static let shared = LanguageStore()

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let languageKey = "promptera_language"

    public var language: AppLanguage {
        didSet {
            defaults.set(language.rawValue, forKey: languageKey)
            // Keep Apple's own UI (menus, panels) in sync on the next launch.
            if let code = language.code {
                defaults.set([code], forKey: "AppleLanguages")
            } else {
                defaults.removeObject(forKey: "AppleLanguages")
            }
        }
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.language = defaults.string(forKey: languageKey)
            .flatMap(AppLanguage.init(rawValue:)) ?? .system
    }
}

/// Small localization facade. Keys are the Portuguese source strings, so a missing
/// translation safely falls back to the original text instead of showing a raw key.
public enum L10n {
    public static var bundle: Bundle {
        guard let code = LanguageStore.shared.language.code,
              let path = Bundle.module.path(forResource: code, ofType: "lproj"),
              let localized = Bundle(path: path) else {
            return .module
        }
        return localized
    }

    public static func t(_ key: String) -> String {
        NSLocalizedString(key, bundle: bundle, comment: "")
    }

    public static func t(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: NSLocalizedString(key, bundle: bundle, comment: ""), locale: Locale.current, arguments: arguments)
    }
}
