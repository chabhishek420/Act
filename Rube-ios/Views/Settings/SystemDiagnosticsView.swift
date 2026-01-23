import SwiftUI
import SwiftOpenAI

struct SystemDiagnosticsView: View {
    @State private var status: String = "Idle"
    @State private var isLoading = false
    @State private var availableModels: [String] = [ComposioConfig.llmModel]
    @State private var selectedModel: String = ComposioConfig.llmModel
    @State private var isFetchingModels = false
    
    // Composio Diagnostics
    @State private var composioStatus: String = "Unknown"
    @State private var userEmail: String = "Not Logged In"
    @State private var fetchedToolsCount: Int = 0
    @State private var connectedToolkits: [String] = []
    
    private let chatService = NativeChatService()
    private let composioManager = ComposioManager.shared
    
    var body: some View {
        Form {
            Section("Pipeline Connectivity") {
                HStack {
                    Text("LLM Endpoint")
                    Spacer()
                    Text(ComposioConfig.openAIBaseURL)
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                Picker("Active Model", selection: $selectedModel) {
                    ForEach(availableModels, id: \.self) { model in
                        Text(model).tag(model)
                    }
                }
                .onChange(of: selectedModel) { _, newValue in
                    ComposioConfig.llmModel = newValue
                }

                Button(action: fetchModels) {
                    if isFetchingModels {
                        HStack {
                            Text("Fetching Models...")
                            ProgressView().tint(.blue)
                        }
                    } else {
                        Text("Refresh Available Models")
                    }
                }
                .disabled(isFetchingModels)
                
                Button(action: runHealthCheck) {
                    if isLoading {
                        ProgressView().tint(.blue)
                    } else {
                        Text("Run Health Check")
                    }
                }
                .disabled(isLoading)
            }
            
            if !responseText.isEmpty {
                Section("Live Response Output") {
                    Text(responseText)
                        .font(.system(.body, design: .monospaced))
                    
                    LabeledContent("Latency", value: String(format: "%.2fs", apiLatency))
                }
            }
            
            Section("Composio Health") {
                LabeledContent("SDK Status", value: ComposioManager.shared.isInitialized ? "✅ Ready" : "❌ Not Ready")
                LabeledContent("User ID", value: AuthService.shared.userEmail ?? "default_user")
                
                if !connectedToolkits.isEmpty {
                    Text("Toolkits: \(connectedToolkits.joined(separator: ", "))")
                        .font(.caption)
                }
                
                LabeledContent("Fetched Tools", value: "\(fetchedToolsCount)")
                
                Button("Verify Composio") {
                    runComposioCheck()
                }
            }
            
            Section("Status") {
                Text(status)
                    .foregroundColor(statusColor)
            }
        }
        .navigationTitle("Diagnostics")
        .onAppear {
            fetchModels()
            runComposioCheck()
        }
    }
    
    private func runComposioCheck() {
        Task {
            let userId = AuthService.shared.userEmail ?? "default_user"
            self.userEmail = userId
            
            do {
                let accounts = try await composioManager.getConnectedAccounts(userId: userId)
                let toolkits = Array(Set(accounts.map { $0.toolkit })).sorted()
                
                let tools = try await composioManager.getTools(userId: userId, toolkits: toolkits.isEmpty ? ["GITHUB", "GMAIL", "SLACK"] : toolkits)
                
                await MainActor.run {
                    self.connectedToolkits = toolkits
                    self.fetchedToolsCount = tools.count
                    self.composioStatus = "✅ Composio OK"
                }
            } catch {
                await MainActor.run {
                    self.composioStatus = "❌ Composio Failed: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private var statusColor: Color {
        if status.contains("Success") { return .green }
        if status.contains("Failed") { return .red }
        return .primary
    }
    
    @State private var responseText = ""
    @State private var apiLatency: Double = 0

    private func fetchModels() {
        isFetchingModels = true
        Task {
            do {
                let models = try await chatService.fetchModels()
                await MainActor.run {
                    self.availableModels = models
                    if models.contains(ComposioConfig.llmModel) {
                        self.selectedModel = ComposioConfig.llmModel
                    } else if let first = models.first {
                        self.selectedModel = first
                        ComposioConfig.llmModel = first
                    }
                    self.isFetchingModels = false
                }
            } catch {
                await MainActor.run {
                    self.status = "❌ Model Fetch Failed: \(error.localizedDescription)"
                    self.isFetchingModels = false
                }
            }
        }
    }

    private func runHealthCheck() {
        isLoading = true
        status = "Testing..."
        responseText = ""
        let startTime = Date()
        
        Task {
            do {
                let response = try await chatService.sendMessage(
                    "Hello, this is a diagnostic test. Please respond with exactly 'Success'.",
                    messages: [],
                    conversationId: nil,
                    onNewConversationId: { _ in }
                )
                
                await MainActor.run {
                    self.apiLatency = Date().timeIntervalSince(startTime)
                    self.responseText = response.content
                    self.status = response.content.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "success" 
                        ? "✅ Success: LLM is responding correctly."
                        : "⚠️ Partial Success: LLM responded but output was unexpected."
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.status = "❌ Failed: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
}
