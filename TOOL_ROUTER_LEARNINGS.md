# Tool Router Implementation Learnings

**Date**: January 27, 2026 | **Source**: Analysis of open-rube codebase + Composio documentation
**Purpose**: Document key learnings, patterns, and architectural insights for implementing Composio Tool Router in production applications

---

## 📌 Executive Summary

Tool Router is Composio's unified interface for AI agents to **search**, **plan**, **authenticate**, and **execute** actions across 1000+ tools. The open-rube implementation (Next.js/React) demonstrates production-grade patterns for integrating Tool Router, specifically handling:

1. **Session-based architecture** for user/conversation isolation
2. **Multi-layer authentication** (user auth + app connections)
3. **Streaming-first design** for real-time feedback
4. **Custom input handling** for complex OAuth flows
5. **Error recovery** with graceful degradation

This document captures patterns applicable to Rube-iOS and other Tool Router implementations.

---

## 🎯 Core Concepts

### What is Tool Router?

Tool Router solves the challenge of building AI agents that work across hundreds of apps:

| Challenge | Solution |
|-----------|----------|
| Finding right tool for task | **Meta-tool**: `COMPOSIO_SEARCH_TOOLS` discovers relevant tools |
| Managing context with large responses | **Workbench**: Processes results without flooding LLM context |
| Handling auth across apps | **In-chat auth**: Users connect accounts during conversation |
| Scaling to 1000+ tools | **Unified interface**: Single tool exposes all Composio tools |

### Two Integration Modes

**1. MCP Mode (Model Context Protocol)**
- Runs as HTTP server exposing standard MCP interface
- LLM calls tool definitions via MCP
- Startup: 2-5 seconds
- Best for: Chat apps with UI control over authentication

**2. Native Tool Mode**
- Single native tool in agent's tool list
- Internal search and execution
- Startup: ~1 second
- Best for: Performance-critical applications

---

## 🏗️ Architecture Patterns from open-rube

### 1. Session-Based Architecture

**Pattern**: Per-user, per-conversation MCP sessions cached in memory

```typescript
// Session cache structure
const sessionCache = new Map<string, MCPSessionCache>();
const sessionKey = `${user.id}-${currentConversationId}`;

// Session creation with Tool Router
const mcpSession = await composio.experimental.toolRouter.createSession(
  userEmail,
  {
    toolkits: [] // Empty allows all available tools
  }
);
```

**Key Insights**:
- Sessions are **ephemeral** - tied to conversation lifecycle
- Scoped by **user email** - ensures credential isolation
- Empty `toolkits: []` enables dynamic discovery of all 1000+ tools
- Cached in memory for performance (reuse across tool calls)

**Benefits**:
- ✅ Efficient resource usage
- ✅ Conversation isolation
- ✅ User data privacy
- ✅ Easy credential management per session

### 2. Multi-Layer Authentication

**Architecture**:
```
┌────────────────────────────────────────┐
│ User Authentication (Supabase OAuth)   │
│ • Google login                          │
│ • Session management                    │
└────────────────────────────────────────┘
              ↓
┌────────────────────────────────────────┐
│ App Connection Auth (Composio)          │
│ • Per-user app OAuth                    │
│ • Connection status tracking            │
│ • Credential management                 │
└────────────────────────────────────────┘
              ↓
┌────────────────────────────────────────┐
│ Tool-Level Authorization                │
│ • MCP session scoped to user            │
│ • Tools filtered by connected apps      │
└────────────────────────────────────────┘
```

**Connection Flow**:
1. User clicks "Connect" app button
2. API generates OAuth Connect Link via `session.authorize("github")`
3. Hosted page handles OAuth flow
4. Connection stored with connected account metadata
5. Tools become available in chat

**Code Pattern**:
```typescript
// Generate auth link
const connection_request = session.authorize("github");
print(connection_request.redirect_url);
// https://connect.composio.dev/link/ln_abc123

// User authenticates, then can use GitHub tools
```

### 3. Streaming-First Design

**Implementation Pattern**:

```typescript
// Main chat endpoint streams tool execution
const stream = await streamText({
  model: client,
  system: systemPrompt,
  messages: conversationHistory,
  tools: toolDefinitions, // From MCP session

  // Real-time tool execution
  onStepStart: async (step) => {
    send('tool-input-start', { toolName: step.toolName });
  },

  onStepFinish: async (step) => {
    send('tool-input-available', { result: step.result });
  },
});

// Stream response to client as it arrives
for await (const chunk of stream.stream) {
  res.write(`data: ${JSON.stringify(chunk)}\n\n`);
}
```

**Benefits**:
- Users see real-time feedback as tools execute
- Non-blocking UI experience
- Progressive updates displayed immediately
- No waiting for all tools to complete

### 4. Custom Input Handling for Complex OAuth

**Problem**: Some OAuth flows require additional user input (e.g., GitHub App selection)

**Solution**: Custom `REQUEST_USER_INPUT` meta-tool

```typescript
// Define custom input tool
REQUEST_USER_INPUT: tool({
  description: 'Request custom input fields BEFORE starting OAuth',
  inputSchema: z.object({
    provider: z.string(),
    fields: z.array(z.object({
      name: z.string(),
      label: z.string(),
      type: z.string().optional(),      // 'text', 'select', etc.
      required: z.boolean().optional(),
      placeholder: z.string().optional()
    }))
  })
}),

// When AI calls this tool:
// 1. Open modal with custom fields
// 2. Collect user input
// 3. Pass to auth endpoint
// 4. Generate OAuth link with parameters
```

**Key Insight**: Composio's Tool Router handles standard OAuth, but complex flows need custom handling via meta-tool integration.

### 5. Error Recovery Patterns

**Three-Layer Error Handling**:

```typescript
// Layer 1: Automatic retry for transient failures
const result = await executeToolWithRetry(
  tool,
  { maxRetries: 3, backoff: 'exponential' }
);

// Layer 2: User input collection for auth failures
if (error.type === 'NOT_AUTHENTICATED') {
  const link = await session.authorize(error.toolkit);
  await collectUserConfirmation(link);
  return executeToolWithRetry(tool); // Retry after auth
}

// Layer 3: Graceful degradation
if (error.type === 'TOOL_NOT_AVAILABLE') {
  return {
    status: 'unavailable',
    reason: 'Tool requires connection',
    suggestions: ['Connect account', 'Try different tool']
  };
}
```

---

## 🔐 Authentication Patterns

### In-Chat Authentication (Recommended for Chat Apps)

**Flow**:
1. Agent receives user task requiring tool (e.g., "Read my emails")
2. `COMPOSIO_MANAGE_CONNECTIONS` meta-tool checks connection status
3. If not connected, returns Connect Link URL
4. User clicks link, completes OAuth in browser
5. User returns to chat, confirms connection
6. Agent retries tool with authenticated connection

**Configuration**:
```python
# By default, in-chat auth is enabled
session = composio.create(user_id="user_123")

# Customize callback URL
session = composio.create(
    user_id="user_123",
    manage_connections={
        "callback_url": "https://yourapp.com/chat"
    }
)
```

**User Experience**:
```
You: Summarize my GitHub issues
Agent: I need to connect GitHub first.
       Please authorize: https://connect.composio.dev/link/ln_abc123
You: Done
Agent: Connected! Here's your summary: [...]
```

### Manual Authentication (For Custom UX)

Use when you want to manage connections outside the chat (e.g., settings page):

```python
# Generate link programmatically
connection_request = session.authorize("github")
# Returns: { redirect_url: "https://connect.composio.dev/link/..." }

# Use in your UI
# → Show in settings page
# → Redirect after OAuth completion
```

### Auth Config Management

**How Tool Router manages auth configs**:
1. Uses your custom `authConfigs` override if provided
2. Otherwise reuses auth config previously created for toolkit
3. If none exists, creates one using Composio managed auth

**Key Insight**: You rarely need to create auth configs manually - Tool Router handles it automatically.

### Supported Auth Methods

- **Composio Managed OAuth**: GitHub, Gmail, Slack, Notion, and 90%+ of toolkits
- **API Key Auth**: Users enter own keys via Connect Link
- **Custom Auth**: For toolkits without Composio managed auth (requires custom config)

---

## 🔧 Tool Discovery, Selection, and Execution

### Tool Discovery Meta-Tool

**`COMPOSIO_SEARCH_TOOLS`** - Automatically searches for relevant tools

```typescript
// Agent can call this to find tools
const tools = await COMPOSIO_SEARCH_TOOLS({
  query: "Read emails",
  limit: 5
});

// Returns most relevant tools for task:
// [
//   { id: "gmail_read_email", toolkit: "gmail" },
//   { id: "outlook_read_email", toolkit: "outlook" },
//   ...
// ]
```

**Smart Ranking**:
- Filters by user's connected apps
- Ranks by relevance to query
- Returns top N results to avoid overwhelming LLM

### Tool Execution Flow

```
User Input: "Star the composio repo"
       ↓
Search Tools: Find relevant GitHub tools
       ↓
Check Auth: Verify GitHub connection exists
       ↓
No Connection? → Return Connect Link
       ↓
Wait for User Confirmation
       ↓
Execute Tool: star_repository(owner="composio", repo="composio-py")
       ↓
Stream Result: "Successfully starred 🌟"
```

### Parallel vs Sequential Execution

**Parallel**: Independent tools run simultaneously
```
Task: "Get GitHub issues AND Notion projects"
     → Run both in parallel
     → Aggregate results
     → Return faster
```

**Sequential**: Tools with dependencies
```
Task: "Get GitHub issues AND create Notion page with those issues"
     → Step 1: Fetch GitHub issues
     → Step 2: Create Notion page with fetched data
     → Execute sequentially
```

**Pattern**: LLM decides parallelization via natural orchestration

---

## 📊 Data Models and Integration

### Key Data Models

**1. Session**
```typescript
interface Session {
  user_id: string;           // Unique user identifier
  conversation_id: string;   // For multi-conversation support
  mcp: {
    url: string;            // MCP server endpoint
    headers: Record<string, string>; // Auth headers
  };
  connected_accounts: Account[];  // User's OAuth connections
}
```

**2. Connected Account**
```typescript
interface ConnectedAccount {
  id: string;
  user_id: string;
  toolkit: string;          // e.g., "github", "gmail"
  account_id: string;       // Unique ID in that service
  status: "active" | "expired" | "error";
  created_at: Date;
  last_used: Date;
}
```

**3. Tool Call**
```typescript
interface ToolCall {
  id: string;
  tool_name: string;        // e.g., "github_star_repository"
  toolkit: string;          // e.g., "github"
  input: Record<string, any>;
  output: Record<string, any>;
  status: "pending" | "running" | "success" | "error";
  duration_ms: number;
  error?: string;
}
```

### Database Optimization in open-rube

```typescript
// Efficient storage pattern
const messages = await db.query(
  `SELECT * FROM messages
   WHERE conversation_id = $1
   ORDER BY created_at DESC
   LIMIT 50`,
  [conversationId]
);

// Indexed queries for fast retrieval
CREATE INDEX idx_messages_conversation_created ON messages(conversation_id, created_at DESC);
CREATE INDEX idx_connected_accounts_user ON connected_accounts(user_id);
CREATE INDEX idx_conversation_user ON conversations(user_id);
```

---

## 🚀 Production Patterns and Best Practices

### 1. Session Caching for Performance

**Pattern**: Cache MCP sessions in memory with TTL

```typescript
class SessionCache {
  private cache = new Map<string, { session, expiresAt }>();

  async getOrCreate(userId: string, conversationId: string) {
    const key = `${userId}-${conversationId}`;
    const cached = this.cache.get(key);

    if (cached && cached.expiresAt > Date.now()) {
      return cached.session; // Reuse
    }

    // Create new session
    const session = await composio.create(userId);
    this.cache.set(key, {
      session,
      expiresAt: Date.now() + 30 * 60 * 1000 // 30 min TTL
    });

    return session;
  }
}
```

**Benefits**:
- ✅ Reduces session creation latency (saves 1-2 seconds per request)
- ✅ Reuses tool definitions across calls
- ✅ TTL prevents memory leaks

### 2. Streaming for Better UX

**Pattern**: Use SSE (Server-Sent Events) for real-time updates

```typescript
res.setHeader('Content-Type', 'text/event-stream');
res.setHeader('Cache-Control', 'no-cache');

// Stream each phase
send('tool-input-start', { tool: 'gmail_read_email' });
send('tool-running', { status: 'fetching emails...' });
send('tool-input-available', { result: [...emails] });
send('tool-completed', { status: 'success' });
```

**Key Insight**: Streaming Tool Router responses is essential for chat UX - users see progress, not frozen screens.

### 3. Error Boundaries and Fallbacks

**Pattern**: Isolated error handling per tool

```typescript
const results = await Promise.allSettled(
  tools.map(tool => executeTool(tool))
);

results.forEach((result, index) => {
  if (result.status === 'rejected') {
    // Log error, continue with other tools
    logError(tools[index].name, result.reason);

    // Provide fallback to user
    sendMessage(`Could not ${tools[index].description}: ${result.reason}`);
  }
});
```

**Benefit**: One tool failure doesn't crash entire operation

### 4. Type Safety Throughout

**Pattern**: Use TypeScript with strict types for tool execution

```typescript
type ToolResult =
  | { success: true; data: unknown; duration: number }
  | { success: false; error: string; toolkit: string };

interface ToolExecution {
  tool_id: string;
  toolkit: string;
  result: ToolResult;
  timestamp: Date;
}

// Strongly typed tool schema
const toolSchema = z.object({
  name: z.string(),
  description: z.string(),
  inputSchema: z.record(z.any()),
  execute: z.function()
});
```

### 5. Security-First Implementation

**Authentication**:
- ✅ User authentication via OAuth (Supabase)
- ✅ Tool credentials encrypted at rest
- ✅ HTTPS for all API calls
- ✅ Session scoped to user email

**Input Validation**:
- ✅ Validate all tool parameters
- ✅ Sanitize user input before tool execution
- ✅ Check user has permission for tool

**Credential Management**:
- ✅ Never log credentials
- ✅ Tokens stored securely (Supabase Vault recommended)
- ✅ Automatic token refresh
- ✅ Implement token rotation

---

## 🎓 Key Learnings & Insights

### 1. Session Scoping is Critical

**Why**: Sessions isolate user data and credentials
- Without proper scoping, user A could access user B's tools
- Session key must include both user_id AND conversation_id
- MCP session created per user prevents cross-user tool access

**Action for Rube-iOS**:
- Scope ComposioManager sessions to user + conversation ID
- Implement session cleanup on logout
- Cache with TTL to prevent stale credentials

### 2. In-Chat Auth is Superior UX

**Why**: Users don't want to leave chat to connect apps
- Traditional flow: Settings → Connect App → Return to chat (friction)
- In-chat auth: Chat → Prompt → OAuth → Resume (seamless)
- Conversion rate significantly higher with in-chat auth

**How Tool Router enables this**:
- `COMPOSIO_MANAGE_CONNECTIONS` meta-tool detects missing auth
- Returns user-friendly Connect Link
- Agent can ask for confirmation without breaking flow

**Action for Rube-iOS**:
- Implement in-app OAuth flows (ASWebAuthenticationSession)
- Display auth prompts inline during chat
- Handle OAuth callbacks to resume tool execution

### 3. Workbench Solves Context Flooding

**Problem**: Large tool results (e.g., 100 emails, 500 files) flood LLM context window
**Solution**: Tool Router's Workbench
- Processes results server-side
- Returns summarized/filtered output to LLM
- Allows handling massive datasets without context issues

**Action for Rube-iOS**:
- Monitor tool response sizes
- Consider Workbench for large result sets
- Test with 100+ item responses to verify context usage

### 4. Dynamic Tool Discovery > Static Tool Lists

**Why**: User's needs change per conversation
- "Help me with email" → Show Gmail tools
- Next turn: "Now help with Slack" → Show Slack tools
- Static lists would show 1000+ tools (overwhelming)

**How Tool Router solves it**:
- `COMPOSIO_SEARCH_TOOLS` finds relevant tools per request
- LLM receives only relevant 3-5 tools
- Reduces context used by tools, improves relevance

**Action for Rube-iOS**:
- Don't pre-load all tools on startup
- Rely on Tool Router's search for each request
- Trust LLM to select appropriate tools

### 5. Error Recovery Requires User Involvement

**Pattern from open-rube**:
1. Tool fails → Show error to user
2. If auth failure → Provide Connect Link
3. If parameter issue → Ask for clarification
4. Never silently fail or retry forever

**Action for Rube-iOS**:
- Show tool errors in chat clearly
- Provide actionable next steps
- Retry only for transient errors (network, timeout)
- Ask user for input on auth/parameter errors

### 6. Monitoring Tool Execution is Essential

**What to track**:
- Tool name and toolkit
- Input parameters (sanitized)
- Execution duration
- Success/failure status
- Error messages and types

**Why**:
- Identify slow tools (performance)
- Track failed authentications (user support)
- Find unused tools (optimization)
- Detect abuse patterns (security)

**Action for Rube-iOS**:
- Log all tool executions (start, end, result)
- Implement metrics dashboard
- Alert on high error rates
- Sample logs for debugging

---

## 📋 Implementation Checklist for Rube-iOS

Based on open-rube patterns, here's what Tool Router needs in iOS:

### Authentication & Session Management
- [ ] User authentication via Appwrite OAuth
- [ ] Session creation per user + conversation
- [ ] Session caching in memory with TTL
- [ ] Clean up sessions on logout
- [ ] Implement connection status tracking

### In-Chat Authentication
- [ ] Detect when tool requires authentication
- [ ] Generate OAuth Connect Link via `session.authorize()`
- [ ] Handle OAuth callback in app
- [ ] Resume tool execution after auth
- [ ] Show user-friendly auth prompts

### Tool Discovery & Execution
- [ ] Implement tool search meta-tool interface
- [ ] Stream tool execution in real-time
- [ ] Handle parallel tool execution
- [ ] Implement sequential workflows
- [ ] Show tool execution status to user

### Error Handling
- [ ] Detect auth failures, network errors, parameter errors
- [ ] Provide user-friendly error messages
- [ ] Implement retry logic for transient errors
- [ ] Ask user for input on recoverable errors
- [ ] Never crash on tool execution failures

### Monitoring & Observability
- [ ] Log all tool executions (start, end, result)
- [ ] Track tool latency and success rates
- [ ] Monitor error patterns
- [ ] Alert on failures
- [ ] Implement analytics for tool usage

### Security
- [ ] Validate all tool inputs
- [ ] Never log sensitive data (credentials, tokens)
- [ ] Use HTTPS for all API calls
- [ ] Implement certificate pinning
- [ ] Store credentials securely (Keychain)
- [ ] Rotate tokens periodically

---

## 🔗 Key References

### Composio Documentation
- [Tool Router Overview](https://docs.composio.dev/tool-router/overview)
- [Quickstart Guides](https://docs.composio.dev/tool-router/quickstart)
- [In-Chat Authentication](https://docs.composio.dev/tool-router/using-in-chat-authentication)
- [Native Tool Mode](https://docs.composio.dev/tool-router/using-as-a-native-tool)

### open-rube Implementation Files
- `/app/api/chat/route.ts` - Session management and tool execution
- `/app/api/authLinks/route.ts` - OAuth link generation
- `/app/components/ChatContainer.tsx` - Streaming UI
- `/app/utils/composio.ts` - Composio client configuration
- `/app/utils/supabase/` - Database operations

### Swift/iOS Specific
- See CLAUDE.md for Rube-iOS architecture
- Services/ComposioManager.swift - Tool Router wrapper (in progress)
- Services/OAuthService.swift - OAuth flow handling (in progress)

---

## 💡 Future Optimization Opportunities

1. **Native Tool Mode Migration** (1s startup vs 2-5s MCP)
2. **Tool Result Caching** (skip re-fetching frequently accessed tools)
3. **Workbench Integration** (for large result sets)
4. **Tool Router Offline Mode** (cache common tools locally)
5. **Custom Auth Configs** (white-label OAuth for premium features)
6. **Tool Versioning** (pin tool versions for consistency)

---

**Document Version**: 1.0 | **Last Updated**: January 27, 2026
**Status**: 🟢 Complete & Actionable
**Next Review**: After Rube-iOS Tool Router integration (4 weeks)
