# Composio API Reference - Verified

**Last Verified:** 2026-01-23  
**API Version:** v3  
**Base URL:** `https://backend.composio.dev/api/v3`

---

## Authentication

All requests require the `x-api-key` header:

```bash
curl -H "x-api-key: YOUR_API_KEY" https://backend.composio.dev/api/v3/apps
```

**Available API Keys:**
- Primary: `ak_5j2LU5s9bVapMLI2kHfL` ✅ Verified
- Secondary: `ak_zADvaco59jaMiHrqpjj4` ✅ Verified  
- Playground: `ak_d8LOxjp7ei0ZyCzkj6-P` ✅ Verified

---

## Swift SDK Methods

### ToolRouterClient

```swift
import Composio

let composio = Composio(apiKey: apiKey)

// 1. Create Tool Router Session
let session = try await composio.toolRouter.createSession(
    for: userId,
    toolkits: ["gmail", "slack", "github"] // nil = all 500+ tools
)
// Returns: ToolRouterSession { sessionId, mcp, toolRouterTools }

// 2. Fetch Session Tools
let tools = try await composio.toolRouter.fetchTools(in: session.sessionId)
// Returns: [Tool]

// 3. Execute Meta-Tool (COMPOSIO_SEARCH_TOOLS, COMPOSIO_MANAGE_CONNECTIONS)
let response = try await composio.toolRouter.executeMeta(
    "COMPOSIO_SEARCH_TOOLS",
    in: session.sessionId,
    arguments: ["queries": [["use_case": "fetch unread emails"]]]
)
// Returns: ToolRouterExecuteResponse { data, error, logId }

// 4. Execute Regular Tool
let result = try await composio.toolRouter.execute(
    "GMAIL_FETCH_EMAILS",
    in: session.sessionId,
    arguments: ["query": "is:unread", "max_results": 25]
)
// Returns: ToolRouterExecuteResponse

// 5. Create Auth Link
let link = try await composio.toolRouter.createLink(
    for: "gmail",
    in: session.sessionId
)
// Returns: ToolRouterLinkResponse { connectedAccountId, linkToken, redirectUrl }
```

### OAuthManager

```swift
let oauthManager = OAuthManager(composio: composio)

// OAuth flow with ASWebAuthenticationSession
let account = try await oauthManager.authenticate(
    userId: "user_123",
    toolkit: "gmail",
    callbackURLScheme: "act" // Must match Info.plist URL scheme
)
// Returns: ConnectedAccount
// Published properties: isAuthenticating, error
```

### ToolsClient

```swift
// Fetch tools for user
let tools = try await composio.tools.fetch(
    for: userId,
    options: ToolsGetOptions(toolkits: ["gmail"])
)

// Execute tool directly (non-session)
let result = try await composio.tools.execute(
    "GMAIL_SEND_EMAIL",
    for: userId,
    parameters: ["to": "user@example.com", "subject": "Hello"]
)

// Search tools
let tools = try await composio.tools.search(for: "send email")
```

---

## REST Endpoints

### 1. GET /apps
**Purpose:** List all available apps  
**Verified:** ✅ Returns 500+ apps

```bash
curl -X GET "https://backend.composio.dev/api/v1/apps" \
  -H "X-API-Key: ak_5j2LU5s9bVapMLI2kHfL"
```

**Response:**
```json
{
  "items": [
    {
      "key": "github",
      "name": "github",
      "displayName": "GitHub",
      "enabled": true,
      "categories": ["developer tools"],
      "meta": {
        "triggersCount": 15,
        "actionsCount": 120
      }
    }
  ],
  "totalPages": 1
}
```

### 2. GET /connected_accounts
**Purpose:** List user's connected accounts  
**Verified:** ✅ Returns active connections

```bash
curl -X GET "https://backend.composio.dev/api/v1/connectedAccounts" \
  -H "X-API-Key: ak_5j2LU5s9bVapMLI2kHfL"
```

**Response:**
```json
{
  "items": [
    {
      "id": "conn_123",
      "appUniqueId": "gmail",
      "status": "ACTIVE",
      "clientUniqueUserId": "default",
      "createdAt": "2025-10-25T18:42:43.574Z"
    }
  ]
}
```

### 3. POST /tool_router/session
**Purpose:** Create Tool Router session  
**SDK Method:** `toolRouter.createSession(for:toolkits:)`

```bash
curl -X POST "https://backend.composio.dev/api/v3/tool_router/session" \
  -H "x-api-key: YOUR_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": "user@example.com",
    "toolkits": ["gmail", "slack"]
  }'
```

**Response:**
```json
{
  "session_id": "sess_abc123",
  "mcp": {
    "type": "sse",
    "url": "https://backend.composio.dev/api/v3/mcp/sse",
    "headers": {
      "x-api-key": "YOUR_KEY",
      "x-session-id": "sess_abc123"
    }
  },
  "tool_router_tools": ["COMPOSIO_SEARCH_TOOLS", "COMPOSIO_MANAGE_CONNECTIONS"]
}
```

### 4. GET /tool_router/session/{id}/tools
**Purpose:** List meta-tools in session  
**SDK Method:** `toolRouter.fetchTools(in:)`

```bash
curl -X GET "https://backend.composio.dev/api/v3/tool_router/session/sess_abc123/tools" \
  -H "x-api-key: YOUR_KEY"
```

### 5. POST /tool_router/session/{id}/execute_meta
**Purpose:** Execute meta-tool (COMPOSIO_SEARCH_TOOLS, COMPOSIO_MANAGE_CONNECTIONS)  
**SDK Method:** `toolRouter.executeMeta(_:in:arguments:)`

```bash
curl -X POST "https://backend.composio.dev/api/v3/tool_router/session/sess_abc123/execute_meta" \
  -H "x-api-key: YOUR_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "tool_name": "COMPOSIO_SEARCH_TOOLS",
    "arguments": {
      "queries": [
        {
          "use_case": "send an email via gmail"
        }
      ]
    }
  }'
```

**Response:**
```json
{
  "data": {
    "results": [{
      "index": 1,
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
      "instructions": "REQUIRED: Pass session_id 'load' in ALL subsequent meta tool calls."
    },
    "success": true
  },
  "error": null,
  "log_id": "log_B6kA3mUuao_R"
}
```

### 6. POST /tool_router/session/{id}/execute
**Purpose:** Execute regular tool  
**SDK Method:** `toolRouter.execute(_:in:arguments:)`

```bash
curl -X POST "https://backend.composio.dev/api/v3/tool_router/session/sess_abc123/execute" \
  -H "x-api-key: YOUR_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "tool_name": "GMAIL_SEND_EMAIL",
    "arguments": {
      "to": "user@example.com",
      "subject": "Hello",
      "body": "Test message"
    }
  }'
```

### 7. POST /tool_router/session/{id}/link
**Purpose:** Create OAuth connection link  
**SDK Method:** `toolRouter.createLink(for:in:)`

```bash
curl -X POST "https://backend.composio.dev/api/v3/tool_router/session/sess_abc123/link" \
  -H "x-api-key: YOUR_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "toolkit": "gmail"
  }'
```

**Response:**
```json
{
  "connected_account_id": "conn_123",
  "link_token": "lk_abc123",
  "redirect_url": "https://connect.composio.dev/link/lk_abc123"
}
```

---

## Response Models

### ToolRouterSession
```swift
struct ToolRouterSession: Codable, Sendable {
    let sessionId: String
    let mcp: ToolRouterMcp?
    let toolRouterTools: [String]?
}

struct ToolRouterMcp: Codable, Sendable {
    let type: String?
    let url: String
    let headers: [String: String]?
}
```

### ToolRouterExecuteResponse
```swift
struct ToolRouterExecuteResponse: Codable, Sendable {
    let data: [String: AnyCodable]
    let error: String?
    let logId: String
}
```

### ToolRouterLinkResponse
```swift
struct ToolRouterLinkResponse: Codable, Sendable {
    let connectedAccountId: String
    let linkToken: String
    let redirectUrl: String

    enum CodingKeys: String, CodingKey {
        case connectedAccountId = "connected_account_id"
        case linkToken = "link_token"
        case redirectUrl = "redirect_url"
    }
}
```

### ConnectedAccount
```swift
struct ConnectedAccount: Codable, Sendable {
    let id: String
    let userId: String
    let status: AccountStatus
    let createdAt: Date?
    let updatedAt: Date?
    let toolkit: String
}

enum AccountStatus: String, Codable {
    case active = "active"
    case inactive = "inactive"
    case expired = "expired"
    case pending = "pending"
    case initiated = "initiated"
    case failed = "failed"
}
```

---

## Error Handling

```swift
enum ComposioError: Error {
    case missingAPIKey
    case invalidConfiguration(String)
    case networkError(Error)
    case invalidResponse(String)
    case notAuthenticated(toolkit: String)
    case rateLimited(retryAfter: Int?)
    case serverError(statusCode: Int, message: String?)
    case decodingError(Error)
    case authenticationCancelled
}

// Usage
do {
    let result = try await composio.toolRouter.execute(...)
} catch ComposioError.notAuthenticated(let toolkit) {
    // Show "Connect \(toolkit)" button
} catch ComposioError.rateLimited(let retryAfter) {
    try await Task.sleep(for: .seconds(retryAfter ?? 5))
    // Retry
}
```

---

## Meta-Tools

### COMPOSIO_SEARCH_TOOLS
**Purpose:** Find tools for a use case and get execution guidance

**Arguments:**
```json
{
  "queries": [
    {
      "use_case": "send an email via gmail"
    }
  ],
  "session_id": "load" // Required after first call
}
```

**Response Fields:**
- `execution_guidance`: Step-by-step instructions
- `recommended_plan_steps`: Ordered list of tool calls
- `primary_tool_slugs`: Main tools to use
- `related_tool_slugs`: Alternative tools
- `toolkit_connection_statuses`: Connection status per toolkit
- `session.id`: Session ID for subsequent calls

### COMPOSIO_MANAGE_CONNECTIONS
**Purpose:** Initiate OAuth connections for missing toolkits

**Arguments:**
```json
{
  "toolkits": ["gmail", "slack"],
  "session_id": "load"
}
```

**Response:**
```json
{
  "data": {
    "message": "All connections have been initiated",
    "results": {
      "gmail": {
        "toolkit": "gmail",
        "status": "initiated",
        "redirect_url": "https://connect.composio.dev/link/lk_...",
        "instruction": "Share the following authentication link..."
      }
    }
  }
}
```

---

## Custom LLM Endpoint

**Base URL:** `http://143.198.174.251:8317`  
**API Key:** `anything` (any value accepted)  
**Verified:** ✅ Working

### Available Models

```bash
curl -X GET "http://143.198.174.251:8317/v1/models" \
  -H "Authorization: Bearer anything"
```

**Selected Models:**
- `gemini-2.5-flash` ✅ Tested
- `gemini-2.5-pro`
- `gemini-claude-sonnet-4-5`
- `gpt-5.1`
- `gpt-5.1-codex`
- `claude-sonnet-4.5`

### Chat Completions

```bash
curl -X POST "http://143.198.174.251:8317/v1/chat/completions" \
  -H "Authorization: Bearer anything" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gemini-2.5-flash",
    "messages": [
      {
        "role": "user",
        "content": "Hello"
      }
    ],
    "temperature": 0.7
  }'
```

**Response:**
```json
{
  "id": "ZhJzaYL3LLGLl7oPk5XNuAs",
  "object": "chat.completion",
  "created": 1769149030,
  "model": "gemini-2.5-flash",
  "choices": [{
    "index": 0,
    "message": {
      "role": "assistant",
      "content": "Hello there!",
      "tool_calls": null
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

---

## Verification Status

| Component | Status | Last Checked |
|-----------|--------|--------------|
| Composio API Keys | ✅ All 3 working | 2026-01-23 |
| Custom LLM Endpoint | ✅ Working | 2026-01-23 |
| GET /apps | ✅ Returns 500+ apps | 2026-01-23 |
| GET /connectedAccounts | ✅ Returns connections | 2026-01-23 |
| POST /chat/completions | ✅ Streaming works | 2026-01-23 |
| GET /models | ✅ 35+ models available | 2026-01-23 |

---

## Integration Notes

1. **Session Caching:** Cache sessions for 1 hour to reduce API calls
2. **Tool Name Sanitization:** Replace `:` with `_` for OpenAI compatibility
3. **Memory Injection:** Pass `memory` dict to `COMPOSIO_MULTI_EXECUTE_TOOL`
4. **OAuth Callback:** Use `rube://oauth-callback` (configured in Info.plist)
5. **Error Recovery:** Implement retry logic for rate limits and network errors
