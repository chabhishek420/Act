//
//  ChatView.swift
//  Rube-ios
//
//  Main chat interface
//

import SwiftUI
import PhotosUI

struct ChatView: View {
    @State private var viewModel: ChatViewModel?
    @State private var showSidebar = false
    @State private var showDeleteAlert = false
    @State private var conversationToDelete: String?

    var body: some View {
        Group {
            if let viewModel {
                chatContent(viewModel: viewModel)
            } else {
                ProgressView()
                    .onAppear {
                        self.viewModel = ChatViewModel()
                    }
            }
        }
    }
    
    @ViewBuilder
    private func chatContent(viewModel: ChatViewModel) -> some View {
        @Bindable var viewModel = viewModel
        NavigationStack {
            VStack(spacing: 0) {
                // Messages or Welcome
                if viewModel.messages.isEmpty && !viewModel.isLoading {
                    WelcomeView(
                        inputText: $viewModel.inputText,
                        onSend: {
                            Task { await viewModel.sendMessage() }
                        }
                    )
                } else {
                    // Messages list
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(viewModel.messages) { message in
                                    MessageBubble(
                                        message: message,
                                        onRetry: { failedMessage in
                                            Task { await viewModel.retryMessage(failedMessage) }
                                        },
                                        onRegenerate: { assistantMessage in
                                            Task { await viewModel.regenerateMessage(assistantMessage) }
                                        }
                                    )
                                    .id(message.id)
                                }

                                // Streaming message
                                if viewModel.isStreaming {
                                    StreamingMessageView(
                                        content: viewModel.streamingContent,
                                        toolCalls: viewModel.streamingToolCalls
                                    )
                                    .id("streaming")
                                }

                                // Loading indicator
                                if viewModel.isLoading && !viewModel.isStreaming {
                                    HStack {
                                        ProgressView()
                                            .padding()
                                        Spacer()
                                    }
                                    .id("loading")
                                }
                            }
                            .padding()
                        }
                        .onChange(of: viewModel.streamingContent) { _, _ in
                            withAnimation {
                                proxy.scrollTo("streaming", anchor: .bottom)
                            }
                        }
                        .onChange(of: viewModel.messages.count) { _, _ in
                            if let lastId = viewModel.messages.last?.id {
                                withAnimation {
                                    proxy.scrollTo(lastId, anchor: .bottom)
                                }
                            }
                        }
                    }

                    // Pending attachments preview
                    if !viewModel.pendingAttachments.isEmpty {
                        ScrollView(.horizontal) {
                            HStack {
                                ForEach(viewModel.pendingAttachments) { attachment in
                                    AttachmentView(attachment: attachment)
                                        .scaleEffect(0.6)
                                        .frame(width: 100, height: 100)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }

                    // Input bar
                    MessageInputView(
                        text: $viewModel.inputText,
                        isLoading: viewModel.isLoading,
                        onSend: {
                            Task { await viewModel.sendMessage() }
                        },
                        onAttach: { attachment in
                            viewModel.pendingAttachments.append(attachment)
                        }
                    )
                }
            }
            .navigationTitle("Rube")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showSidebar = true
                    } label: {
                        Image(systemName: "sidebar.left")
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    HStack {
                        NavigationLink {
                            SystemDiagnosticsView()
                        } label: {
                            Image(systemName: "gauge.open.with.lines.needle.33percent")
                        }

                        Button {
                            viewModel.startNewChat()
                        } label: {
                            Image(systemName: "square.and.pencil")
                        }
                    }
                }
            }
            .sheet(isPresented: $showSidebar) {
                ConversationSidebar(
                    conversations: viewModel.conversations,
                    currentId: viewModel.currentConversationId,
                    onSelect: { id in
                        Task { await viewModel.loadConversation(id) }
                        showSidebar = false
                    },
                    onDelete: { id in
                        conversationToDelete = id
                        showDeleteAlert = true
                    },
                    onNewChat: {
                        viewModel.startNewChat()
                        showSidebar = false
                    }
                )
            }
            .alert("Delete Conversation?", isPresented: $showDeleteAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    if let id = conversationToDelete {
                        Task { await viewModel.deleteConversation(id) }
                    }
                }
            } message: {
                Text("This action cannot be undone.")
            }

            .overlay {
                // Connection prompt overlay
                if viewModel.showConnectionPrompt, let request = viewModel.pendingConnectionRequest {
                    ZStack {
                        Color.black.opacity(0.4)
                            .ignoresSafeArea()
                            .onTapGesture {
                                viewModel.dismissConnectionRequest()
                            }

                        ConnectionPromptView(
                            request: request,
                            onConnect: { oauthUrl in
                                Task {
                                    // Always use SDK connect flow (backend removed)
                                    if let toolkit = extractToolkitName(from: request) {
                                        await viewModel.connectApp(toolkit: toolkit)
                                    } else {
                                        await viewModel.connectApp(oauthUrl: oauthUrl)
                                    }
                                }
                            },
                            onDismiss: {
                                viewModel.dismissConnectionRequest()
                            }
                        )
                        .transition(.scale.combined(with: .opacity))
                    }
                    .animation(.spring(response: 0.3), value: viewModel.showConnectionPrompt)
                }
            }
            .overlay {
                // User input form overlay (REQUEST_USER_INPUT tool)
                if let request = viewModel.pendingUserInputRequest {
                    ZStack {
                        Color.black.opacity(0.4)
                            .ignoresSafeArea()
                            .onTapGesture {
                                viewModel.dismissUserInputRequest()
                            }

                        UserInputFormView(
                            request: request,
                            onSubmit: { response in
                                Task {
                                    await viewModel.handleUserInputSubmission(response)
                                }
                            },
                            onDismiss: {
                                viewModel.dismissUserInputRequest()
                            }
                        )
                        .transition(.scale.combined(with: .opacity))
                    }
                    .animation(.spring(response: 0.3), value: viewModel.pendingUserInputRequest?.id)
                }
            }
            .task {
                await viewModel.loadConversations()
            }
        }
    }

    private func extractToolkitName(from request: RubeConnectionRequest) -> String? {
        // Assuming the toolkit name is directly the provider name, lowercased.
        // If there's a more complex mapping, it would go here.
        return request.provider.lowercased()
    }
}

// MARK: - Welcome View

struct WelcomeView: View {
    @Binding var inputText: String
    let onSend: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "sparkles")
                .font(.system(size: 48))
                .foregroundStyle(.blue)

            Text("Welcome to Rube")
                .font(.title)
                .fontWeight(.semibold)

            Text("Your AI assistant that can interact with 500+ apps")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()

            MessageInputView(
                text: $inputText,
                isLoading: false,
                onSend: onSend,
                onAttach: nil // No attachments on welcome screen for simplicity
            )
        }
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: Message
    let onRetry: ((Message) -> Void)?
    var onRegenerate: ((Message) -> Void)?

    var body: some View {
        HStack(alignment: .top) {
            if message.role == .user { Spacer(minLength: 60) }

            VStack(alignment: .leading, spacing: 8) {
                if message.role == .user {
                    Text(message.content)
                        .padding(12)
                        .background(message.isFailed ? Color.red.opacity(0.1) : Color(.systemGray6))
                        .foregroundColor(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        // Use LinkableTextView for tappable links
                        LinkableTextView(text: message.content)
                            .fixedSize(horizontal: false, vertical: true)

                        // Action buttons for assistant
                        HStack(spacing: 16) {
                            Button {
                                UIPasteboard.general.string = message.content
                            } label: {
                                Image(systemName: "doc.on.doc")
                                    .font(.system(size: 14))
                            }

                            Button {
                                onRegenerate?(message)
                            } label: {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 14))
                            }
                        }
                        .foregroundStyle(.secondary)
                    }
                }

                // Tool calls
                if let toolCalls = message.toolCalls, !toolCalls.isEmpty {
                    ForEach(toolCalls) { toolCall in
                        ToolCallView(toolCall: toolCall)
                    }
                }

                // Attachments
                if let attachments = message.attachments, !attachments.isEmpty {
                    ForEach(attachments) { attachment in
                        AttachmentView(attachment: attachment)
                    }
                }

                // Failure indicator and retry button
                if message.isFailed {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                            .font(.caption)

                        Text(message.failureReason ?? "Failed to send")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Spacer()

                        Button {
                            onRetry?(message)
                        } label: {
                            Label("Retry", systemImage: "arrow.clockwise")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                        .tint(.blue)
                    }
                    .padding(.top, 4)
                }
            }

            if message.role == .assistant { Spacer(minLength: 60) }
        }
    }
}

// MARK: - Attachment View

struct AttachmentView: View {
    let attachment: Attachment
    @State private var storageService = AppwriteStorageService() // In production, inject this

    // Bolt: Cache formatter to avoid repeated allocation on every view render
    // ByteCountFormatter initialization has non-trivial overhead; reusing is ~5x faster
    private static let byteFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if attachment.isImage, let url = storageService.getPreviewURL(fileId: attachment.fileId) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } placeholder: {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 100)
                }
            } else {
                HStack {
                    Image(systemName: "doc.fill")
                    Text(attachment.name)
                        .font(.caption)
                    Spacer()
                    Text(Self.byteFormatter.string(fromByteCount: Int64(attachment.size)))
                        .font(.caption2)
                }
                .padding(8)
                .background(Color.black.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .frame(maxWidth: 240)
    }
}

// MARK: - Streaming Message View

struct StreamingMessageView: View {
    let content: String
    let toolCalls: [ToolCall]

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                if !content.isEmpty {
                    // Use LinkableTextView for tappable links during streaming
                    LinkableTextView(text: content)
                        .fixedSize(horizontal: false, vertical: true)
                }

                ForEach(toolCalls) { toolCall in
                    ToolCallView(toolCall: toolCall)
                }

                // Typing indicator
                if content.isEmpty && toolCalls.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(0..<3, id: \.self) { i in
                            Circle()
                                .fill(Color.gray)
                                .frame(width: 8, height: 8)
                                .opacity(0.5)
                        }
                    }
                    .padding(12)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }

            Spacer(minLength: 60)
        }
    }
}

// MARK: - Tool Call View

struct ToolCallView: View {
    let toolCall: ToolCall
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button {
                withAnimation {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    // Status icon
                    Group {
                        switch toolCall.status {
                        case .pending:
                            Image(systemName: "clock.fill")
                                .foregroundStyle(.gray)
                        case .running:
                            ProgressView()
                                .scaleEffect(0.8)
                        case .completed:
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        case .error:
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.red)
                        }
                    }
                    .frame(width: 20)

                    Text(toolCall.name)
                        .font(.caption)
                        .fontWeight(.medium)

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    if !toolCall.input.isEmpty {
                        Text("Input:")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(formatJSON(toolCall.input))
                            .font(.caption2)
                            .fontDesign(.monospaced)
                    }

                    if let output = toolCall.output {
                        Text("Output:")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(formatAny(output))
                            .font(.caption2)
                            .fontDesign(.monospaced)
                            .lineLimit(10)
                    }
                }
                .padding(.leading, 24)
            }
        }
        .padding(8)
        .background(Color(.systemGray5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func formatJSON(_ dict: [String: Any]) -> String {
        // Safely convert to JSON-serializable format
        let sanitized = sanitizeForJSON(dict)
        guard let data = try? JSONSerialization.data(withJSONObject: sanitized, options: .prettyPrinted),
              let string = String(data: data, encoding: .utf8) else {
            return "\(dict)"
        }
        return string
    }

    private func formatAny(_ value: Any) -> String {
        // Safely handle any value type, including Composio.AnyCodable
        let sanitized = sanitizeForJSON(value)
        
        if let dict = sanitized as? [String: Any] {
            return formatJSON(dict)
        } else if let array = sanitized as? [Any] {
            guard let data = try? JSONSerialization.data(withJSONObject: array, options: .prettyPrinted),
                  let string = String(data: data, encoding: .utf8) else {
                return "\(array)"
            }
            return string
        }
        return "\(sanitized)"
    }
    
    /// Recursively extracts values from AnyCodable wrappers to make them JSON-serializable
    private func sanitizeForJSON(_ value: Any) -> Any {
        // Handle Composio.AnyCodable by extracting the underlying value
        if let mirror = Mirror(reflecting: value).children.first(where: { $0.label == "value" })?.value {
            return sanitizeForJSON(mirror)
        }
        
        // Recursively sanitize dictionaries
        if let dict = value as? [String: Any] {
            return dict.mapValues { sanitizeForJSON($0) }
        }
        
        // Recursively sanitize arrays
        if let array = value as? [Any] {
            return array.map { sanitizeForJSON($0) }
        }
        
        // Return primitive types as-is
        return value
    }
}

// MARK: - Message Input View

struct MessageInputView: View {
    @Binding var text: String
    let isLoading: Bool
    let onSend: () -> Void
    let onAttach: ((Attachment) -> Void)?
    
    @State private var selectedItem: PhotosPickerItem?
    @State private var isUploading = false
    private let storageService = AppwriteStorageService()

    var body: some View {
        HStack(spacing: 12) {
            PhotosPicker(selection: $selectedItem, matching: .images) {
                if isUploading {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "plus")
                        .font(.title3)
                        .foregroundStyle(.blue)
                }
            }
            .disabled(isLoading || isUploading)
            .onChange(of: selectedItem) { _, newItem in
                if let newItem {
                    Task {
                        await uploadItem(newItem)
                    }
                }
            }

            TextField("Send a message...", text: $text, axis: .vertical)
                .textFieldStyle(.plain)
                .padding(12)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .lineLimit(1...5)
                .onSubmit {
                    if !text.isEmpty && !isLoading {
                        onSend()
                    }
                }

            Button {
                onSend()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title)
                    .foregroundStyle(text.isEmpty || isLoading ? .gray : .blue)
            }
            .disabled(text.isEmpty || isLoading || isUploading)
        }
        .padding()
        .background(.ultraThinMaterial)
    }
    
    private func uploadItem(_ item: PhotosPickerItem) async {
        isUploading = true
        defer { isUploading = false }
        
        do {
            if let data = try await item.loadTransferable(type: Data.self) {
                let attachment = try await storageService.uploadFile(
                    data: data,
                    name: "upload_\(Int(Date().timeIntervalSince1970)).jpg",
                    mimeType: "image/jpeg"
                )
                onAttach?(attachment)
                selectedItem = nil
            }
        } catch {
            print("[MessageInputView] ❌ Upload failed: \(error)")
        }
    }
}

// MARK: - Conversation Sidebar

struct ConversationSidebar: View {
    let conversations: [ConversationModel]
    let currentId: String?
    let onSelect: (String) -> Void
    let onDelete: (String) -> Void
    let onNewChat: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Button {
                    onNewChat()
                } label: {
                    Label("New Chat", systemImage: "plus.circle")
                }

                Section("History") {
                    ForEach(conversations) { conversation in
                        Button {
                            onSelect(conversation.id)
                        } label: {
                            VStack(alignment: .leading) {
                                Text(conversation.title)
                                    .lineLimit(1)
                                Text(conversation.updatedAt, style: .relative)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .foregroundStyle(conversation.id == currentId ? .blue : .primary)
                        .swipeActions {
                            Button(role: .destructive) {
                                onDelete(conversation.id)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Conversations")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    ChatView()
}
