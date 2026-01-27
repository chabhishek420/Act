# Rube iOS - Architecture Documentation

## Project Overview

**Rube** is a native iOS application that provides an AI-powered chat assistant capable of integrating with 500+ third-party applications. The app features real-time streaming chat, OAuth-based app connections, conversation management, and tool execution visualization.

### Key Capabilities
- **AI Chat Interface**: Real-time streaming chat with Server-Sent Events (SSE)
- **Multi-App Integration**: OAuth flows for connecting external services (Gmail, Slack, etc.)
- **Conversation Management**: Persistent chat history with CRUD operations
- **Tool Execution Visibility**: Real-time display of AI tool calls and results
- **Authentication**: Appwrite-based user authentication with JWT tokens

### Technology Stack
- **Language**: Swift
- **UI Framework**: SwiftUI
- **Minimum Deployment**: iOS 18.0
- **Backend Integration**: REST APIs with SSE streaming
- **Authentication**: Appwrite SDK (v13.5.0+)
- **Dependencies**: Swift Package Manager (SPM)

---

## Project Structure

```
Rube-ios/
├── Rube-ios/
│   ├── Rube_iosApp.swift              # App entry point
│   ├── ContentView.swift              # Root view with auth routing
│   ├── Config/
│   │   └── Config.swift               # Environment configuration
│   ├── Models/
│   │   ├── Message.swift              # Chat message models
│   │   └── Conversation.swift         # Conversation models
│   ├── Services/
│   │   ├── AuthService.swift          # Appwrite authentication
│   │   ├── ChatService.swift          # SSE streaming chat
│   │   ├── ConversationService.swift  # Conversation API client
│   │   └── OAuthService.swift         # OAuth flow handler
│   ├── ViewModels/
│   │   └── ChatViewModel.swift        # Chat state management
│   ├── Views/
│   │   ├── Auth/
│   │   │   └── AuthView.swift         # Login/signup UI
│   │   ├── Chat/
│   │   │   └── ChatView.swift         # Main chat interface
│   │   └── Connection/
│   │       └── ConnectionPromptView.swift # OAuth prompt UI
│   ├── Utilities/
│   │   └── SSEParser.swift            # Server-Sent Events parser
│   ├── Lib/
│   │   └── AppwriteClient.swift       # Global Appwrite client
│   └── Info.plist                     # App metadata
├── project.yml                         # XcodeGen configuration
└── build/                              # Build artifacts (ignored)
```

---

## Architecture Patterns

### MVVM (Model-View-ViewModel)

The app follows MVVM architecture with SwiftUI's `@Observable` macro:

```
┌─────────────┐      ┌──────────────┐      ┌─────────────┐
│   Views     │─────▶│  ViewModels  │─────▶│  Services   │
│  (SwiftUI)  │      │ (@Observable)│      │  (Business  │
│             │◀─────│              │◀─────│   Logic)    │
└─────────────┘      └──────────────┘      └─────────────┘
                            │
                            ▼
                     ┌──────────────┐
                     │    Models    │
                     │  (Data DTOs) │
                     └──────────────┘
```

### Singleton Pattern

Services use shared singletons for app-wide state:
- `AuthService.shared` - Authentication state (AuthService.swift:36)
- Observable ViewModels - View-specific state management

### Observer Pattern

SwiftUI's `@Observable` macro provides automatic state updates:
- ViewModels notify views of state changes
- No manual `objectWillChange` needed (Swift 5.9+)

---

## Application Flow

### 1. App Launch

```
Rube_iosApp.swift:11-16
    ▼
ContentView.swift:11-52
    │
    ├─ isAuthenticated? ──▶ ChatView.swift:10
    │                       (Main chat interface)
    └─ !isAuthenticated ──▶ AuthView.swift:10
                            (Login/signup flow)
```

**Entry Point**: Rube_iosApp.swift:10-17
```swift
@main
struct Rube_iosApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

**Auth Routing**: ContentView.swift:16-51
- Checks `AuthService.shared.isAuthenticated` (line 18)
- Shows `ChatView()` if authenticated (line 19)
- Shows `AuthView()` if not authenticated (line 22)

### 2. Authentication Flow

```
┌──────────────┐
│   AuthView   │ User enters email/password
└──────┬───────┘
       │
       ▼
┌──────────────────┐
│  AuthService     │
│  .signIn()       │ Creates Appwrite session
│  (line 110)     │
└──────┬───────────┘
       │
       ├─ Success ──▶ Generate JWT token (line 124)
       │              Update isAuthenticated = true
       │              ContentView auto-navigates to ChatView
       │
       └─ Failure ──▶ Display error (line 127-130)
```

**Key Files**:
- AuthView.swift:106-128 - UI submit handler
- AuthService.swift:110-134 - Sign-in logic
- AuthService.swift:88-106 - Sign-up logic

**Authentication States** (AuthService.swift:41-47):
```swift
private(set) var session: Session?        // Appwrite session
private(set) var user: User<[String: AnyCodable]>?  // User profile
private(set) var jwt: String?             // JWT for API calls
var isAuthenticated: Bool { session != nil }
```

### 3. Chat Flow

```
User types message
    ▼
ChatView.swift:76-78 ──▶ ChatViewModel.sendMessage() (line 48)
    │
    ├─ Create optimistic user message (line 55-60)
    │
    ▼
ChatService.sendMessage() (line 48-62)
    │
    ├─ Build SSE request with JWT auth (line 88-103)
    ├─ Stream response via URLSession.bytes (line 106)
    │
    ▼
SSEParser.parse() (line 34-207)
    │
    ├─ Parse SSE events line-by-line (line 144-190)
    ├─ Emit text deltas ──▶ Update streamingContent (line 151-155)
    ├─ Emit tool calls ──▶ Update streamingToolCalls (line 157-175)
    └─ Emit connection requests ──▶ Show OAuth prompt (line 177-182)
    │
    ▼
ChatViewModel updates messages array (line 76)
    │
    ▼
ChatView auto-scrolls to new message (line 63-68)
```

**Streaming Architecture**:
1. **HTTP Streaming**: Uses `URLSession.shared.bytes(for:)` for SSE (ChatService.swift:106)
2. **Byte-by-byte Processing**: Builds buffer until newline (ChatService.swift:140-146)
3. **Event Parsing**: SSEParser extracts JSON from `data: ` prefix (SSEParser.swift:36-50)
4. **Real-time Updates**: `@MainActor` updates published properties (ChatService.swift:153-155)

### 4. OAuth Connection Flow

```
AI requests app connection
    ▼
SSEParser detects connection request (line 177-182)
    ▼
ChatService.onConnectionRequest callback (line 44)
    ▼
ChatViewModel shows prompt (line 37-42)
    ▼
ConnectionPromptView displays OAuth UI (line 10-126)
    │
User taps "Connect"
    ▼
OAuthService.startOAuth() (line 42-84)
    │
    ├─ Launch ASWebAuthenticationSession (line 52-83)
    ├─ User authenticates in browser
    └─ Callback URL returned (line 66-71)
    │
    ▼
ChatViewModel receives callback (line 135-149)
    │
    └─ Send callback URL to backend
       Backend completes OAuth exchange
```

**OAuth Architecture**:
- Uses `ASWebAuthenticationSession` for secure browser-based auth (OAuthService.swift:37)
- Supports custom callback schemes via `Info.plist` CFBundleURLSchemes (Info.plist:30)
- Handles cancellation and errors gracefully (OAuthService.swift:56-62)

---

## Core Components

### Configuration (Config.swift)

**Purpose**: Environment-aware backend URL configuration

**Structure** (Config.swift:11-44):
```swift
enum Config {
    // Development: localhost (DEBUG builds)
    // Production: Vercel URL (RELEASE builds)
    static let backendURL: URL

    // Appwrite settings
    static let appwriteEndpoint = "https://nyc.cloud.appwrite.io/v1"
    static let appwriteProjectId = "6961fcac000432c6a72a"

    // API endpoints
    static var chatURL: URL
    static var conversationsURL: URL
    static var appsConnectionURL: URL
    static var toolkitsURL: URL
}
```

**Environment Detection** (line 13-19):
- `#if DEBUG` → Uses `http://localhost:3000`
- `#else` → Uses production Vercel URL (needs configuration)

### Models

#### Message Model (Message.swift:10-34)
```swift
struct Message: Identifiable, Equatable {
    let id: String
    let content: String
    let role: MessageRole          // .user, .assistant, .system
    let timestamp: Date
    var toolCalls: [ToolCall]?     // Optional AI tool executions
}
```

#### ToolCall Model (Message.swift:42-66)
```swift
struct ToolCall: Identifiable, Equatable {
    let id: String
    let name: String               // e.g., "COMPOSIO_MANAGE_CONNECTIONS"
    var input: [String: Any]       // Tool parameters
    var output: Any?               // Tool result
    var status: ToolCallStatus     // .running, .completed, .error
}
```

#### Conversation Model (Conversation.swift:10-44)
```swift
struct Conversation: Identifiable, Codable {
    let id: String
    let title: String?
    let createdAt: Date
    let updatedAt: Date
}
```

**Date Parsing** (line 31-35):
- Uses `ISO8601DateFormatter` with fractional seconds
- Custom `Codable` implementation for API compatibility

### Services

#### AuthService (AuthService.swift)

**Singleton Architecture** (line 36):
```swift
static let shared = AuthService()
```

**Key Methods**:
- `signUp(email:password:name:)` - Create account (line 88-106)
- `signIn(email:password:)` - Email/password auth (line 110-134)
- `signOut()` - Delete session (line 138-149)
- `refreshJWT()` - Renew JWT token (line 153-165)
- `performRequestWithAutoRefresh(_:)` - Auto-retry on 401 (line 179-207)

**JWT Management**:
- JWT generated after successful login (line 124-125)
- Stored in memory (not persisted)
- Auto-refreshed on 401 errors (line 190-203)

**Session Persistence**:
- Checks for existing session on app launch (line 57-59)
- `account.get()` retrieves current user (line 67)
- `account.getSession(sessionId: "current")` retrieves session (line 71)

#### ChatService (ChatService.swift)

**SSE Streaming** (line 48-199):
```swift
func sendMessage(
    _ content: String,
    messages: [Message],
    conversationId: String?,
    onNewConversationId: @escaping (String) -> Void
) async throws -> Message
```

**Streaming State** (line 36-40):
```swift
private(set) var isStreaming = false
private(set) var streamingContent = ""
private(set) var streamingToolCalls: [ToolCall] = []
private(set) var pendingConnectionRequest: ConnectionRequest?
```

**Auto-Retry Logic** (line 113-122):
- Detects 401 responses
- Calls `AuthService.shared.refreshJWT()`
- Retries request with new JWT
- Prevents infinite retry loops with `isRetry` flag

**Event Processing Loop** (line 140-191):
```swift
for try await byte in bytes {
    buffer.append(Character(UnicodeScalar(byte)))

    while let newlineIndex = buffer.firstIndex(of: "\n") {
        let line = String(buffer[..<newlineIndex])
        buffer = String(buffer[buffer.index(after: newlineIndex)...])

        guard let event = SSEParser.parse(line: line) else { continue }

        switch event {
        case .textDelta(let delta): /* Update streamingContent */
        case .toolInputStart(let id, let name): /* Create tool call */
        case .toolOutputAvailable(let id, let output): /* Complete tool */
        case .connectionRequest(let request): /* Show OAuth prompt */
        case .done: /* Stream complete */
        case .error(let message): /* Throw error */
        }
    }
}
```

#### ConversationService (ConversationService.swift)

**Purpose**: Manage conversation history via REST API

**Key Methods**:
- `loadConversations()` - Fetch all conversations (line 17-50)
- `getMessages(conversationId:)` - Fetch conversation messages (line 54-97)
- `deleteConversation(_:)` - Delete conversation (line 101-128)

**Auto-Refresh Integration** (line 24-42):
```swift
let result = try await AuthService.shared.performRequestWithAutoRefresh { jwt in
    var request = URLRequest(url: Config.conversationsURL)
    request.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
    let (data, response) = try await URLSession.shared.data(for: request)
    // ... parse response
    return (decoded.conversations, httpResponse)
}
```

#### OAuthService (OAuthService.swift)

**Purpose**: Handle OAuth flows for third-party app connections

**Key Method** (`startOAuth(url:callbackScheme:)` - line 42-84):
```swift
@MainActor
func startOAuth(url: URL, callbackScheme: String? = nil) async throws -> URL
```

**ASWebAuthenticationSession Integration**:
- Presents system OAuth browser (line 52-72)
- Handles callback URL interception (line 66-71)
- Supports ephemeral vs persistent sessions (line 75)

**Callback Scheme Detection** (line 87-95):
- Extracts `redirect_uri` from OAuth URL query params
- Falls back to `rube://` if not found
- Matches `Info.plist` URL scheme (Info.plist:30)

### ViewModels

#### ChatViewModel (ChatViewModel.swift)

**Purpose**: Coordinate chat UI state and service interactions

**State Properties** (line 16-24):
```swift
var messages: [Message] = []
var currentConversationId: String?
var inputText = ""
var isLoading = false
var errorMessage: String?
var pendingConnectionRequest: ConnectionRequest?
var showConnectionPrompt = false
```

**Forwarded Properties** (line 27-33):
- Exposes ChatService streaming state to views
- Exposes ConversationService conversation list

**Key Methods**:
- `sendMessage()` - Send user message and handle response (line 48-86)
- `loadConversation(_:)` - Load conversation history (line 91-94)
- `startNewChat()` - Reset chat state (line 99-104)
- `connectApp(oauthUrl:)` - Initiate OAuth flow (line 128-150)

**Connection Request Callback** (line 36-42):
```swift
chatService.onConnectionRequest = { [weak self] request in
    Task { @MainActor in
        self?.pendingConnectionRequest = request
        self?.showConnectionPrompt = true
    }
}
```

### Utilities

#### SSEParser (SSEParser.swift)

**Purpose**: Parse Server-Sent Events from chat API

**Event Types** (line 10-18):
```swift
enum SSEEvent {
    case textDelta(String)
    case toolInputStart(id: String, name: String)
    case toolInputAvailable(id: String, input: [String: Any])
    case toolOutputAvailable(id: String, output: Any)
    case connectionRequest(ConnectionRequest)
    case done
    case error(String)
}
```

**Parsing Logic** (`parse(line:)` - line 34-207):

1. **Extract JSON** (line 36-50):
   ```swift
   guard line.hasPrefix("data: ") else { return nil }
   let data = String(line.dropFirst(6))
   guard let json = try? JSONSerialization.jsonObject(with: jsonData)
   ```

2. **Route by Type** (line 55-204):
   - `text-delta` → Text streaming
   - `tool-input-start` → Tool execution begins
   - `tool-input-available` → Tool parameters available
   - `tool-output-available` → Tool result available
   - `error` → Error message

3. **Connection Request Detection** (line 86-104, 112-192):
   - Detects `REQUEST_USER_INPUT` tool output
   - Detects `COMPOSIO_MANAGE_CONNECTIONS` tool output
   - Detects `RUBE_MANAGE_CONNECTIONS` tool output
   - Extracts OAuth URL from multiple formats:
     - Direct `auth_url` field (line 149-154)
     - Nested `data.results[toolkit].redirect_url` (line 157-174)
     - Wrapped in `content[0].text` JSON string (line 130-136)

**Connection Request Model** (line 20-30):
```swift
struct ConnectionRequest {
    let provider: String           // "Gmail", "Slack", etc.
    let fields: [[String: Any]]    // Additional form fields
    let authConfigId: String?      // Backend auth config ID
    let logoUrl: String?           // Provider logo
    let oauthUrl: String?          // OAuth initiation URL

    var isOAuthOnly: Bool { fields.isEmpty && oauthUrl != nil }
}
```

### Views

#### ChatView (ChatView.swift)

**Main Components**:

1. **Messages List** (line 29-70):
   - `ScrollViewReader` for auto-scroll
   - `LazyVStack` for performance
   - `MessageBubble` for each message
   - `StreamingMessageView` for active stream
   - Auto-scrolls on new messages (line 63-68)

2. **Input Bar** (line 73-79):
   - `MessageInputView` with send button
   - Disabled during loading

3. **Toolbar** (line 84-100):
   - Sidebar toggle (conversations list)
   - New chat button

4. **Connection Prompt Overlay** (line 129-154):
   - Modal overlay with backdrop
   - `ConnectionPromptView` for OAuth
   - Dismiss on background tap

**Subviews**:

- **MessageBubble** (line 199-225):
  - User messages: right-aligned, blue
  - Assistant messages: left-aligned, gray
  - Text selection enabled
  - Tool calls shown below message

- **StreamingMessageView** (line 229-264):
  - Real-time content updates
  - Tool call progress indicators
  - Typing indicator when empty

- **ToolCallView** (line 268-357):
  - Expandable accordion
  - Status icons (running/completed/error)
  - JSON-formatted input/output
  - Limited to 10 lines of output

- **ConversationSidebar** (line 396-440):
  - Sheet presentation
  - Conversation list with timestamps
  - Swipe-to-delete actions
  - "New Chat" button

#### AuthView (AuthView.swift)

**Features**:
- Toggle between sign-in and sign-up (line 90-99)
- Optional name field for sign-up (line 41-46)
- Email validation (keyboardType, textContentType)
- Error message display (line 61-67)
- Loading state with disabled submit (line 86)

#### ConnectionPromptView (ConnectionPromptView.swift)

**OAuth Flow** (line 51-73):
- Shows provider logo (AsyncImage)
- "Continue with {Provider}" button
- Calls `onConnect(oauthUrl)` when tapped

**Custom Fields Flow** (line 74-111):
- Displays additional form fields
- TextField for each field with placeholder
- Submit button triggers OAuth with collected data

---

## Data Flow Diagrams

### Message Send Flow

```
┌─────────────┐
│   User      │ Types message
│   Input     │
└──────┬──────┘
       │
       ▼
┌──────────────────┐
│ ChatViewModel    │
│ .sendMessage()   │ Create optimistic user message
└──────┬───────────┘
       │
       ▼
┌──────────────────┐
│  ChatService     │ Build POST /api/chat request
│ .sendMessage()   │ Add JWT Bearer token
└──────┬───────────┘
       │
       ▼
┌──────────────────┐
│  URLSession      │ Stream SSE response
│  .bytes(for:)    │ Byte-by-byte reading
└──────┬───────────┘
       │
       ▼
┌──────────────────┐
│  SSEParser       │ Parse "data: {json}\n" lines
│  .parse()        │ Extract event type
└──────┬───────────┘
       │
       ├─ text-delta ──────────▶ Update streamingContent
       ├─ tool-input-start ────▶ Create ToolCall (running)
       ├─ tool-output-available ─▶ Update ToolCall (completed)
       └─ connection-request ───▶ Show OAuth prompt
       │
       ▼
┌──────────────────┐
│ ChatViewModel    │ Append assistant Message
│ .messages        │ Trigger UI update
└──────────────────┘
       │
       ▼
┌──────────────────┐
│   ChatView       │ Auto-scroll to bottom
│   ScrollView     │ Display new message
└──────────────────┘
```

### OAuth Connection Flow

```
┌──────────────────┐
│  Backend AI      │ Needs app connection
│  Tool Call       │ Returns user_input_request
└──────┬───────────┘
       │
       ▼
┌──────────────────┐
│  SSEParser       │ Detects connectionRequest event
│                  │ Extracts provider, oauthUrl
└──────┬───────────┘
       │
       ▼
┌──────────────────┐
│  ChatService     │ Fires onConnectionRequest callback
│                  │ pendingConnectionRequest = request
└──────┬───────────┘
       │
       ▼
┌──────────────────┐
│ ChatViewModel    │ showConnectionPrompt = true
│                  │ pendingConnectionRequest = request
└──────┬───────────┘
       │
       ▼
┌──────────────────┐
│ ConnectionPrompt │ Display provider name, logo
│ View             │ "Connect" button with oauthUrl
└──────┬───────────┘
       │
    User taps "Connect"
       │
       ▼
┌──────────────────┐
│  OAuthService    │ Launch ASWebAuthenticationSession
│ .startOAuth()    │ Open OAuth URL in browser
└──────┬───────────┘
       │
    User authenticates
       │
       ▼
┌──────────────────┐
│ System Callback  │ Intercept rube://callback?code=...
│ URL Handler      │ Return callback URL
└──────┬───────────┘
       │
       ▼
┌──────────────────┐
│ ChatViewModel    │ Send callback URL to backend
│ .connectApp()    │ Backend exchanges code for token
└──────────────────┘
```

---

## API Integration

### Backend Endpoints

Defined in Config.swift:32-36:

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/api/chat` | POST | Send message, receive SSE stream |
| `/api/conversations` | GET | List all conversations |
| `/api/conversations/:id/messages` | GET | Get conversation messages |
| `/api/conversations/:id` | DELETE | Delete conversation |
| `/api/apps/connection` | POST | Complete app connection |
| `/api/toolkits` | GET | List available toolkits |

### Chat API Contract

**Request** (ChatService.swift:94-103):
```json
{
  "messages": [
    {"role": "user", "content": "Hello"},
    {"role": "assistant", "content": "Hi!"}
  ],
  "conversationId": "abc123" // Optional
}
```

**Headers**:
- `Content-Type: application/json`
- `Authorization: Bearer {jwt}`

**Response** (SSE stream):
```
data: {"type": "text-delta", "delta": "Hello"}

data: {"type": "tool-input-start", "toolCallId": "1", "toolName": "SEARCH"}

data: {"type": "tool-output-available", "toolCallId": "1", "output": {...}}

data: [DONE]
```

**New Conversation ID** (ChatService.swift:125-128):
- Returned in `X-Conversation-Id` response header
- First message in new conversation triggers header
- Client updates `currentConversationId`

### Appwrite Integration

**Client Setup** (AppwriteClient.swift:11-15):
```swift
let client = Client()
    .setEndpoint("https://nyc.cloud.appwrite.io/v1")
    .setProject("6961fcac000432c6a72a")

let account = Account(client)
```

**Account Operations** (AuthService.swift):
- `account.create()` - Create user (line 91-96)
- `account.createEmailPasswordSession()` - Login (line 113-116)
- `account.get()` - Get current user (line 120)
- `account.createJWT()` - Generate JWT (line 124)
- `account.deleteSession()` - Logout (line 141)

---

## State Management

### Observable Pattern

Uses Swift 5.9 `@Observable` macro for automatic state updates:

**Service Example** (ChatService.swift:33-40):
```swift
@Observable
final class ChatService {
    private(set) var isStreaming = false
    private(set) var streamingContent = ""
    // Changes automatically notify SwiftUI views
}
```

**View Binding** (ChatView.swift:38-43):
```swift
if viewModel.isStreaming {
    StreamingMessageView(
        content: viewModel.streamingContent,
        toolCalls: viewModel.streamingToolCalls
    )
}
// View auto-updates when streamingContent changes
```

### ViewModel Responsibilities

**ChatViewModel** owns:
- Message list state
- Conversation ID tracking
- Input text state
- Connection prompt visibility
- Error handling

**Services** (injected, not owned):
- ChatService (streaming logic)
- ConversationService (API client)
- OAuthService (OAuth flows)

---

## Dependency Management

### Swift Package Manager

**Dependencies**:
- **Appwrite**: User authentication, session management
- **ServiceLifecycle**: (Declared but not used in source code)
- **AsyncAlgorithms**: (Declared but not used in source code)

**Transitive Dependencies**:
Resolved in `build/SourcePackages/`:
- `swift-nio-transport-services` (via Appwrite)
- `swift-system` (via Appwrite)

---

## Configuration & Environment

### Development vs Production

**Conditional Compilation** (Config.swift:13-26):
```swift
#if DEBUG
private static let isDevelopment = true  // localhost:3000
#else
private static let isDevelopment = false // Vercel production
#endif
```

**Backend URLs**:
- Development: `http://localhost:3000`
- Production: `https://your-app.vercel.app` ⚠️ **Needs configuration**

### Info.plist Configuration

**URL Schemes** (Info.plist:21-33):
```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>rube</string>
        </array>
    </dict>
</array>
```
- Enables `rube://` deep linking
- Required for OAuth callback interception

**Bundle Info** (Info.plist:7-8):
- Display Name: "Rube"
- Bundle ID: `com.rube.ios`
- Version: 1.0 (Build 1)

---

## Extension Points

### 1. Adding New SSE Event Types

**Location**: SSEParser.swift:10-18, 55-204

**Steps**:
1. Add case to `SSEEvent` enum (line 10-18)
2. Add parsing logic in `parse(line:)` switch (line 55-204)
3. Handle event in `ChatService.sendMessage()` loop (line 150-189)

**Example**:
```swift
// 1. Add enum case
enum SSEEvent {
    case fileAttachment(url: String, name: String)
    // ...
}

// 2. Parse event
case "file-attachment":
    if let url = json["url"] as? String,
       let name = json["name"] as? String {
        return .fileAttachment(url: url, name: name)
    }

// 3. Handle in ChatService
case .fileAttachment(let url, let name):
    // Download file, show in UI, etc.
```

### 2. Adding New Tool Call Visualizations

**Location**: ChatView.swift:268-357

**Current Display**:
- Status icon (running/completed/error)
- Expandable accordion
- JSON input/output

**Extension Points**:
- Custom UI per tool name (line 296)
- Rich rendering for specific output types (line 345-356)
- Action buttons in tool cards

**Example**:
```swift
// In ToolCallView.body
if toolCall.name == "SEND_EMAIL" {
    EmailToolView(toolCall: toolCall)
} else {
    // Default JSON view
}
```

### 3. Adding Authentication Providers

**Location**: AuthService.swift, AuthView.swift

**Current**: Email/password via Appwrite

**OAuth Extension**:
1. Add OAuth provider to AuthService
2. Add UI button in AuthView
3. Handle OAuth callback in app delegate
4. Create session from OAuth token

**Example**:
```swift
// AuthService
func signInWithGoogle() async throws {
    let token = try await GoogleSignIn.shared.signIn()
    // Exchange token with Appwrite
}

// AuthView
Button("Continue with Google") {
    Task { try await AuthService.shared.signInWithGoogle() }
}
```

### 4. Custom Message Rendering

**Location**: ChatView.swift:199-225

**Current**: Text bubbles with tool calls

**Extension Points**:
- Markdown rendering (add `MarkdownUI` dependency)
- Code syntax highlighting
- Image/file attachments
- Interactive components (buttons, forms)

**Example**:
```swift
struct MessageBubble: View {
    let message: Message

    var body: some View {
        if message.content.contains("```") {
            CodeBlockView(content: message.content)
        } else {
            Text(message.content)
        }
    }
}
```

### 5. Conversation Features

**Location**: ConversationService.swift, ChatView.swift:396-440

**Current**: List, load, delete

**Extension Points**:
- Rename conversation (PATCH `/api/conversations/:id`)
- Search conversations (GET `/api/conversations?q=...`)
- Pin/favorite conversations
- Export conversation to PDF/text

**Example**:
```swift
// ConversationService
func renameConversation(_ id: String, title: String) async -> Bool {
    var request = URLRequest(url: Config.conversationsURL.appendingPathComponent(id))
    request.httpMethod = "PATCH"
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.httpBody = try JSONEncoder().encode(["title": title])
    // ...
}
```

---

## Error Handling

### Authentication Errors

**Custom Error Type** (AuthService.swift:11-32):
```swift
enum AuthError: LocalizedError {
    case notAuthenticated
    case invalidCredentials
    case emailNotVerified
    case networkError(Error)
    case unknown(String)
}
```

**Usage Pattern**:
```swift
do {
    try await AuthService.shared.signIn(email: email, password: password)
} catch let error as AuthError {
    // Handle specific auth errors
    errorMessage = error.localizedDescription
} catch {
    // Handle unexpected errors
}
```

### Chat Errors

**Custom Error Type** (ChatService.swift:10-31):
```swift
enum ChatError: LocalizedError {
    case unauthorized
    case invalidResponse
    case httpError(Int)
    case serverError(String)
    case networkError(Error)
}
```

**Auto-Retry on 401** (ChatService.swift:113-122):
- Refresh JWT token
- Retry request once
- Prevent infinite loops with `isRetry` flag

### OAuth Errors

**Custom Error Type** (OAuthService.swift:12-33):
```swift
enum OAuthError: LocalizedError {
    case cancelled
    case invalidURL
    case noCallback
    case failedToStart
    case networkError(Error)
}
```

**User Cancellation** (OAuthService.swift:56-62):
- Detects `ASWebAuthenticationSessionError.canceledLogin`
- Converts to custom `OAuthError.cancelled`
- ViewModel displays error or dismisses silently

---

## Performance Considerations

### 1. Lazy Loading

**Messages List** (ChatView.swift:31):
```swift
LazyVStack(spacing: 12) {
    ForEach(viewModel.messages) { message in
        MessageBubble(message: message)
    }
}
```
- Only renders visible messages
- Reduces memory for long conversations

### 2. Byte Streaming

**SSE Processing** (ChatService.swift:140-191):
- Processes bytes as they arrive
- No buffering entire response in memory
- Immediate UI updates for perceived speed

### 3. Async Image Loading

**Provider Logos** (ConnectionPromptView.swift:19-30):
```swift
AsyncImage(url: url) { image in
    image.resizable().scaledToFit()
} placeholder: {
    Image(systemName: "app.fill")
}
```
- Non-blocking image downloads
- Fallback placeholder during load

### 4. Main Actor Isolation

**State Updates** (ChatService.swift:75-79):
```swift
await MainActor.run {
    self.isStreaming = true
    self.streamingContent = ""
}
```
- All UI state updates on main thread
- Prevents thread safety issues

---

## Security Considerations

### 1. JWT Token Storage

**Current**: In-memory only (AuthService.swift:43)
- ✅ Secure: Not persisted to disk
- ⚠️ Limitation: Lost on app termination

**Recommendation**: Use Keychain for secure persistence
```swift
// Store JWT in Keychain
KeychainWrapper.standard.set(jwt, forKey: "userJWT")

// Retrieve on app launch
if let jwt = KeychainWrapper.standard.string(forKey: "userJWT") {
    self.jwt = jwt
}
```

### 2. OAuth Security

**ASWebAuthenticationSession** (OAuthService.swift:74-75):
```swift
session.prefersEphemeralWebBrowserSession = false
```
- `false`: Allows SSO (shares cookies with Safari)
- `true`: Isolated session (more secure, no SSO)

**Callback Validation**:
- ⚠️ Currently trusts all `rube://` callbacks
- **Recommendation**: Validate state parameter to prevent CSRF

### 3. HTTPS Enforcement

**Production Backend** (Config.swift:24):
- ⚠️ Placeholder URL `https://your-app.vercel.app`
- ✅ Must use HTTPS in production
- ⚠️ Development uses HTTP localhost (acceptable for local testing)

### 4. Input Validation

**Current**: Minimal validation
- Email format: Handled by SwiftUI `.keyboardType(.emailAddress)`
- Password strength: Not enforced client-side

**Recommendations**:
- Add password strength requirements
- Sanitize user input before sending to backend
- Validate conversation IDs are UUIDs

---

## Testing Strategy

### Unit Tests

**Services to Test**:
1. **SSEParser** (SSEParser.swift):
   - Parse various event types
   - Handle malformed JSON
   - Extract connection requests from nested structures

2. **AuthService** (AuthService.swift):
   - Mock Appwrite client
   - Test JWT refresh logic
   - Test error mapping

3. **ConversationService** (ConversationService.swift):
   - Mock URLSession
   - Test auto-retry on 401
   - Test response parsing

### Integration Tests

1. **OAuth Flow**:
   - Mock ASWebAuthenticationSession
   - Test callback URL handling
   - Test cancellation

2. **Chat Streaming**:
   - Mock SSE stream
   - Test incremental updates
   - Test tool call lifecycle

### UI Tests

1. **Authentication Flow**:
   - Sign up new user
   - Sign in existing user
   - Handle invalid credentials

2. **Chat Flow**:
   - Send message
   - Receive streaming response
   - Load conversation history

3. **Connection Prompt**:
   - Display OAuth prompt
   - Launch browser
   - Handle callback

---

## Known Limitations & TODOs

### 1. Production URL Configuration

**File**: Config.swift:24
```swift
private static let productionURL = "https://your-app.vercel.app" // ← Update this
```
- ⚠️ Placeholder URL must be replaced before production release

### 2. Unused Dependencies

- `ServiceLifecycle` - Declared but not imported anywhere
- `AsyncAlgorithms` - Declared but not imported anywhere

**Recommendation**: Remove unused dependencies or document intended use

### 3. Error Recovery

**Chat Stream Interruption**:
- Network drop during streaming → User must resend message
- **Enhancement**: Implement retry with last message ID

**Session Expiry**:
- Appwrite session expires → User must re-authenticate
- **Enhancement**: Detect expiry, prompt re-auth, resume activity

### 4. Offline Support

**Current**: No offline mode
- Cannot send messages without network
- Cannot view cached conversations

**Enhancement**:
- Cache messages with Core Data / SwiftData
- Queue messages for send when online
- Sync on reconnection

### 5. Tool Call Limitations

**Output Display** (ChatView.swift:326):
```swift
.lineLimit(10)
```
- Large tool outputs truncated
- **Enhancement**: Expandable "Show More" or sheet presentation

### 6. Conversation Title Generation

**Current**: Server-generated titles (Conversation.swift:12)
- Client displays `"Untitled"` if nil
- **Enhancement**: Client-side title generation from first message

---

## Build & Deployment

### Build Configuration

**Deployment Target**: iOS 18.0+

**Bundle Identifier**: `com.rube.ios`

### Build Schemes

**Debug**:
- Backend: `http://localhost:3000`
- Appwrite: `https://nyc.cloud.appwrite.io/v1`

**Release**:
- Backend: Production Vercel URL (must configure)
- Appwrite: `https://nyc.cloud.appwrite.io/v1`

### App Store Preparation

**Required Updates**:
1. Set production backend URL (Config.swift:24)
2. Update marketing version
3. Configure App Store Connect metadata
4. Add privacy policy URL (OAuth requirements)
5. Test OAuth flows on real device
6. Enable App Transport Security for HTTPS

---

## Troubleshooting

### "Unauthorized" Errors

**Symptom**: 401 errors on chat/conversation requests

**Causes**:
1. JWT expired → Auto-refresh should handle (ChatService.swift:113-122)
2. No active session → Sign out and sign in again
3. Appwrite session invalidated server-side

**Debug**:
```swift
// Check auth state
print("JWT: \(AuthService.shared.jwt ?? "nil")")
print("Session: \(AuthService.shared.session != nil)")
```

### OAuth Callback Not Working

**Symptom**: OAuth browser opens but doesn't return to app

**Causes**:
1. Callback scheme not registered in Info.plist
2. Backend redirect_uri mismatch
3. ASWebAuthenticationSession cancelled

**Debug**:
```swift
// OAuthService.swift:56-71
print("Callback URL: \(callbackURL?.absoluteString ?? "nil")")
print("Error: \(error?.localizedDescription ?? "nil")")
```

### Streaming Not Updating

**Symptom**: No text appears during streaming

**Causes**:
1. SSE events not parsing (check `data: ` prefix)
2. Main actor updates not firing
3. Backend not sending SSE format

**Debug**:
```swift
// SSEParser.swift:53
print("📨 SSE EVENT: type=\(type), json=\(json)")

// ChatService.swift:151-155
print("Streaming content: \(fullContent)")
```

---

## Glossary

| Term | Definition |
|------|------------|
| **SSE** | Server-Sent Events - HTTP streaming protocol for real-time updates |
| **JWT** | JSON Web Token - Stateless authentication token |
| **Appwrite** | Backend-as-a-Service platform for authentication and databases |
| **OAuth** | Authorization protocol for third-party app access |
| **ASWebAuthenticationSession** | iOS API for secure OAuth flows in browser |
| **Observable** | Swift 5.9 macro for automatic state observation |
| **MVVM** | Model-View-ViewModel architecture pattern |
| **Tool Call** | AI function execution (e.g., search, API call) |
| **Conversation** | Chat history thread with multiple messages |

---

## ASCII Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                         Rube iOS App                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐         │
│  │   AuthView   │  │   ChatView   │  │ Connection   │         │
│  │              │  │              │  │  PromptView  │         │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘         │
│         │                 │                  │                  │
│         │                 │                  │                  │
│         ▼                 ▼                  ▼                  │
│  ┌──────────────────────────────────────────────────┐          │
│  │            ChatViewModel (@Observable)           │          │
│  │  • messages: [Message]                           │          │
│  │  • currentConversationId: String?                │          │
│  │  • showConnectionPrompt: Bool                    │          │
│  └──────────┬───────────────────────────────────────┘          │
│             │                                                   │
│    ┌────────┼────────────────┐                                 │
│    │        │                │                                 │
│    ▼        ▼                ▼                                 │
│  ┌───────┐ ┌──────┐ ┌────────────┐ ┌────────────┐             │
│  │ Auth  │ │ Chat │ │Conversation│ │   OAuth    │             │
│  │Service│ │Service│ │  Service   │ │  Service   │             │
│  │       │ │       │ │            │ │            │             │
│  │• JWT  │ │•Stream│ │• Load List │ │• Browser   │             │
│  │• User │ │•Parse │ │• Get Msgs  │ │• Callback  │             │
│  └───┬───┘ └───┬──┘ └─────┬──────┘ └─────┬──────┘             │
│      │         │          │              │                     │
│      │         └──────────┼──────────────┘                     │
│      │                    │                                    │
│      ▼                    ▼                                    │
│  ┌─────────────────────────────────────┐                      │
│  │         URLSession / Network        │                      │
│  │  • HTTP Requests                    │                      │
│  │  • SSE Streaming                    │                      │
│  │  • Auto-Retry on 401                │                      │
│  └───────────┬─────────────────────────┘                      │
│              │                                                 │
└──────────────┼─────────────────────────────────────────────────┘
               │
     ┌─────────┴────────────┐
     │                      │
     ▼                      ▼
┌─────────────┐      ┌─────────────┐
│  Appwrite   │      │   Backend   │
│   Server    │      │    API      │
│             │      │             │
│ • Auth      │      │ • Chat SSE  │
│ • Sessions  │      │ • Convos    │
│ • JWT       │      │ • Tools     │
└─────────────┘      └─────────────┘
```

---

## File Reference Index

| File | Lines | Purpose |
|------|-------|---------|
| Rube_iosApp.swift | 17 | App entry point |
| ContentView.swift | 72 | Auth routing, ping test |
| Config.swift | 45 | Environment config, URLs |
| Message.swift | 73 | Message/ToolCall models |
| Conversation.swift | 67 | Conversation models, API DTOs |
| AuthService.swift | 209 | Appwrite authentication |
| ChatService.swift | 211 | SSE streaming chat |
| ConversationService.swift | 130 | Conversation API client |
| OAuthService.swift | 109 | OAuth flow handler |
| ChatViewModel.swift | 160 | Chat state coordinator |
| SSEParser.swift | 228 | SSE event parser |
| AppwriteClient.swift | 16 | Global Appwrite setup |
| ChatView.swift | 445 | Main chat UI |
| AuthView.swift | 134 | Login/signup UI |
| ConnectionPromptView.swift | 143 | OAuth prompt UI |
| Info.plist | 43 | App metadata, URL schemes |

---

## Quick Start Guide

### For New Developers

1. **Clone & Setup**:
   ```bash
   cd Rube-ios
   open Rube-ios.xcodeproj
   ```

2. **Configure Backend**:
   - Set production URL in Config.swift:24
   - Verify Appwrite project ID in Config.swift:30

3. **Run App**:
   - Select simulator (iOS 18.0+)
   - Cmd+R to build and run

4. **Test Flow**:
   - Sign up with email/password
   - Send message: "Hello"
   - Observe streaming response
   - Test OAuth: "Connect my Gmail"

### Key Entry Points

- **App Launch**: Rube_iosApp.swift:10
- **Auth Check**: ContentView.swift:18
- **Message Send**: ChatViewModel.swift:48
- **SSE Parse**: SSEParser.swift:34
- **OAuth Start**: OAuthService.swift:42

### Common Tasks

**Add new SSE event**:
1. Edit SSEParser.swift:10-18 (enum)
2. Edit SSEParser.swift:55-204 (parse logic)
3. Edit ChatService.swift:150-189 (handle event)

**Add new API endpoint**:
1. Edit Config.swift:32-36 (add static var)
2. Create service method (e.g., ConversationService)
3. Call from ViewModel

**Customize message UI**:
1. Edit ChatView.swift:199-225 (MessageBubble)
2. Add conditional rendering based on content

---

## Summary

Rube iOS is a production-ready AI chat application with:
- ✅ Real-time SSE streaming
- ✅ Appwrite authentication with JWT
- ✅ OAuth flows for app connections
- ✅ Conversation history management
- ✅ Tool execution visualization
- ⚠️ Production URL configuration needed

**Architecture Strengths**:
- Clean MVVM separation
- Observable state management
- Auto-retry error handling
- Secure OAuth implementation

**Recommended Enhancements**:
1. Keychain JWT storage
2. Offline conversation caching
3. Message retry on network failure
4. Enhanced tool call UI
5. Search conversations

---

*Generated: 2026-01-26*
*Codebase Version: 1.0*
*iOS Target: 18.0+*
