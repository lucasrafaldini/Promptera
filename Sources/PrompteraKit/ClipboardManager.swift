import Foundation
import AppKit

@MainActor
public final class ClipboardManager: ObservableObject {
    @Published public private(set) var history: [ClipboardItem] = []
    @Published public var searchQuery: String = ""
    @Published public var isMonitoring: Bool = false
    
    private let pasteboard = NSPasteboard.general
    private var lastChangeCount: Int
    private var monitorTimer: Timer?
    private let maxHistoryItems: Int
    private let storageKey = "promptera_clipboard_history"
    
    public init(maxHistoryItems: Int = 50) {
        self.maxHistoryItems = maxHistoryItems
        self.lastChangeCount = pasteboard.changeCount
        loadPersistedHistory()
        startMonitoring()
        
        // Check initial pasteboard content
        checkPasteboard()
    }
    
    deinit {
        monitorTimer?.invalidate()
    }
    
    public var filteredHistory: [ClipboardItem] {
        if searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return history
        }
        let lower = searchQuery.lowercased()
        return history.filter { $0.content.lowercased().contains(lower) }
    }
    
    public var latestItem: ClipboardItem? {
        history.first
    }
    
    public func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true
        monitorTimer = Timer.scheduledTimer(withTimeInterval: 0.75, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkPasteboard()
            }
        }
    }
    
    public func stopMonitoring() {
        monitorTimer?.invalidate()
        monitorTimer = nil
        isMonitoring = false
    }
    
    public func checkPasteboard() {
        let currentCount = pasteboard.changeCount
        guard currentCount != lastChangeCount else { return }
        lastChangeCount = currentCount
        
        guard let text = pasteboard.string(forType: .string) else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        // Avoid duplicate consecutive entry
        if let first = history.first, first.content == text {
            return
        }
        
        // If already in history somewhere, remove old occurrence and move to top
        var updated = history.filter { $0.content != text }
        let newItem = ClipboardItem(content: text)
        updated.insert(newItem, at: 0)
        
        if updated.count > maxHistoryItems {
            updated = Array(updated.prefix(maxHistoryItems))
        }
        
        self.history = updated
        persistHistory()
    }
    
    public func copyToClipboard(_ text: String) {
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        lastChangeCount = pasteboard.changeCount
        
        var updated = history.filter { $0.content != text }
        let item = ClipboardItem(content: text)
        updated.insert(item, at: 0)
        if updated.count > maxHistoryItems {
            updated = Array(updated.prefix(maxHistoryItems))
        }
        self.history = updated
        persistHistory()
    }
    
    public func removeItem(id: UUID) {
        history.removeAll { $0.id == id }
        persistHistory()
    }
    
    public func clearHistory() {
        history.removeAll()
        persistHistory()
    }
    
    private func persistHistory() {
        do {
            let data = try JSONEncoder().encode(history)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            // Non-critical persistence failure
        }
    }
    
    private func loadPersistedHistory() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        do {
            let loaded = try JSONDecoder().decode([ClipboardItem].self, from: data)
            self.history = loaded
        } catch {
            self.history = []
        }
    }
}
