import XCTest
@testable import PrompteraKit

final class LocalizationTests: XCTestCase {
    func testTranslationsResolveForEverySupportedLanguage() {
        let store = LanguageStore.shared
        let original = store.language
        defer { store.language = original }

        store.language = .pt
        XCTAssertEqual(L10n.t("Gerador"), "Gerador")
        XCTAssertEqual(L10n.t("Biblioteca"), "Biblioteca")

        store.language = .en
        XCTAssertEqual(L10n.t("Gerador"), "Generator")
        XCTAssertEqual(L10n.t("Biblioteca"), "Library")

        store.language = .es
        XCTAssertEqual(L10n.t("Gerador"), "Generador")
        XCTAssertEqual(L10n.t("Biblioteca"), "Biblioteca")
    }

    func testFormatArgumentsArePreserved() {
        let store = LanguageStore.shared
        let original = store.language
        defer { store.language = original }

        store.language = .en
        XCTAssertEqual(L10n.t("%d prompts", 3), "3 prompts")
        XCTAssertEqual(L10n.t("Tema %@", "Aurora"), "Aurora theme")
    }

    func testMissingKeyFallsBackToSourceString() {
        let store = LanguageStore.shared
        let original = store.language
        defer { store.language = original }

        store.language = .en
        XCTAssertEqual(L10n.t("Chave inexistente"), "Chave inexistente")
    }

    func testStatusAndErrorMessagesAreLocalized() {
        let store = LanguageStore.shared
        let original = store.language
        defer { store.language = original }

        store.language = .en
        XCTAssertEqual(L10n.t("Geração cancelada"), "Generation cancelled")
        XCTAssertEqual(L10n.t("Selecione um modelo local do Ollama."), "Select a local Ollama model.")
        XCTAssertEqual(L10n.t("Prompt concluído com sucesso!"), "Prompt completed successfully!")
        XCTAssertEqual(OllamaError.invalidURL.errorDescription, "Invalid Ollama server URL.")

        store.language = .es
        XCTAssertEqual(L10n.t("Geração cancelada"), "Generación cancelada")
        XCTAssertEqual(L10n.t("Selecione um modelo local do Ollama."), "Selecciona un modelo local de Ollama.")
        XCTAssertEqual(L10n.t("Prompt concluído com sucesso!"), "¡Prompt completado con éxito!")
        XCTAssertEqual(OllamaError.invalidURL.errorDescription, "URL del servidor de Ollama no válida.")
    }
}
