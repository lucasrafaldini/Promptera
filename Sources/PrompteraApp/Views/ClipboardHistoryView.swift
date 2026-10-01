import SwiftUI
import PrompteraKit

public struct ClipboardHistoryView: View {
    @ObservedObject var clipboardManager: ClipboardManager
    @ObservedObject var state: PrompteraState
    
    public init(clipboardManager: ClipboardManager, state: PrompteraState) {
        self.clipboardManager = clipboardManager
        self.state = state
    }
    
    public var body: some View {
        VStack(spacing: 12) {
            // Header with stats
            HStack {
                Label("Histórico de Clipboard", systemImage: "doc.on.clipboard.fill")
                    .font(.headline.weight(.semibold))
                
                Spacer()
                
                HStack(spacing: 12) {
                    StatBadge(label: "Itens", value: "\(clipboardManager.filteredHistory.count)")
                    
                    if !clipboardManager.searchQuery.isEmpty {
                        StatBadge(label: "Filtrados", value: "\(clipboardManager.filteredHistory.count) de \(clipboardManager.history.count)")
                    }
                }
            }
            
            // Search & Actions Bar
            SearchActionBar(clipboardManager: clipboardManager)
            
            // Content
            if clipboardManager.filteredHistory.isEmpty {
                EmptyStateView(hasSearch: !clipboardManager.searchQuery.isEmpty)
            } else {
                ClipboardListView(
                    items: clipboardManager.filteredHistory,
                    onSelect: { item in state.useClipboardItem(item) },
                    onDelete: { id in clipboardManager.removeItem(id: id) }
                )
            }
        }
        .padding(16)
    }
}

struct StatBadge: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.callout.weight(.bold))
                .foregroundColor(.primary)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

struct SearchActionBar: View {
    @ObservedObject var clipboardManager: ClipboardManager
    
    var body: some View {
        HStack(spacing: 10) {
            // Search Field
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 14, weight: .medium))
                
                TextField("Buscar no histórico...", text: $clipboardManager.searchQuery)
                    .textFieldStyle(.plain)
                    .font(.callout)
                
                if !clipboardManager.searchQuery.isEmpty {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            clipboardManager.searchQuery = ""
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
            )
            
            // Clear Button
            if !clipboardManager.history.isEmpty {
                Button {
                    clipboardManager.clearHistory()
                } label: {
                    Label("Limpar Tudo", systemImage: "trash")
                        .font(.callout.weight(.medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .help("Remove todos os itens do histórico")
            }
        }
    }
}

struct EmptyStateView: View {
    let hasSearch: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Color.secondary.opacity(0.1))
                    .frame(width: 80, height: 80)
                
                Image(systemName: hasSearch ? "magnifyingglass" : "doc.on.clipboard")
                    .font(.system(size: 32, weight: .light))
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 6) {
                Text(hasSearch ? "Nenhum resultado encontrado" : "Histórico vazio")
                    .font(.title3.weight(.medium))
                    .foregroundColor(.primary)
                
                Text(hasSearch ? 
                    "Tente ajustar sua busca ou limpe o filtro." : 
                    "Copie textos em qualquer app\npara vê-los aparecer aqui automaticamente.")
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            if hasSearch {
                Button("Limpar busca") {
                    // This will be handled by the parent view
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(32)
    }
}

struct ClipboardListView: View {
    let items: [ClipboardItem]
    let onSelect: (ClipboardItem) -> Void
    let onDelete: (UUID) -> Void
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(items) { item in
                    ClipboardItemCard(
                        item: item,
                        onSelect: { onSelect(item) },
                        onDelete: { onDelete(item.id) }
                    )
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .trailing)),
                        removal: .opacity.combined(with: .move(edge: .leading))
                    ))
                }
            }
            .padding(.vertical, 4)
        }
    }
}

struct ClipboardItemCard: View {
    let item: ClipboardItem
    let onSelect: () -> Void
    let onDelete: () -> Void
    @State private var isHovered = false
    @State private var showActions = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Content
            Text(item.preview)
                .font(.system(.body, design: .default))
                .lineLimit(4)
                .foregroundColor(.primary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Meta info
            HStack(spacing: 16) {
                Label {
                    Text(item.timestamp, style: .time)
                        .font(.caption)
                        .foregroundColor(.secondary)
                } icon: {
                    Image(systemName: "clock")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Label {
                    Text("\(item.characterCount) chars")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } icon: {
                    Image(systemName: "character")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if item.lineCount > 1 {
                    Label {
                        Text("\(item.lineCount) linhas")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } icon: {
                        Image(systemName: "list.bullet")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Actions - always visible but subtle, more prominent on hover
                HStack(spacing: 6) {
                    Button(action: onSelect) {
                        Image(systemName: "arrow.up.forward.app.fill")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Usar como entrada para gerar prompt")
                    .keyboardShortcut("u", modifiers: .command)
                    
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Remover do histórico")
                    .tint(.red)
                }
                .opacity(isHovered || showActions ? 1 : 0.5)
                .scaleEffect(isHovered || showActions ? 1 : 0.9)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isHovered ? Color(NSColor.selectedContentBackgroundColor).opacity(0.2) : Color(NSColor.controlBackgroundColor).opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isHovered ? Color.blue.opacity(0.3) : Color.secondary.opacity(0.1), lineWidth: 1)
        )
        .scaleEffect(isHovered ? 1.01 : 1.0)
        .shadow(color: .black.opacity(isHovered ? 0.08 : 0), radius: isHovered ? 8 : 0, x: 0, y: 4)
        .onHover { hovering in
            withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                isHovered = hovering
            }
        }
        .onTapGesture(count: 2) {
            onSelect()
        }
        .contextMenu {
            Button("Usar como entrada") {
                onSelect()
            }
            Divider()
            Button("Copiar conteúdo") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(item.content, forType: .string)
            }
            Divider()
            Button("Remover", role: .destructive) {
                onDelete()
            }
        }
        .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isHovered)
    }
}