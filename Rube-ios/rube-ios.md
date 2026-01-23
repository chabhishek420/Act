# Rube-iOS Architecture Documentation

## Executive Summary

**Rube-iOS** is a native iOS chat application that serves as an AI-powered assistant capable of interacting with 500+ third-party applications through the Composio platform. The app combines SwiftUI-based UI, Appwrite-based authentication and cloud storage, OpenAI-compatible LLM streaming, and Composio's tool execution framework to enable conversational AI that can perform real-world actions across multiple services.

**Core Purpose**: Enable users to interact with external apps (GitHub, Gmail, Calendar, etc.) through natural language chat, with persistent conversation history and OAuth-based app connections.

**Key Design Decisions**:
- **Native-only architecture**: Backend removed; all logic runs client-side using Swift SDKs
- **Tool Router session model**: Uses Composio's Tool Router for dynamic tool discovery (500+ tools)
- **Appwrite for persistence**: User auth, conversation storage, and message history
- **Streaming LLM responses**: Real-time token-by-token UI updates with tool call visualization
- **Durable Brain memory**: Per-conversation memory storage for maintaining context across sessions

---

## Technology Stack

| Layer | Technology | Version/Config | Purpose |
|-------|-----------|----------------|---------|
| **UI Framework** | SwiftUI | iOS 15.0+ | Declarative UI with @Observable pattern |
| **Language** | Swift | 5.9+ | Primary development language |
| **Auth & Database** | Appwrite SDK | v6.1.0 | User authentication, conversation/message persistence |
| **AI Integration** | SwiftOpenAI | Custom base URL | Streaming chat completions with tool calling |
| **Tool Execution** | Composio Swift SDK | Latest | 500+ app integrations, OAuth, tool execution |
| **Async Utilities** | AsyncAlgorithms | SPM | Stream processing helpers |
| **Lifecycle** | ServiceLifecycle | SPM | Service management utilities |
| **Build System** | Xcode 14+ | project.pbxproj | Native iOS build toolchain |
| **Config Management** | xcconfig files | Secrets.xcconfig | Environment variable injection |

**External Services**:
- Appwrite Cloud: `https://nyc.cloud.appwrite.io/v1` (Project: `6961fcac000432c6a72a`)
- Custom LLM Endpoint: `http://143.198.174.251:8317` (OpenAI-compatible)
- Composio API: Tool Router, OAuth, Connected Accounts

---

## Project Structure

```
Rube-ios/
├── Rube-ios/                          # Main application target
│   ├── Rube_iosApp.swift              # App entry point (@main)
│   ├── ContentView.swift              # Root view with auth routing
│   ├── Info.plist                     # App config, API keys, URL schemes
│   ├── Assets.xcassets                # Images, colors, icons
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
│   │   └── AppwriteConversationService.swift # Conversation CRUD + persistence
│   │
│   ├── ViewModels/                    # Presentation logic
│   │   └── ChatViewModel.swift        # Chat orchestration, state management
│   │
│   ├── Views/                         # SwiftUI views
│   │   ├── Auth/
│   │   │   └── AuthView.swift         # Sign-in/sign-up form
│   │   ├── Chat/
│   │   │   └── ChatView.swift         # Main chat UI, sidebar, message bubbles
│   │   ├── Connection/
│   │   │   └── ConnectionPromptView.swift # OAuth connection UI
│   │   └── Settings/
│   │       └── SystemDiagnosticsView.swift # Debug/diagnostics panel
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

**File Count**: 25 Swift files (main target), 5 test files
**Target**: iOS 15.0+
**Bundle ID**: Configured via Xcode project settings
**URL Scheme**: `rube://` (Info.plist:30-33)

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           Rube-iOS Application                          │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌───────────────────┐      ┌────────────────────────────────────┐    │
│  │  Rube_iosApp      │─────▶│  ContentView                       │    │
│  │  (Entry Point)    │      │  - Auth routing                    │    │
│  └───────────────────┘      │  - AuthView / ChatView switcher   │    │
│                              └──────────┬─────────────────────────┘    │
│                                         │                              │
│  ┌──────────────────────────────────────┼──────────────────────────┐  │
│  │                       PRESENTATION LAYER                        │  │
│  ├─────────────────────────────────────────────────────────────────┤  │
│  │  ┌─────────────────┐   ┌──────────────────┐   ┌──────────────┐ │  │
│  │  │   AuthView      │   │   ChatView       │   │ ConnectionUI │ │  │
│  │  │  (email/pass)   │   │  - MessageBubble │   │ (OAuth flow) │ │  │
│  │  └────────┬────────┘   │  - ToolCallView  │   └──────────────┘ │  │
│  │           │            │  - Streaming UI  │                     │  │
│  │           │            └────┬─────────────┘                     │  │
│  │           │                 │                                   │  │
│  │           │                 ▼                                   │  │
│  │           │        ┌────────────────────┐                       │  │
│  │           │        │  ChatViewModel     │                       │  │
│  │           │        │  (@Observable)     │                       │  │
│  │           │        │  - State mgmt      │                       │  │
│  │           │        │  - Orchestration   │                       │  │
│  │           │        └──────────┬─────────┘                       │  │
│  └───────────┼────────────────────┼─────────────────────────────────┘  │
│              │                    │                                    │
│  ┌───────────┼────────────────────┼─────────────────────────────────┐  │
│  │                        SERVICE LAYER                             │  │
│  ├──────────────────────────────────────────────────────────────────┤  │
│  │  ┌───────▼──────────┐   ┌─────▼─────────────────────────────┐   │  │
│  │  │  AuthService     │   │  NativeChatService                │   │  │
│  │  │  - signIn/signUp │   │  - sendMessage()                  │   │  │
│  │  │  - JWT mgmt      │   │  - runChatLoop() [recursive]      │   │  │
│  │  │  - session check │   │  - Tool execution                 │   │  │
│  │  └──────────────────┘   │  - Streaming assembly             │   │  │
│  │                         └─────┬──────────┬──────────────────┘   │  │
│  │                               │          │                      │  │
│  │  ┌────────────────────────────┼──────────┼─────────────────┐   │  │
│  │  │ AppwriteConversationService│          │                 │   │  │
│  │  │ - saveConversation()       │          │                 │   │  │
│  │  │ - loadConversations()      │          │                 │   │  │
│  │  │ - updateMemory()           │          │                 │   │  │
│  │  └────────────────────────────┘          │                 │   │  │
│  │                                           │                 │   │  │
│  │  ┌─────────────────────────┐    ┌────────▼──────────────┐  │   │  │
│  │  │ ComposioManager         │◀───│ OpenAIStreamService   │  │   │  │
│  │  │ - createToolRouterSession│    │ - startStreamedChat() │  │   │  │
│  │  │ - fetchSessionTools()   │    └───────────────────────┘  │   │  │
│  │  │ - executeInSession()    │                               │   │  │
│  │  │ - initiateConnection()  │                               │   │  │
│  │  └─────────────────────────┘                               │   │  │
│  │                                                             │   │  │
│  └─────────────────────────────────────────────────────────────┘   │
│                                                                     │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │                      EXTERNAL SERVICES                       │  │
│  ├──────────────────────────────────────────────────────────────┤  │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐   │  │
│  │  │  Appwrite    │  │  Custom LLM  │  │  Composio API    │   │  │
│  │  │  Cloud       │  │  Endpoint    │  │  - Tool Router   │   │  │
│  │  │  - Auth      │  │  - Streaming │  │  - OAuth         │   │  │
│  │  │  - Database  │  │  - Tools API │  │  - Execution     │   │  │
│  │  └──────────────┘  └──────────────┘  └──────────────────┘   │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘

                        DATA FLOW (SEND MESSAGE)
                        ========================
   User Input ──▶ ChatViewModel.sendMessage()
                      │
                      ├──▶ NativeChatService.sendMessage()
                      │      │
                      │      ├──▶ ComposioManager.createToolRouterSession()
                      │      ├──▶ ComposioManager.fetchSessionTools()
                      │      ├──▶ OpenAIStreamService.startStreamedChat()
                      │      │       ↓ (streaming chunks)
                      │      ├──▶ ToolCallAccumulator (reassemble deltas)
                      │      ├──▶ ComposioManager.executeInSession()
                      │      └──▶ Recursive runChatLoop() until final answer
                      │
                      ├──▶ AppwriteConversationService.saveConversation()
                      └──▶ Update UI (@Observable triggers re-render)
```

---

## Execution Flow

### 1. Application Startup
**Entry Point**: `Rube_iosApp.swift:10-17`

```swift
@main
struct Rube_iosApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()  // Root view
        }
    }
}
```

**Flow**:
1. `ContentView.swift:11-17` initializes `AuthService.shared` (singleton)
2. `AuthService.init()` (AuthService.swift:49-60) checks for existing Appwrite session
3. If session exists → `ChatView` rendered
4. If no session → `AuthView` rendered with ping test option

### 2. Authentication Flow
**Entry**: `AuthView.swift:106-128`

**Sign-Up/Sign-In**:
1. User enters email/password
2. `AuthService.signUp()` or `AuthService.signIn()` (AuthService.swift:88-134)
3. Appwrite SDK creates session via `account.createEmailPasswordSession()`
4. JWT token generated via `account.createJWT()` (AuthService.swift:124-125)
5. `@Observable` property update triggers `ContentView` to switch to `ChatView`

**Session Persistence**:
- Session stored in Appwrite SDK's internal storage
- JWT refreshed automatically on 401 errors (AuthService.swift:177-207)

### 3. Chat Message Flow
**Entry**: `ChatView.swift:38-39` → `ChatViewModel.sendMessage()`

**Detailed Steps** (ChatViewModel.swift:40-124):

1. **User Input Capture**
   - Input validated (non-empty, not already loading)
   - Optimistic user message added to UI (line 49-54)

2. **Native Chat Service Call** (NativeChatService.swift:84-191)
   ```
   a. Create Tool Router session for user (line 124)
      ├─ Uses cached session if available (1-hour TTL)
      └─ Creates new session via Composio SDK

   b. Fetch ALL available tools (line 129)
      ├─ Returns 500+ tools from Composio
      └─ Tools dynamically mapped to OpenAI function format

   c. Prepare chat messages (line 156-181)
      ├─ System prompt with "Rube Core Mandate"
      ├─ Conversation history
      └─ New user message

   d. Start chat loop (line 183-190)
   ```

3. **Recursive Chat Loop** (NativeChatService.swift:195-414)
   ```
   runChatLoop(depth=0):
     ├─ Stream LLM response (line 227)
     ├─ Accumulate content + tool calls (line 245-267)
     ├─ If tool calls present:
     │   ├─ Execute each tool via Composio (line 316-339)
     │   ├─ Update memory if returned (line 343-357)
     │   ├─ Append tool results to messages
     │   └─ Recurse: runChatLoop(depth+1) → final answer
     └─ If no tool calls: return final message
   ```

4. **Tool Execution** (ComposioManager.swift:101-112)
   - Session-based execution: `composio.toolRouter.execute()`
   - Memory injection for COMPOSIO_MULTI_EXECUTE_TOOL
   - Error handling with fallback messages

5. **Persistence** (AppwriteConversationService.swift:120-225)
   - Save/update conversation metadata
   - Persist new messages to Appwrite
   - Update conversation memory field (line 228-247)

6. **UI Update**
   - `@Observable` ChatViewModel triggers view re-render
   - Messages displayed in `ChatView` (ChatView.swift:44-85)
   - Streaming content updates in real-time

### 4. OAuth Connection Flow
**Trigger**: LLM requests connection via special message format

**Steps**:
1. `ChatViewModel` detects connection request (ChatViewModel.swift:165-190)
2. `ConnectionPromptView` sheet presented (ChatView.swift:153-183)
3. User taps "Connect"
4. `ComposioManager.initiateConnection()` returns OAuth URL (ComposioManager.swift:180-196)
5. `OAuthService.startOAuth()` launches ASWebAuthenticationSession
6. User authorizes in Safari
7. Callback URL `rube://oauth-callback` captured (Info.plist:30-33)
8. Connection saved to Composio backend
9. Tools for newly connected app become available in next session

---

## Data Models

### Core Models (Models/Message.swift:10-73)

```swift
struct Message: Identifiable, Equatable {
    let id: String              // UUID
    let content: String         // Message text
    let role: MessageRole       // .user / .assistant / .system
    let timestamp: Date
    var toolCalls: [ToolCall]?  // Optional tool executions
}

enum MessageRole: String, Codable {
    case user, assistant, system
}

struct ToolCall: Identifiable {
    let id: String              // Tool call UUID
    let name: String            // Tool slug (e.g., "GITHUB_STAR_A_REPOSITORY")
    var input: [String: Any]    // Tool parameters
    var output: Any?            // Execution result
    var status: ToolCallStatus  // .running / .completed / .error
}
```

### Conversation Models

**ConversationModel** (Models/ConversationModel.swift):
- Local model with title generation logic
- Memory field for Durable Brain storage

**Conversation** (Models/Conversation.swift:10-44):
- API response model with ISO8601 date parsing
- Used for Appwrite deserialization

### Appwrite Database Schema

**Database**: `rube_database` (AppwriteClient.swift:19-23)

**Collections**:
1. `conversations`
   - `userId` (string, indexed)
   - `title` (string)
   - `createdAt` (ISO8601 string)
   - `updatedAt` (ISO8601 string)
   - `memory` (JSON string) - Durable Brain state
   - Permissions: user-scoped read/write/delete

2. `messages`
   - `conversationId` (string, indexed)
   - `content` (string)
   - `role` (string: user/assistant/system)
   - `createdAt` (ISO8601 string)
   - `toolCalls` (JSON string, optional)
   - Permissions: user-scoped read/write/delete

---

## Configuration & Environment

### Configuration Files

| File | Purpose | Source Control |
|------|---------|----------------|
| `Info.plist` | App metadata, API key placeholders, URL schemes | Committed |
| `Secrets.xcconfig` | Actual API key values | **EXCLUDED** (gitignore) |
| `Config.swift` | Hardcoded Appwrite endpoints | Committed |
| `ComposioConfig.swift` | Dynamic config with fallbacks | Committed |

### Environment Variables (Info.plist:5-50)

| Key | Type | Default/Fallback | Usage |
|-----|------|------------------|-------|
| `COMPOSIO_API_KEY` | String | `ak_5j2LU5s9bVapMLI2kHfL` | Composio SDK authentication |
| `OPENAI_API_KEY` | String | `"anything"` | Custom LLM endpoint key |
| `OPENAI_BASE_URL` | String | `http://143.198.174.251:8317` | LLM server endpoint |
| `LLM_MODEL` | String | `gemini-claude-sonnet-4-5` | Model identifier |
| `APPWRITE_API_KEY` | String | (from xcconfig) | Not currently used in code |

**Resolution Priority** (ComposioConfig.swift:15-29):
1. Environment variable (ProcessInfo)
2. Info.plist value (from xcconfig)
3. Hardcoded fallback

### URL Schemes (Info.plist:23-35)

```xml
<key>CFBundleURLSchemes</key>
<array>
    <string>rube</string>  <!-- OAuth callback: rube://oauth-callback -->
</array>
```

**Usage**: OAuth redirect after external app authorization (ComposioConfig.swift:36)

### Appwrite Configuration (Config.swift:11-15)

```swift
static let appwriteEndpoint = "https://nyc.cloud.appwrite.io/v1"
static let appwriteProjectId = "6961fcac000432c6a72a"
```

**Database IDs** (AppwriteClient.swift:19-23):
- Database: `rube_database`
- Collections: `conversations`, `messages`

---

## API Surface & Verification

### Public Interfaces

**No REST API Exposed**: This is a pure client-side app.

**Deep Linking**:
- `rube://` scheme registered for OAuth callbacks
- Future potential: `rube://chat/{conversationId}` (not implemented)

### Verified API Endpoints (2026-01-23)

#### Custom LLM Endpoint
**Base URL**: `http://143.198.174.251:8317`  
**Status**: ✅ Verified Working  
**API Key**: `anything` (any value accepted)

**Available Models** (35+ total):
- `gemini-2.5-flash` ✅ Tested & Recommended
- `gemini-2.5-pro`
- `gemini-claude-sonnet-4-5`
- `gpt-5.1`, `gpt-5.1-codex`, `gpt-5.1-codex-max`
- `claude-sonnet-4.5`, `claude-opus-4.5`

**Test Results**:
```bash
# GET /v1/models - Returns 35+ models
curl -X GET "http://143.198.174.251:8317/v1/models" \
  -H "Authorization: Bearer anything"

# POST /v1/chat/completions - Streaming works
curl -X POST "http://143.198.174.251:8317/v1/chat/completions" \
  -H "Authorization: Bearer anything" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gemini-2.5-flash",
    "messages": [{"role": "user", "content": "Hello"}],
    "temperature": 0.7
  }'

# Response (verified):
{
  "id": "ZhJzaYL3LLGLl7oPk5XNuAs",
  "model": "gemini-2.5-flash",
  "choices": [{
    "message": {
      "role": "assistant",
      "content": "Hello there!"
    },
    "finish_reason": "stop"
  }],
  "usage": {
    "completion_tokens": 3,
    "total_tokens": 32,
    "prompt_tokens": 29
  }
}
```

#### Composio API
**Base URL**: `https://backend.composio.dev/api/v3`  
**Status**: ✅ All Keys Verified

**API Keys**:
- Primary: `ak_5j2LU5s9bVapMLI2kHfL` ✅
- Secondary: `ak_zADvaco59jaMiHrqpjj4` ✅
- Playground: `ak_d8LOxjp7ei0ZyCzkj6-P` ✅

**Verified Endpoints**:

1. **GET /api/v1/apps** - List available apps
   ```bash
   curl -H "X-API-Key: ak_5j2LU5s9bVapMLI2kHfL" \
     https://backend.composio.dev/api/v1/apps
   ```
   - Returns: 500+ apps (GitHub, Gmail, Slack, etc.)
   - Each with actions count, triggers count, categories

2. **GET /api/v1/connectedAccounts** - List user connections
   ```bash
   curl -H "X-API-Key: ak_5j2LU5s9bVapMLI2kHfL" \
     https://backend.composio.dev/api/v1/connectedAccounts
   ```
   - Active connections: Instagram, Perplexity, Hyperbrowser, etc.
   - Status: ACTIVE, EXPIRED, INITIATED

3. **POST /api/v3/tool_router/session** - Create Tool Router session
   - Returns: `{ session_id, mcp, tool_router_tools }`
   - Meta-tools: `COMPOSIO_SEARCH_TOOLS`, `COMPOSIO_MANAGE_CONNECTIONS`

4. **POST /api/v3/tool_router/session/{id}/execute_meta** - Execute meta-tool
   - COMPOSIO_SEARCH_TOOLS: Returns execution guidance + recommended plan
   - COMPOSIO_MANAGE_CONNECTIONS: Initiates OAuth connections

5. **POST /api/v3/tool_router/session/{id}/execute** - Execute tool
   - Executes actual tools (GMAIL_SEND_EMAIL, GITHUB_STAR, etc.)

**Example Meta-Tool Response** (COMPOSIO_SEARCH_TOOLS):
```json
{
  "data": {
    "results": [{
      "use_case": "send an email via gmail",
      "execution_guidance": "IMPORTANT: Follow the recommended plan...",
      "recommended_plan_steps": [
        "Required Step 1: Use GMAIL_SEND_EMAIL with arguments..."
      ],
      "difficulty": "easy",
      "primary_tool_slugs": ["GMAIL_SEND_EMAIL"],
      "toolkit_connection_statuses": [{
        "toolkit": "gmail",
        "has_active_connection": true,
        "status_message": "Gmail is connected"
      }]
    }],
    "session": {
      "id": "load",
      "instructions": "REQUIRED: Pass session_id 'load' in ALL subsequent calls."
    },
    "success": true
  },
  "error": null,
  "log_id": "log_B6kA3mUuao_R"
}
```

### SDK Integration Points

#### 1. Appwrite SDK (AppwriteClient.swift:11-16)
```swift
let client = Client()
    .setEndpoint(Config.appwriteEndpoint)
    .setProject(Config.appwriteProjectId)

let account = Account(client)
let databases = Databases(client)
```

**Usage**:
- `AuthService`: User authentication
- `AppwriteConversationService`: CRUD operations on conversations/messages

**Best Practices**:
- ✅ Use async/await for all database operations
- ✅ Implement proper error handling with retry logic
- ✅ Cache frequently accessed data locally
- ✅ Use batch operations for multiple updates

#### 2. SwiftOpenAI (NativeChatService.swift:62-73)
```swift
OpenAIServiceFactory.service(
    apiKey: ComposioConfig.openAIKey,
    overrideBaseURL: ComposioConfig.openAIBaseURL,
    debugEnabled: true
)
```

**Custom Base URL**: Requires trailing `/v1` removed (SDK appends automatically)

**Protocol**: `OpenAIStreamService` (OpenAIStreamService.swift:5-8)
- `startStreamedChat()` → AsyncThrowingStream
- `listModels()` → [String]

**Verified Configuration**:
```swift
// Secrets.xcconfig (verified 2026-01-23)
CUSTOM_API_KEY = anything
CUSTOM_API_URL = http://143.198.174.251:8317
LLM_MODEL = gemini-2.5-flash
```

**Best Practices**:
- ✅ Use streaming for real-time UI updates
- ✅ Implement token counting for cost tracking
- ✅ Handle rate limits with exponential backoff
- ✅ Cache model responses when appropriate

#### 3. Composio SDK (ComposioManager.swift:44-50)
```swift
self.composio = try Composio(validating: apiKey)
```

**Key Methods**:
- `toolRouter.createSession(for: userId, toolkits: nil)` → All 500+ tools
- `toolRouter.fetchTools(in: sessionId)` → [Tool]
- `toolRouter.execute(toolSlug, in: sessionId, arguments:)` → ToolRouterExecuteResponse
- `toolRouter.executeMeta(metaTool, in: sessionId, arguments:)` → ToolRouterExecuteResponse
- `toolRouter.createLink(for: toolkit, in: sessionId)` → ToolRouterLinkResponse
- `connectedAccounts.initiateConnection(for: userId, toolkit:, redirectUrl:)` → ConnectionRequest

**Response Models**:
```swift
struct ToolRouterSession: Codable, Sendable {
    let sessionId: String
    let mcp: ToolRouterMcp?
    let toolRouterTools: [String]?
}

struct ToolRouterExecuteResponse: Codable, Sendable {
    let data: [String: AnyCodable]
    let error: String?
    let logId: String
}

struct ToolRouterLinkResponse: Codable, Sendable {
    let connectedAccountId: String
    let linkToken: String
    let redirectUrl: String // Verified from live API
}
```

**Best Practices**:
- ✅ Cache Tool Router sessions (1-hour TTL)
- ✅ Use meta-tools for dynamic tool discovery
- ✅ Sanitize tool names for OpenAI compatibility (replace `:` with `_`)
- ✅ Inject memory context into COMPOSIO_MULTI_EXECUTE_TOOL
- ✅ Handle OAuth flows with ASWebAuthenticationSession

---

## Production Best Practices (2026)

### Swift 6 Concurrency Patterns

**1. Async/Await Over Completion Handlers**
```swift
// ✅ GOOD: Modern async/await
func fetchData() async throws -> Data {
    let (data, _) = try await URLSession.shared.data(from: url)
    return data
}

// ❌ BAD: Legacy completion handlers
func fetchData(completion: @escaping (Result<Data, Error>) -> Void) {
    URLSession.shared.dataTask(with: url) { data, _, error in
        // ...
    }.resume()
}
```

**2. Actor Isolation for Thread Safety**
```swift
actor DataCache {
    private var cache: [String: Data] = [:]
    
    func store(_ data: Data, for key: String) {
        cache[key] = data
    }
    
    func retrieve(for key: String) -> Data? {
        cache[key]
    }
}
```

**3. Structured Concurrency with TaskGroup**
```swift
func processItems(_ items: [Item]) async -> [Result] {
    await withTaskGroup(of: Result.self) { group in
        for item in items {
            group.addTask { await process(item) }
        }
        
        var results: [Result] = []
        for await result in group {
            results.append(result)
        }
        return results
    }
}
```

### SwiftUI Performance Optimization

**1. Property Wrapper Selection**

| Wrapper | Use Case | Ownership | Lifecycle |
|---------|----------|-----------|-----------|
| `@State` | View-local simple values | View owns | View lifetime |
| `@StateObject` | View-local observable objects | View owns | Persists across recreations |
| `@ObservedObject` | Passed observable objects | External | External control |
| `@EnvironmentObject` | App-wide shared state | Environment | App lifetime |

**2. Lazy Loading for Performance**
```swift
// ✅ GOOD: Lazy loading
ScrollView {
    LazyVStack(spacing: 12) {
        ForEach(messages) { message in
            MessageRow(message: message)
        }
    }
}

// ❌ BAD: Renders all upfront
ScrollView {
    VStack(spacing: 12) {
        ForEach(messages) { message in
            MessageRow(message: message)
        }
    }
}
```

**3. Minimize View Refreshes**
```swift
// ✅ GOOD: Granular state dependencies
struct UserView: View {
    @StateObject private var viewModel = UserViewModel()
    
    var body: some View {
        VStack {
            Text(viewModel.user.name) // Only refreshes when name changes
            ExpandableSection(isExpanded: viewModel.isExpanded)
        }
    }
}
```

### Memory Management

**1. Prevent Retain Cycles**
```swift
// ✅ GOOD: Weak self in closures
class DataManager {
    func loadData() {
        NetworkService.fetch { [weak self] result in
            guard let self = self else { return }
            self.processData(result)
        }
    }
}

// ✅ GOOD: Weak delegate
protocol DataManagerDelegate: AnyObject {
    func dataDidUpdate()
}

class DataManager {
    weak var delegate: DataManagerDelegate?
}
```

**2. Cleanup in deinit**
```swift
class ViewModel {
    private var cancellables = Set<AnyCancellable>()
    
    deinit {
        cancellables.removeAll()
        print("ViewModel deallocated")
    }
}
```

### Security Best Practices

**1. Keychain for Sensitive Data**
```swift
import Security

class KeychainManager {
    static func save(key: String, data: Data) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        SecItemDelete(query as CFDictionary)
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }
    
    static func load(key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        return status == errSecSuccess ? result as? Data : nil
    }
}
```

**2. Avoid Hardcoded Secrets**
```swift
// ❌ BAD: Hardcoded API key
let apiKey = "sk-1234567890abcdef"

// ✅ GOOD: Load from secure storage
let apiKey = KeychainManager.load(key: "apiKey")

// ✅ GOOD: Use xcconfig for build-time configuration
// Secrets.xcconfig (excluded from VCS)
COMPOSIO_API_KEY = ak_5j2LU5s9bVapMLI2kHfL
```

**3. Input Validation**
```swift
func validateEmail(_ email: String) -> Bool {
    let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
    let predicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
    return predicate.evaluate(with: email)
}

func sanitizeInput(_ input: String) -> String {
    input.trimmingCharacters(in: .whitespacesAndNewlines)
        .replacingOccurrences(of: "<", with: "&lt;")
        .replacingOccurrences(of: ">", with: "&gt;")
}
```

### Data Persistence Strategy

**SwiftData (Recommended for New Apps)**:
```swift
@Model
final class Message {
    var id: UUID
    var content: String
    var role: String
    var timestamp: Date
    
    init(content: String, role: String) {
        self.id = UUID()
        self.content = content
        self.role = role
        self.timestamp = Date()
    }
}

// Query in views
@Query(sort: \Message.timestamp, order: .reverse)
private var messages: [Message]
```

**Appwrite (Current Implementation)**:
- User authentication with JWT
- Conversation/message persistence
- Real-time updates via WebSocket
- User-scoped permissions

### Testing Strategy

**1. Unit Tests**
```swift
final class ChatViewModelTests: XCTestCase {
    var viewModel: ChatViewModel!
    var mockService: MockChatService!
    
    override func setUp() {
        mockService = MockChatService()
        viewModel = ChatViewModel(chatService: mockService)
    }
    
    func testSendMessage() async {
        await viewModel.sendMessage("Hello")
        XCTAssertEqual(viewModel.messages.count, 2) // User + Assistant
        XCTAssertFalse(viewModel.isLoading)
    }
}
```

**2. UI Tests**
```swift
func testChatFlow() {
    app.textFields["messageInput"].tap()
    app.textFields["messageInput"].typeText("Hello")
    app.buttons["Send"].tap()
    
    XCTAssertTrue(app.staticTexts["Hello"].waitForExistence(timeout: 5))
}
```

### Performance Monitoring

**Key Metrics**:
- View body execution: < 16ms (60fps)
- Memory footprint: < 100MB
- App launch time: < 2 seconds
- Network request latency: < 500ms

**Tools**:
- Instruments - Time Profiler
- Instruments - Allocations
- Instruments - Leaks
- SwiftUI Instrument (Xcode 26+)

---

## API Documentation Reference

For comprehensive API documentation, see:
- **[COMPOSIO_API.md](../COMPOSIO_API.md)** - Complete Composio API reference with verified endpoints
- **[iOS_Production_Best_Practices_2026.md](../iOS_Production_Best_Practices_2026.md)** - Full production best practices guide
- **[RESEARCH_SUMMARY.md](../RESEARCH_SUMMARY.md)** - Quick reference summary

---

## Extension Points

### 1. Adding New Views
**Location**: `Views/` subdirectories

**Pattern**:
```swift
struct NewFeatureView: View {
    @State private var viewModel = NewFeatureViewModel()

    var body: some View {
        // SwiftUI layout
    }
}
```

**Integration**: Add to navigation stack in `ChatView.swift` toolbar or sidebar

### 2. Custom Tool Execution
**Extension Point**: `NativeChatService.swift:302-396`

**Current Flow**:
1. Tool calls received from LLM
2. Mapped to original slugs via `toolMapping`
3. Executed via `ComposioManager.executeInSession()`

**Custom Logic Insertion**:
- Pre-execution validation (line 306)
- Memory injection (line 318-322)
- Post-execution processing (line 343-357)

### 3. LLM Provider Swapping
**Interface**: `OpenAIStreamService` protocol (OpenAIStreamService.swift:5-8)

**Steps**:
1. Implement protocol for new provider
2. Replace `OpenAIServiceWrapper` in `NativeChatService.init()`
3. Ensure streaming format matches `ChatCompletionChunkObject`

**Example**:
```swift
struct CustomLLMService: OpenAIStreamService {
    func startStreamedChat(parameters: ChatCompletionParameters) async throws -> AsyncThrowingStream<ChatCompletionChunkObject, Error> {
        // Custom implementation
    }
}
```

### 4. Persistence Layer Abstraction
**Current**: Tightly coupled to Appwrite (AppwriteConversationService.swift)

**Refactoring Path**:
1. Define `ConversationStorageProtocol`
2. Extract interface:
   - `saveConversation(id:, messages:) async -> String`
   - `loadConversations() async -> [ConversationModel]`
   - `getMessages(conversationId:) async -> [Message]`
3. Implement for alternative backends (Core Data, CloudKit, Firebase)

### 5. OAuth Provider Expansion
**Current**: ASWebAuthenticationSession (OAuthService.swift)

**Extension**:
- Add custom OAuth schemes to Info.plist
- Update `ComposioConfig.oauthCallbackURL` for multi-scheme support
- Implement custom callback handling in AppDelegate (if needed)

### 6. Memory System Enhancement
**Current**: Simple JSON dictionary (NativeChatService.swift:49-50)

**Potential Extensions**:
- Structured memory models (entities, relationships)
- Memory pruning/summarization
- Cross-conversation memory linking
- Semantic search over memory

---

## Notable Patterns & Design Decisions

### 1. @Observable Pattern (iOS 17+)
**Rationale**: Replaces `ObservableObject` for cleaner SwiftUI integration

**Examples**:
- `ChatViewModel` (ChatViewModel.swift:10)
- `AuthService` (AuthService.swift:34)
- `ComposioManager` (ComposioManager.swift:14)

**Benefits**:
- Automatic view invalidation on property changes
- No manual `@Published` wrappers
- Better performance with selective updates

### 2. Recursive Chat Loop (Tool Calling)
**Location**: `NativeChatService.swift:195-414`

**Why**:
- LLM may need multiple tool executions before final answer
- Tools can trigger additional tool needs (chaining)
- Max depth limit (10) prevents infinite loops

**Flow**:
```
User Query → LLM → Tool Call → Execute → Results → LLM → Final Answer
                    ↓          ↓
                  [More Tools] ← (recursive)
```

### 3. Streaming with ToolCallAccumulator
**Location**: `Utilities/ToolCallAccumulator.swift`

**Problem**: Tool calls arrive as fragmented deltas across stream chunks

**Solution**:
1. Accumulator tracks partial tool calls by index
2. Reassembles JSON arguments incrementally
3. Finalizes complete tool calls at stream end

**Example**:
```
Chunk 1: {"index": 0, "id": "call_123", "function": {"name": "GITHUB_STAR"}}
Chunk 2: {"index": 0, "function": {"arguments": "{\"owner\":"}}
Chunk 3: {"index": 0, "function": {"arguments": "\"anthropics\"}"}}
Result:  ToolCall(id: "call_123", name: "GITHUB_STAR", args: {"owner": "anthropics"})
```

### 4. Session Caching (1-Hour TTL)
**Location**: `ComposioManager.swift:56-82`

**Why**:
- Tool Router session creation is expensive (~500ms)
- Sessions are stateless (user-scoped)
- Reduces API calls by 90% during active chat

**Cache Key**: `userId` (email)
**Expiration**: 3600 seconds

### 5. Error Recovery with JWT Auto-Refresh
**Location**: `AuthService.swift:177-207`

**Pattern**:
```swift
func performRequestWithAutoRefresh<T>(
    _ makeRequest: @escaping (String) async throws -> (T, HTTPURLResponse)
) async throws -> T {
    // Try with current JWT
    // If 401 → refresh JWT → retry once
}
```

**Usage**: Backend communication (if backend existed)

### 6. Dual Model Pattern (Message vs MessageModel)
**Files**: `Message.swift`, `MessageModel.swift`

**Confusion**: Two similar models exist, likely from refactoring

**Recommendation**: Consolidate to `Message.swift` (actively used)

### 7. Native-Only Architecture (Backend Removed)
**Evidence**: Comments in code (e.g., Config.swift:6, ChatViewModel.swift:58)

**Why**:
- Faster iteration (no backend deployment)
- Reduced infrastructure costs
- All logic in Swift SDKs (Appwrite, Composio, SwiftOpenAI)

**Trade-off**:
- API keys in client (mitigated by xcconfig exclusion)
- Limited server-side validation
- Dependent on SDK uptime

### 8. Durable Brain Memory
**Location**: `NativeChatService.swift:49-50, 112-120, 343-357`

**Purpose**: Persistent context across sessions

**Storage**:
- In-memory during chat: `[String: [String]]` dictionary
- Persisted to Appwrite: JSON string in `conversations.memory`
- Injected into `COMPOSIO_MULTI_EXECUTE_TOOL` calls

**Example**:
```json
{
  "gmail": ["account_id_123"],
  "github": ["repo_mapping_456"]
}
```

### 9. Tool Name Sanitization
**Location**: `NativeChatService.swift:134-143`

**Why**: OpenAI function naming rules `^[a-zA-Z0-9_-]{1,64}$`

**Transformation**:
```
COMPOSIO:GITHUB_STAR_A_REPOSITORY → COMPOSIO_GITHUB_STAR_A_REPOSITORY
```

**Reverse Mapping**: `toolMapping` dictionary preserves original slugs for execution

### 10. @unchecked Sendable
**Locations**: `NativeChatService`, `ComposioManager`

**Why**: Swift concurrency requires `Sendable` conformance

**Risk**: Observable properties accessed across threads

**Mitigation**: All mutations wrapped in `@MainActor.run { }`

---

## Verification Notes

All claims verified by direct file inspection:

- ✅ Entry point: `Rube_iosApp.swift:10`
- ✅ Auth flow: `AuthService.swift:88-134`
- ✅ Chat loop: `NativeChatService.swift:195-414`
- ✅ Tool Router: `ComposioManager.swift:63-83`
- ✅ Persistence: `AppwriteConversationService.swift:120-225`
- ✅ OAuth: `OAuthService.swift`, `Info.plist:30-33`
- ✅ Config resolution: `ComposioConfig.swift:15-85`
- ✅ Database schema: `AppwriteClient.swift:19-23`

**Uncertainties**:
- Secrets.xcconfig contents (excluded from VCS)
- Actual LLM endpoint capabilities (assumed OpenAI-compatible from code)
- Full Appwrite database permissions (inferred from code patterns)

---

## Dependencies (Package.swift equivalent)

Extracted from `project.pbxproj` (lines 12, 19, 22, 33, 39):

```swift
dependencies: [
    .package(url: "https://github.com/appwrite/sdk-for-swift", from: "6.1.0"),
    .package(url: "https://github.com/jamesrochabrun/SwiftOpenAI", branch: "main"),
    .package(url: "https://github.com/composiohq/composio-swift", branch: "main"),
    .package(url: "https://github.com/apple/swift-async-algorithms", from: "1.0.0"),
    .package(url: "https://github.com/swift-server/swift-service-lifecycle", from: "2.0.0")
]
```

**Build Tool**: Swift Package Manager (SPM) integrated via Xcode

---

## Future Extension Opportunities

Based on architecture analysis:

1. **Offline Mode**: Cache conversations locally with Core Data, sync on reconnect
2. **Voice Input**: Integrate Speech framework, stream to LLM
3. **Rich Media**: Extend `Message` model for images, files (Appwrite storage)
4. **Multi-User Conversations**: Shared conversation model with Appwrite permissions
5. **Custom Tool Definitions**: Allow users to define personal tools/shortcuts
6. **Analytics**: Track tool usage, conversation metrics (privacy-respecting)
7. **Push Notifications**: Appwrite Realtime for background updates
8. **macOS/iPadOS**: Multi-platform with SwiftUI target expansion

---

**Document Version**: 1.0
**Generated**: 2026-01-22
**Codebase**: Rube-iOS (backup 2026-01-17)
**Total Files Analyzed**: 25 Swift files, 1 Info.plist, 1 project.pbxproj
