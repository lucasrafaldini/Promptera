import SwiftUI
import PrompteraKit

public struct ClipboardHistoryView: View {
    @ObservedObject var clipboardManager: ClipboardManager
    @ObservedObject var state: PrompteraState
    @AppStorage("promptera_selected_tab") private var selectedTab: PrompteraTab = .clipboard
    
    public init(clipboardManager: ClipboardManager, state: PrompteraState) {
        self.clipboardManager = clipboardManager
        self.state = state
    }
    
    public var body: some View {
        // Filter once per render (the header and the list both need it).
        let items = clipboardManager.filteredHistory
        let isSearching = !clipboardManager.searchQuery.isEmpty
        
        VStack(spacing: 12) {
            // Header with stats
            HStack {
                Label("Histórico de Clipboard", systemImage: "doc.on.clipboard.fill")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(PrompteraColors.textPrimary)
                
                Spacer()
                
                if isSearching {
                    StatBadge(label: "Filtrados", value: "\(items.count) de \(clipboardManager.history.count)")
                } else {
                    StatBadge(label: "Itens", value: "\(items.count)")
                }
            }
            
            // Search & Actions Bar
            SearchActionBar(clipboardManager: clipboardManager)
            
            // Content
            if items.isEmpty {
                EmptyStateView(hasSearch: isSearching) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        clipboardManager.searchQuery = ""
                    }
                }
            } else {
                ClipboardListView(
                    items: items,
                    onSelect: { item in
                        // Load it and jump straight to the generator.
                        state.useClipboardItem(item)
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                            selectedTab = .generator
                        }
                    },
                    onDelete: { id in
                        withAnimation(.easeOut(duration: 0.2)) {
                            clipboardManager.removeItem(id: id)
                        }
                    }
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
                .foregroundStyle(PrompteraColors.textPrimary)
            Text(label)
                .font(.caption2)
                .foregroundStyle(PrompteraColors.textSecondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(PrompteraColors.surfaceSecondary)
        .cornerRadius(8)
    }
}

struct SearchActionBar: View {
    @ObservedObject var clipboardManager: ClipboardManager
    @State private var confirmClear = false
    
    var body: some View {
        HStack(spacing: 10) {
            // Search Field
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(PrompteraColors.textSecondary)
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
                            .foregroundStyle(PrompteraColors.textSecondary)
                    }
                    .buttonStyle(.plain)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(PrompteraColors.surfaceSecondary)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(PrompteraColors.borderSubtle, lineWidth: 1)
            )
            
            // Clear Button
            if !clipboardManager.history.isEmpty {
                Button {
                    confirmClear = true
                } label: {
                    Label("Limpar Tudo", systemImage: "trash")
                        .font(.callout.weight(.medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .help("Remove todos os itens do histórico")
                .confirmationDialog(
                    "Apagar todo o histórico do clipboard?",
                    isPresented: $confirmClear
                ) {
                    Button("Apagar \(clipboardManager.history.count) itens", role: .destructive) {
                        withAnimation { clipboardManager.clearHistory() }
                    }
                    Button("Cancelar", role: .cancel) {}
                } message: {
                    Text("Essa ação não pode ser desfeita.")
                }
            }
        }
    }
}

struct EmptyStateView: View {
    let hasSearch: Bool
    var onClearSearch: () -> Void = {}
    
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(PrompteraColors.surfaceTertiary)
                    .frame(width: 80, height: 80)
                
                Image(systemName: hasSearch ? "magnifyingglass" : "doc.on.clipboard")
                    .font(.system(size: 32, weight: .light))
                    .foregroundStyle(PrompteraColors.textSecondary)
            }
            
            VStack(spacing: 6) {
                Text(hasSearch ? "Nenhum resultado encontrado" : "Histórico vazio")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(PrompteraColors.textPrimary)
                
                Text(hasSearch ? 
                    "Tente ajustar sua busca ou limpe o filtro." : 
                    "Copie textos em qualquer app\npara vê-los aparecer aqui automaticamente.")
                    .font(.callout)
                    .foregroundStyle(PrompteraColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            if hasSearch {
                Button("Limpar busca", action: onClearSearch)
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
                .foregroundStyle(PrompteraColors.textPrimary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Meta info
            HStack(spacing: 16) {
                Label {
                    Text(item.timestamp, style: .time)
                        .font(.caption)
                        .foregroundStyle(PrompteraColors.textSecondary)
                } icon: {
                    Image(systemName: "clock")
                        .font(.caption)
                        .foregroundStyle(PrompteraColors.textSecondary)
                }
                
                Label {
                    Text("\(item.characterCount) chars")
                        .font(.caption)
                        .foregroundStyle(PrompteraColors.textSecondary)
                } icon: {
                    Image(systemName: "character")
                        .font(.caption)
                        .foregroundStyle(PrompteraColors.textSecondary)
                }
                
                if item.lineCount > 1 {
                    Label {
                        Text("\(item.lineCount) linhas")
                            .font(.caption)
                            .foregroundStyle(PrompteraColors.textSecondary)
                    } icon: {
                        Image(systemName: "list.bullet")
                            .font(.caption)
                            .foregroundStyle(PrompteraColors.textSecondary)
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
                    .help("Usar como entrada para gerar prompt (ou clique duplo)")
                    
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Remover do histórico")
                    .tint(PrompteraColors.error)
                }
                .opacity(isHovered || showActions ? 1 : 0.5)
                .scaleEffect(isHovered || showActions ? 1 : 0.9)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isHovered ? PrompteraColors.surfaceSelected : PrompteraColors.surfaceTertiary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isHovered ? PrompteraColors.brandPrimary.opacity(0.3) : PrompteraColors.borderSubtle, lineWidth: 1)
        )
        .scaleEffect(isHovered ? 1.01 : 1.0)
        .shadow(color: isHovered ? PrompteraColors.shadowBrand : PrompteraColors.shadowSubtle, radius: isHovered ? 8 : 0, x: 0, y: 4)
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