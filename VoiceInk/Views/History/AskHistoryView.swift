import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Ask Mode keeps its conversations separate from transcription history, but
/// uses the same selection, export, deletion, and analysis workflow.
struct AskHistoryView: View {
    @EnvironmentObject private var engine: VoiceInkEngine
    @EnvironmentObject private var recorderUIManager: RecorderUIManager
    @ObservedObject private var store = AskHistoryStore.shared

    @State private var searchText = ""
    @State private var expandedID: UUID?
    @State private var selectedConversationIDs = Set<UUID>()
    @State private var showDeleteConfirmation = false
    @State private var isPanelPresented = false
    @State private var panelMode: AskHistoryPanelMode = .analysis

    private let exportService = AskHistoryExportService()

    private var conversations: [AskConversation] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return store.conversations }
        return store.conversations.filter { conversation in
            conversation.title.localizedCaseInsensitiveContains(query)
                || conversation.messages.contains { $0.content.localizedCaseInsensitiveContains(query) }
        }
    }

    private var selectedConversations: [AskConversation] {
        store.conversations.filter { selectedConversationIDs.contains($0.id) }
    }

    private var allSelected: Bool {
        !conversations.isEmpty && conversations.allSatisfy { selectedConversationIDs.contains($0.id) }
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Divider()

            if conversations.isEmpty {
                emptyStateView
            } else {
                cardListView
            }

            if !selectedConversationIDs.isEmpty {
                Divider()
                selectionBar
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: selectedConversationIDs.isEmpty)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sidePanel(isPresented: $isPanelPresented) {
            AskHistoryAnalysisPanelView(
                conversations: selectedConversations,
                onClose: { isPanelPresented = false }
            )
            .id(selectedConversationIDs)
        }
        .alert("Delete Selected Chats?", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                deleteSelectedConversations()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone. Are you sure you want to delete \(selectedConversationIDs.count) chats?")
        }
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            NativeSearchField("Search chats", text: $searchText)
                .frame(maxWidth: .infinity)

            AppIconButton(
                systemName: "chart.bar.xaxis",
                help: "Analyze selected chats",
                size: 36,
                iconSize: 15,
                cornerRadius: AppTheme.Radius.pill,
                isDisabled: selectedConversationIDs.isEmpty
            ) {
                panelMode = .analysis
                isPanelPresented = true
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 6)
    }

    private var cardListView: some View {
        Form {
            ForEach(conversations) { conversation in
                Section {
                    AskHistoryCardRow(
                        conversation: conversation,
                        isExpanded: expandedID == conversation.id,
                        isChecked: selectedConversationIDs.contains(conversation.id),
                        onToggleExpand: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                expandedID = expandedID == conversation.id ? nil : conversation.id
                            }
                        },
                        onToggleCheck: { toggleSelection(conversation) },
                        onContinue: { open(conversation) }
                    )
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text(searchText.isEmpty ? "No chat history yet" : "No results found")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.secondary)
            Text(searchText.isEmpty ? "Your Ask Mode conversations will appear here" : "Try a different search term")
                .font(.system(size: 13))
                .foregroundStyle(.secondary.opacity(0.8))
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var selectionBar: some View {
        HStack(spacing: 16) {
            Text("\(selectedConversationIDs.count) selected")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)

            Spacer()

            Button {
                panelMode = .analysis
                isPanelPresented = true
            } label: {
                Label("Analyze", systemImage: "chart.bar.xaxis")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)

            Button {
                exportService.export(conversations: selectedConversations)
            } label: {
                Label("Export", systemImage: "square.and.arrow.up")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)

            Button { showDeleteConfirmation = true } label: {
                Label("Delete", systemImage: "trash")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.plain)
            .foregroundStyle(AppTheme.Status.error.opacity(0.80))

            Divider().frame(height: 16)

            Button(allSelected ? "Deselect All" : "Select All") {
                if allSelected {
                    selectedConversationIDs.removeAll()
                } else {
                    selectedConversationIDs.formUnion(conversations.map(\.id))
                }
            }
            .font(.system(size: 12, weight: .medium))
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 10)
        .background(AppTheme.Surface.window.shadow(color: .black.opacity(0.1), radius: 3, y: -2))
    }

    private func toggleSelection(_ conversation: AskConversation) {
        if selectedConversationIDs.contains(conversation.id) {
            selectedConversationIDs.remove(conversation.id)
        } else {
            selectedConversationIDs.insert(conversation.id)
        }
    }

    private func deleteSelectedConversations() {
        for conversation in selectedConversations {
            store.delete(conversation)
        }
        selectedConversationIDs.removeAll()
        if let expandedID, !store.conversations.contains(where: { $0.id == expandedID }) {
            self.expandedID = nil
        }
    }

    private func open(_ conversation: AskConversation) {
        engine.assistantSession.restore(conversation)
        recorderUIManager.presentAssistantSession()
    }
}

private enum AskHistoryPanelMode {
    case analysis
}

private struct AskHistoryCardRow: View {
    let conversation: AskConversation
    let isExpanded: Bool
    let isChecked: Bool
    let onToggleExpand: () -> Void
    let onToggleCheck: () -> Void
    let onContinue: () -> Void

    private var userMessageCount: Int {
        conversation.messages.filter { $0.role == .user }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Toggle("", isOn: Binding(get: { isChecked }, set: { _ in onToggleCheck() }))
                    .toggleStyle(CircularCheckboxStyle())
                    .labelsHidden()

                VStack(alignment: .leading, spacing: 4) {
                    Text(conversation.updatedAt, format: .dateTime.month(.abbreviated).day().hour().minute())
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)

                    if !isExpanded {
                        Text(conversation.title)
                            .font(.system(size: 13))
                            .lineLimit(2)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .animation(.easeInOut(duration: 0.2), value: isExpanded)
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: onToggleExpand)

            if isExpanded {
                expandedContent
                    .padding(.top, 10)
            }
        }
    }

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Label("\(conversation.messages.count) messages", systemImage: "bubble.left.and.bubble.right")
                if let modelName = conversation.modelName, !modelName.isEmpty {
                    Label(modelName, systemImage: "cpu")
                }
                if conversation.isWebSearchEnabled {
                    Label("Web search", systemImage: "globe")
                }
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.secondary)

            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(conversation.messages) { message in
                        VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 3) {
                            Text(message.role == .user ? "You" : "Assistant")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.secondary)
                            Text(message.content)
                                .font(.system(size: 13))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
                        }
                        .padding(10)
                        .background(message.role == .user ? Color.accentColor.opacity(0.16) : Color.secondary.opacity(0.10), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
            }
            .frame(maxHeight: 350)

            HStack {
                Text("\(userMessageCount) questions")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Continue Chat", action: onContinue)
                    .buttonStyle(.bordered)
            }
        }
    }
}

private struct AskHistoryAnalysisPanelView: View {
    let conversations: [AskConversation]
    let onClose: () -> Void

    private var messageCount: Int { conversations.reduce(0) { $0 + $1.messages.count } }
    private var userMessageCount: Int { conversations.reduce(0) { total, conversation in total + conversation.messages.filter { $0.role == .user }.count } }
    private var assistantMessageCount: Int { messageCount - userMessageCount }
    private var wordCount: Int { conversations.flatMap(\.messages).reduce(0) { $0 + $1.content.split(whereSeparator: \.isWhitespace).count } }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Chat Analysis")
                        .font(.headline.weight(.semibold))
                    Text("\(conversations.count) selected chats")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppTheme.Text.secondary)
                }
                Spacer()
                AppIconButton(systemName: "xmark", help: "Close", size: 28, iconSize: 14, cornerRadius: AppTheme.Radius.control, action: onClose)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .overlay(Divider().opacity(0.5), alignment: .bottom)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    analysisSection("Conversation Summary") {
                        analysisRow("Chats", value: "\(conversations.count)")
                        analysisRow("Messages", value: "\(messageCount)")
                        analysisRow("Questions", value: "\(userMessageCount)")
                        analysisRow("Responses", value: "\(assistantMessageCount)")
                        analysisRow("Words", value: "\(wordCount)")
                    }

                    analysisSection("AI Configuration") {
                        analysisRow("Web search enabled", value: "\(conversations.filter(\.isWebSearchEnabled).count) chats")
                        analysisRow("Models", value: "\(Set(conversations.compactMap(\.modelName)).count)")
                        analysisRow("Modes", value: "\(Set(conversations.compactMap(\.modeName)).count)")
                    }
                }
                .padding(18)
            }
        }
    }

    private func analysisSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
            VStack(spacing: 0, content: content)
                .background(AppTheme.Surface.subtle, in: RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
        }
    }

    private func analysisRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title).foregroundStyle(.secondary)
            Spacer()
            Text(value).fontWeight(.medium)
        }
        .font(.system(size: 12))
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}

private final class AskHistoryExportService {
    func export(conversations: [AskConversation]) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "VoiceInk-ask-history.json"
        panel.begin { result in
            guard result == .OK, let url = panel.url else { return }
            do {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                encoder.dateEncodingStrategy = .iso8601
                try encoder.encode(conversations).write(to: url, options: .atomic)
            } catch {
                NSSound.beep()
            }
        }
    }
}
