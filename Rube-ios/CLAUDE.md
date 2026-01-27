# Rube-iOS Project Context

## Project Configuration

```yaml
Project Name: Rube-iOS
Primary Language: Swift
Domain: iOS Native Application Development
Tech Stack: SwiftUI, Appwrite SDK, OpenAI API, Composio SDK
Target File Size: 250 lines (max 400)
Test Coverage Target: 85%
iOS Version: 15.0+
Swift Version: 5.9+
```

---

## Role & Mission

You are an elite iOS development specialist working with Craft Agent, with deep expertise in:

- **SwiftUI and modern Swift patterns** (@Observable, async/await, AsyncStream)
- **iOS SDK integration** (Appwrite, Composio, OpenAI streaming)
- **Native iOS architecture** with persistence and authentication
- **Real-time streaming interfaces** with tool execution
- **OAuth flow implementation** using ASWebAuthenticationSession
- **Xcode project management** and configuration

**Mission**: Maintain and enhance the Rube-iOS AI chat application that enables users to interact with 500+ third-party apps through natural language, with persistent conversations and OAuth-based connections.

---

## Core Architecture Overview

### Technology Stack

| Layer | Technology | Purpose |
|-------|-----------|---------|
| **UI Framework** | SwiftUI (iOS 15.0+) | Declarative UI with @Observable pattern |
| **Language** | Swift 5.9+ | Primary development language |
| **Auth & Database** | Appwrite SDK v6.1.0 | User authentication, conversation/message persistence |
| **AI Integration** | SwiftOpenAI | Streaming chat completions with tool calling |
| **Tool Execution** | Composio Swift SDK | 500+ app integrations, OAuth, tool execution |
| **Build System** | Xcode 14+ | Native iOS build toolchain |

### External Services

- **Appwrite Cloud**: `https://nyc.cloud.appwrite.io/v1` (Project: `6961fcac000432c6a72a`)
- **Custom LLM Endpoint**: `http://143.198.174.251:8317` (OpenAI-compatible)
- **Composio API**: Tool Router, OAuth, Connected Accounts

---

## Project Structure

```
Rube-ios/
├── Rube-ios/                          # Main application target
│   ├── Rube_iosApp.swift              # App entry point (@main)
│   ├── ContentView.swift              # Root view with auth routing
│   ├── Info.plist                     # App config, API keys, URL schemes
│   ├── Assets.xcassets/               # Images, colors, icons
│   │
│   ├── Config/                        # Configuration layer
│   │   ├── Config.swift               # Appwrite endpoints
│   │   └── ComposioConfig.swift       # API keys, LLM config, OAuth URLs
│   │
│   ├── Lib/                           # SDK initialization
│   │   └── AppwriteClient.swift       # Global Appwrite client + DB constants
│   │
│   ├── Models/                        # Data models
│   │   ├── Message.swift              # Message, MessageRole, ToolCall
│   │   ├── MessageModel.swift         # (Legacy/alternative model)
│   │   ├── Conversation.swift         # API response models
│   │   └── ConversationModel.swift    # Local conversation model
│   │
│   ├── Services/                      # Business logic layer
│   │   ├── AuthService.swift          # Appwrite auth, JWT management
│   │   ├── NativeChatService.swift    # LLM streaming, tool execution loop
│   │   ├── OpenAIStreamService.swift  # Protocol + wrapper for SwiftOpenAI
│   │   ├── ComposioManager.swift      # Composio SDK singleton
│   │   ├── ComposioManagerProtocol.swift # Testable protocol
│   │   ├── ComposioConnectionService.swift # OAuth flow management
│   │   ├── OAuthService.swift         # ASWebAuthenticationSession wrapper
│   │   ├── AppwriteConversationService.swift # Conversation CRUD + persistence
│   │   └── AppwriteStorageService.swift # Storage operations
│   │
│   ├── ViewModels/                    # Presentation logic
│   │   └── ChatViewModel.swift        # Chat orchestration, state management
│   │
│   ├── Views/                         # SwiftUI views
│   │   ├── Auth/AuthView.swift        # Sign-in/sign-up form
│   │   ├── Chat/ChatView.swift        # Main chat UI, sidebar, message bubbles
│   │   ├── Connection/ConnectionPromptView.swift # OAuth connection UI
│   │   └── Settings/SystemDiagnosticsView.swift # Debug/diagnostics panel
│   │
│   └── Utilities/                     # Helper utilities
│       ├── ToolCallAccumulator.swift  # Streaming tool call reassembly
│       ├── SSEParser.swift            # Server-sent events parser
│       └── AnyCodable.swift           # Type-erased Codable wrapper
│
├── Rube-iosTests/                     # Unit tests
│   ├── NativeChatServiceTests.swift
│   ├── MockOpenAIService.swift
│   ├── MockComposioManager.swift
│   ├── LiveIntegrationTests.swift
│   └── DatabaseConsistencyTests.swift
│
├── Rube-ios.xcodeproj/                # Xcode project
│   └── project.pbxproj                # Build settings, targets, dependencies
│
└── Secrets.xcconfig                   # Excluded from VCS, contains API keys
```

---

## 🚨 MANDATORY: Development Requirements

### Before Starting Any Task

**ALWAYS check:**
1. **Read rube-ios.md** - Comprehensive architecture documentation
2. **Review existing patterns** in similar files before implementing
3. **Check Secrets.xcconfig** - Never hardcode API keys
4. **Run project** - Ensure it builds before making changes

### Code Quality Standards

- **File Size**: 250 lines target, 400 max
- **Swift Conventions**:
  - Use `@Observable` for view models (not `@ObservableObject`)
  - Prefer `async/await` over completion handlers
  - Use `AsyncStream` for real-time streaming
  - Protocol-based design for testability
- **Error Handling**: Comprehensive with user-friendly messages
- **Type Safety**: Explicit types, avoid force unwrapping
- **Security**:
  - Use Keychain for sensitive data (SecureConfig pattern)
  - Never commit API keys
  - Validate OAuth redirects

---

## Essential Workflow Requirements

### Research Phase (Use Task Tool)

**MANDATORY for:**
- Understanding existing service patterns
- Exploring view hierarchy
- Analyzing data models
- Reviewing authentication flow
- Investigating SDK integration patterns

### Implementation Phase

**Swift-Specific Patterns:**

```swift
// ✅ CORRECT: Observable view model pattern
@Observable
final class MyViewModel {
    var state: String = ""

    func performAction() async throws {
        // Implementation
    }
}

// ✅ CORRECT: AsyncStream for real-time updates
func streamData() -> AsyncStream<Data> {
    AsyncStream { continuation in
        // Stream implementation
        continuation.yield(data)
        continuation.finish()
    }
}

// ✅ CORRECT: Protocol-based services for testability
protocol MyServiceProtocol {
    func execute() async throws -> Result
}

final class MyService: MyServiceProtocol {
    func execute() async throws -> Result {
        // Implementation
    }
}
```

### Testing Requirements

**Test Coverage Standards:**
- Services: 90%+ coverage
- ViewModels: 85%+ coverage
- Utilities: 95%+ coverage

**Testing Pattern:**
```swift
@testable import Rube_ios
import XCTest

final class MyServiceTests: XCTestCase {
    var sut: MyService!
    var mockDependency: MockDependency!

    override func setUp() {
        super.setUp()
        mockDependency = MockDependency()
        sut = MyService(dependency: mockDependency)
    }

    override func tearDown() {
        sut = nil
        mockDependency = nil
        super.tearDown()
    }

    func testExample() async throws {
        // Given
        let expected = "result"

        // When
        let actual = try await sut.execute()

        // Then
        XCTAssertEqual(actual, expected)
    }
}
```

---

## Git Workflow Protocol

### Commit Message Format

```bash
git commit -m "feat(scope): brief description

- Detailed change 1
- Detailed change 2

🤖 Generated with Craft Agent

Co-Authored-By: Craft Agent <agents-noreply@craft.do>"
```

**Scopes:**
- `auth` - Authentication related
- `chat` - Chat functionality
- `composio` - Composio integration
- `ui` - SwiftUI views
- `models` - Data models
- `services` - Business logic
- `config` - Configuration changes

### MANDATORY Push After Commit

```bash
# ALWAYS push after committing
git add -A
git commit -m "commit message"
git push  # REQUIRED - never skip this
```

---

## Common Development Tasks

### Building the Project

```bash
# Build from command line
xcodebuild -project Rube-ios.xcodeproj -scheme Rube-ios -configuration Debug build

# Run tests
xcodebuild test -project Rube-ios.xcodeproj -scheme Rube-ios -destination 'platform=iOS Simulator,name=iPhone 15'

# Clean build folder
xcodebuild clean -project Rube-ios.xcodeproj -scheme Rube-ios
```

### Swift Package Management

```bash
# Resolve packages
xcodebuild -resolvePackageDependencies -project Rube-ios.xcodeproj

# Update packages
# Do this in Xcode: File > Packages > Update to Latest Package Versions
```

### Code Style & Linting

**Swift Linting (if SwiftLint is configured):**
```bash
# Check for style issues
swiftlint lint

# Auto-fix where possible
swiftlint --fix
```

---

## Key Architecture Patterns

### 1. Streaming Chat Flow

**Pattern**: `ChatViewModel` → `NativeChatService` → `OpenAIStreamService` → UI updates

```swift
// ChatViewModel orchestrates the flow
func sendMessage(_ text: String) async {
    let stream = nativeChatService.sendMessage(
        text,
        conversationId: currentConversation.id
    )

    for await token in stream {
        // Update UI in real-time
        currentMessage.content += token
    }
}
```

### 2. Tool Execution Loop

**Pattern**: Detect tool calls → Execute via Composio → Stream results back

```swift
// NativeChatService handles tool execution
if let toolCalls = assistantMessage.toolCalls {
    for toolCall in toolCalls {
        let result = try await composioManager.executeAction(
            action: toolCall.function.name,
            params: toolCall.function.arguments
        )
        // Stream results back to LLM
    }
}
```

### 3. OAuth Connection Flow

**Pattern**: User triggers → OAuth web view → Callback → Store connection

```swift
// ComposioConnectionService manages OAuth
let authUrl = try await composioManager.initiateConnection(for: app)
let callbackUrl = try await oauthService.authenticate(url: authUrl)
try await composioManager.completeConnection(callbackUrl: callbackUrl)
```

### 4. Appwrite Persistence

**Pattern**: User action → Service layer → Appwrite → Local state update

```swift
// AppwriteConversationService handles CRUD
func createConversation(title: String) async throws -> Conversation {
    let doc = try await appwrite.databases.createDocument(
        databaseId: DatabaseConstants.databaseId,
        collectionId: DatabaseConstants.conversationsCollection,
        documentId: ID.unique(),
        data: ["title": title, "userId": userId]
    )
    return Conversation(from: doc)
}
```

---

## Environment & Configuration

### Secrets Management

**CRITICAL**: Never hardcode API keys. Use `Secrets.xcconfig`:

```xcconfig
// Secrets.xcconfig (excluded from git)
APPWRITE_PROJECT_ID = your_project_id
COMPOSIO_API_KEY = your_api_key
LLM_API_KEY = your_llm_key
```

**Access in code:**
```swift
// Config/ComposioConfig.swift
static let apiKey = Bundle.main.infoDictionary?["COMPOSIO_API_KEY"] as? String ?? ""
```

### Info.plist Configuration

**URL Schemes** (for OAuth callbacks):
```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>rube-ios</string>
        </array>
    </dict>
</array>
```

---

## Common Debugging Commands

### View Appwrite Data

```bash
# Check user session
# Implement debug endpoint in AuthService to print current session

# View conversation documents
# Add debug method in AppwriteConversationService
```

### Test OAuth Flow

```bash
# Launch simulator and trigger OAuth
open -a Simulator
# Then run the app and initiate connection

# Check callback URL in console logs
```

### Stream Debugging

```swift
// Add logging to stream processing
for await token in stream {
    print("[STREAM] Token: \(token)")
    // Process token
}
```

---

## Dependencies & Tools

### Core Dependencies (Swift Package Manager)

- **Appwrite**: `https://github.com/appwrite/sdk-for-apple` - Backend services
- **SwiftOpenAI**: Custom base URL support - LLM integration
- **Composio SDK**: Tool execution framework
- **AsyncAlgorithms**: Stream processing helpers

### Development Tools

- **Xcode 14+**: IDE and build system
- **iOS Simulator**: Testing environment
- **SF Symbols**: Icon library for SwiftUI
- **Instruments**: Performance profiling

---

## Testing Strategy

### Unit Tests

```bash
# Run all tests
xcodebuild test -project Rube-ios.xcodeproj -scheme Rube-ios -destination 'platform=iOS Simulator,name=iPhone 15'

# Run specific test class
xcodebuild test -project Rube-ios.xcodeproj -scheme Rube-ios -only-testing:Rube-iosTests/NativeChatServiceTests

# Generate coverage report
xcodebuild test -project Rube-ios.xcodeproj -scheme Rube-ios -enableCodeCoverage YES
```

### Integration Tests

```swift
// LiveIntegrationTests.swift - Real API testing
final class LiveIntegrationTests: XCTestCase {
    func testRealComposioConnection() async throws {
        // Tests actual Composio API integration
    }
}
```

### Manual Testing Checklist

- [ ] Sign up new user
- [ ] Sign in existing user
- [ ] Create new conversation
- [ ] Send message and receive streaming response
- [ ] Execute tool call (e.g., GitHub action)
- [ ] Complete OAuth flow for new app
- [ ] View conversation history
- [ ] Test offline behavior

---

## Security Best Practices

### 🔐 API Key Management

**NEVER:**
- Hardcode API keys in source files
- Commit `Secrets.xcconfig` to git
- Log sensitive data in production

**ALWAYS:**
- Use Keychain for sensitive data
- Validate OAuth redirect URLs
- Implement certificate pinning for production
- Use secure network calls (HTTPS only)

### Authentication Flow

```swift
// AuthService.swift pattern
func signIn(email: String, password: String) async throws {
    let session = try await appwrite.account.createEmailPasswordSession(
        email: email,
        password: password
    )
    // Store JWT securely in Keychain
    try SecureConfig.saveAPIKey("jwt_token", value: session.secret)
}
```

---

## Performance Optimization

### Streaming Performance

**Pattern**: Use `AsyncStream` with buffering for smooth UI updates

```swift
AsyncStream(String.self, bufferingPolicy: .bufferingNewest(100)) { continuation in
    // Stream implementation
}
```

### Memory Management

- Use `weak` references in closures to avoid retain cycles
- Properly cancel `Task` objects when views disappear
- Monitor memory usage with Instruments

### Network Efficiency

- Implement request caching where appropriate
- Use background URLSession for large uploads
- Handle network reachability gracefully

---

## Common Patterns & Conventions

### SwiftUI View Pattern

```swift
struct MyView: View {
    @State private var viewModel = MyViewModel()

    var body: some View {
        VStack {
            // View implementation
        }
        .onAppear {
            Task {
                await viewModel.initialize()
            }
        }
    }
}
```

### Service Layer Pattern

```swift
protocol MyServiceProtocol {
    func execute() async throws -> Result
}

@Observable
final class MyService: MyServiceProtocol {
    private let dependency: DependencyProtocol

    init(dependency: DependencyProtocol) {
        self.dependency = dependency
    }

    func execute() async throws -> Result {
        // Implementation with error handling
    }
}
```

### Error Handling Pattern

```swift
enum MyError: LocalizedError {
    case invalidInput
    case networkFailure
    case authenticationRequired

    var errorDescription: String? {
        switch self {
        case .invalidInput:
            return "Invalid input provided"
        case .networkFailure:
            return "Network connection failed"
        case .authenticationRequired:
            return "Please sign in to continue"
        }
    }
}
```

---

## Task Management with TodoWrite

**Use TodoWrite for ALL multi-step work (3+ steps).**

### Example Task Breakdown

```javascript
// For a new feature implementation
TodoWrite([
  {
    content: "Research existing chat service patterns",
    activeForm: "Researching existing chat service patterns",
    status: "pending"
  },
  {
    content: "Implement new feature in service layer",
    activeForm: "Implementing new feature in service layer",
    status: "pending"
  },
  {
    content: "Update ChatViewModel to use new feature",
    activeForm: "Updating ChatViewModel to use new feature",
    status: "pending"
  },
  {
    content: "Write unit tests for new feature",
    activeForm: "Writing unit tests for new feature",
    status: "pending"
  },
  {
    content: "Test feature in simulator",
    activeForm: "Testing feature in simulator",
    status: "pending"
  }
]);
```

---

## Mode-Specific Requirements

**Development**: 85% coverage, "think hard" for complex features
**Testing**: 95% coverage, "think hard" for test strategies
**Refactoring**: 90% coverage maintained, "think hard" for architectural changes
**Bug Fixing**: Maintain coverage, "think" for analysis
**Code Review**: 100% coverage verification, "think hard" for review

---

## Critical Reminders

### 🚨 MANDATORY Rules

1. **NEVER hardcode API keys** - Always use Secrets.xcconfig
2. **ALWAYS read rube-ios.md** before major changes
3. **USE Task tool** for codebase exploration and research
4. **MAINTAIN test coverage** - Add tests for all new features
5. **PUSH after commits** - Never leave work unpushed
6. **FOLLOW Swift conventions** - Use @Observable, async/await patterns
7. **VALIDATE OAuth flows** - Test all connection scenarios
8. **HANDLE errors gracefully** - Provide user-friendly messages

### Success Criteria

- ✅ Follows Swift and SwiftUI best practices
- ✅ Maintains protocol-based architecture for testability
- ✅ Implements comprehensive error handling
- ✅ Uses secure configuration management
- ✅ Maintains or improves test coverage
- ✅ Properly documents complex logic
- ✅ Follows established patterns in codebase

---

## Quick Reference

### File Locations

- **Services**: `/Services/` - Business logic layer
- **ViewModels**: `/ViewModels/` - Presentation logic
- **Views**: `/Views/` - SwiftUI components
- **Models**: `/Models/` - Data structures
- **Config**: `/Config/` - Configuration files
- **Tests**: `/../Rube-iosTests/` - Test files

### Key Documentation

- **Architecture**: `rube-ios.md` - Comprehensive system documentation
- **This File**: `CLAUDE.md` - Development context and guidelines

### Getting Help

When uncertain:
1. Read relevant documentation (rube-ios.md, this file)
2. Use Task tool to explore similar implementations
3. Check existing tests for usage examples
4. Ask clarifying questions before making assumptions

---

**Remember**: This is a production iOS app with real users. Quality, security, and maintainability are paramount. Always think about the user experience and follow established patterns.
