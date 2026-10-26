import SwiftUI
import PrompteraKit

public struct PromptLibraryView: View {
    @ObservedObject var state: PrompteraState
    @AppStorage("promptera_selected_tab") private var selectedTab: PrompteraTab = .library

    @State private var searchQuery = ""
    @State private var editingItem: PromptLibraryItem?
    @State private var confirmClear = false

    public init(state: PrompteraState) {
        self.state = state
    }

    private var items: [PromptLibraryItem] {
        state.libraryItems(matching: searchQuery)
    }

    public var body: some View {
        let filtered = items
        let isSearching = !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        VStack(spacing: 12) {
            HStack {
                Label(L10n.t("Biblioteca de Prompts"), systemImage: "books.vertical.fill")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(PrompteraColors.textPrimary)

                Spacer()

                Text(isSearching
                     ? L10n.t("%d de %d prompts", filtered.count, state.library.count)
                     : L10n.t("%d prompts", filtered.count))
                    .font(.caption)
                    .foregroundStyle(PrompteraColors.textSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(PrompteraColors.surfaceSecondary)
                    .cornerRadius(8)
            }

            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(PrompteraColors.textSecondary)
                        .font(.system(size: 14, weight: .medium))

                    TextField(L10n.t("Buscar na biblioteca..."), text: $searchQuery)
                        .textFieldStyle(.plain)
                        .font(.callout)
                        .accessibilityLabel(L10n.t("Buscar na biblioteca"))
                        .accessibilityHint(L10n.t("Filtra os prompts salvos por título, entrada ou resultado."))

                    if !searchQuery.isEmpty {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                searchQuery = ""
                            }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(PrompteraColors.textSecondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(L10n.t("Limpar busca"))
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

                if !state.library.isEmpty {
                    Button {
                        confirmClear = true
                    } label: {
                        Label(L10n.t("Limpar Tudo"), systemImage: "trash")
                            .font(.callout.weight(.medium))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                    .help(L10n.t("Remove todos os prompts salvos"))
                    .accessibilityHint(L10n.t("Remove permanentemente todos os prompts da biblioteca."))
                    .confirmationDialog(
                        L10n.t("Apagar todos os prompts salvos?"),
                        isPresented: $confirmClear
                    ) {
                        Button(L10n.t("Apagar %d prompts", state.library.count), role: .destructive) {
                            withAnimation { state.clearLibrary() }
                        }
                        Button(L10n.t("Cancelar"), role: .cancel) {}
                    } message: {
                        Text(L10n.t("Essa ação não pode ser desfeita."))
                    }
                }
            }

            if filtered.isEmpty {
                emptyState(isSearching: isSearching)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(filtered) { item in
                            PromptLibraryCard(
                                item: item,
                                onLoad: { load(item) },
                                onEdit: { editingItem = item },
                                onCopy: { copy(item) },
                                onDelete: {
                                    withAnimation(.easeOut(duration: 0.2)) {
                                        state.deleteLibraryItem(id: item.id)
                                    }
                                }
                            )
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(16)
        .sheet(item: $editingItem) { item in
            PromptLibraryEditor(item: item) { updated in
                state.updateLibraryItem(updated)
                editingItem = nil
            } onCancel: {
                editingItem = nil
            }
        }
    }

    private func emptyState(isSearching: Bool) -> some View {
        VStack(spacing: 16) {
            Spacer()

            ZStack {
                Circle()
                    .fill(PrompteraColors.surfaceTertiary)
                    .frame(width: 80, height: 80)

                Image(systemName: isSearching ? "magnifyingglass" : "books.vertical")
                    .font(.system(size: 32, weight: .light))
                    .foregroundStyle(PrompteraColors.textSecondary)
            }

            VStack(spacing: 6) {
                Text(isSearching ? L10n.t("Nenhum prompt encontrado") : L10n.t("Biblioteca vazia"))
                    .font(.title3.weight(.medium))
                    .foregroundStyle(PrompteraColors.textPrimary)

                Text(isSearching
                     ? L10n.t("Tente outro termo ou limpe o filtro.")
                     : L10n.t("Cada Master Prompt gerado é salvo aqui automaticamente."))
                    .font(.callout)
                    .foregroundStyle(PrompteraColors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            if isSearching {
                Button(L10n.t("Limpar busca")) {
                    searchQuery = ""
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(32)
    }

    private func load(_ item: PromptLibraryItem) {
        state.loadLibraryItem(item)
        withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
            selectedTab = .generator
        }
    }

    private func copy(_ item: PromptLibraryItem) {
        state.clipboardManager.copyToClipboard(item.output)
        state.setStatus(L10n.t("Prompt copiado para o clipboard"), kind: .success)
    }
}

struct PromptLibraryCard: View {
    let item: PromptLibraryItem
    let onLoad: () -> Void
    let onEdit: () -> Void
    let onCopy: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false

    private var outputPreview: String {
        let oneLine = item.output
            .prefix(400)
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return String(oneLine.prefix(220))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(item.title)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(PrompteraColors.textPrimary)
                    .lineLimit(1)

                Spacer()

                Text(item.updatedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(PrompteraColors.textSecondary)
            }

            Text(outputPreview)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(PrompteraColors.textSecondary)
                .lineLimit(4)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 10) {
                if let preset = item.preset {
                    LibraryBadge(text: preset.displayTitle, icon: preset.icon)
                }
                if let mode = item.mode {
                    LibraryBadge(text: mode.displayName, icon: "arrow.triangle.2.circlepath")
                }
                LibraryBadge(text: item.model, icon: "cpu")

                Spacer()

                HStack(spacing: 6) {
                    Button(action: onLoad) {
                        Image(systemName: "arrow.up.forward.app.fill")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help(L10n.t("Carregar no gerador"))
                    .accessibilityLabel(L10n.t("Carregar prompt no gerador"))

                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help(L10n.t("Editar prompt"))
                    .accessibilityLabel(L10n.t("Editar prompt"))

                    Button(action: onCopy) {
                        Image(systemName: "doc.on.doc.fill")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help(L10n.t("Copiar resultado"))
                    .accessibilityLabel(L10n.t("Copiar resultado do prompt"))

                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help(L10n.t("Remover da biblioteca"))
                    .accessibilityLabel(L10n.t("Remover prompt da biblioteca"))
                    .tint(PrompteraColors.error)
                }
                .opacity(isHovered ? 1 : 0.6)
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
        .onHover { hovering in
            withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                isHovered = hovering
            }
        }
        .onTapGesture(count: 2, perform: onLoad)
        .contextMenu {
            Button(L10n.t("Carregar no gerador"), action: onLoad)
            Button(L10n.t("Editar"), action: onEdit)
            Button(L10n.t("Copiar resultado"), action: onCopy)
            Divider()
            Button(L10n.t("Remover"), role: .destructive, action: onDelete)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(item.title)
        .accessibilityHint(L10n.t("Clique duas vezes para carregar este prompt no gerador."))
    }
}

struct LibraryBadge: View {
    let text: String
    let icon: String

    var body: some View {
        Label(text, systemImage: icon)
            .font(.caption2)
            .foregroundStyle(PrompteraColors.textSecondary)
            .lineLimit(1)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(PrompteraColors.surfaceSecondary)
            .cornerRadius(6)
    }
}

struct PromptLibraryEditor: View {
    let item: PromptLibraryItem
    let onSave: (PromptLibraryItem) -> Void
    let onCancel: () -> Void

    @State private var title: String
    @State private var input: String
    @State private var output: String

    init(
        item: PromptLibraryItem,
        onSave: @escaping (PromptLibraryItem) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.item = item
        self.onSave = onSave
        self.onCancel = onCancel
        _title = State(initialValue: item.title)
        _input = State(initialValue: item.input)
        _output = State(initialValue: item.output)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label(L10n.t("Editar Prompt"), systemImage: "pencil")
                    .font(.headline)
                    .foregroundStyle(PrompteraColors.textPrimary)

                Spacer()

                Button(L10n.t("Cancelar"), action: onCancel)
                    .keyboardShortcut(.cancelAction)

                Button(L10n.t("Salvar")) {
                    var updated = item
                    updated.title = title
                    updated.input = input
                    updated.output = output
                    onSave(updated)
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.t("Título"))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(PrompteraColors.textSecondary)
                TextField(L10n.t("Título do prompt"), text: $title)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel(L10n.t("Título do prompt"))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.t("Entrada original"))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(PrompteraColors.textSecondary)
                TextEditor(text: $input)
                    .font(.system(.callout, design: .monospaced))
                    .frame(minHeight: 80, maxHeight: 120)
                    .padding(6)
                    .background(PrompteraColors.surfacePrimary)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(PrompteraColors.borderDefault, lineWidth: 1)
                    )
                    .accessibilityLabel(L10n.t("Entrada original do prompt"))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.t("Master Prompt"))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(PrompteraColors.textSecondary)
                TextEditor(text: $output)
                    .font(.system(.callout, design: .monospaced))
                    .frame(minHeight: 180)
                    .padding(6)
                    .background(PrompteraColors.surfacePrimary)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(PrompteraColors.borderDefault, lineWidth: 1)
                    )
                    .accessibilityLabel(L10n.t("Master Prompt salvo"))
            }
        }
        .padding(20)
        .frame(width: 620, height: 620)
        .background(PrompteraColors.surfacePrimary)
    }
}
