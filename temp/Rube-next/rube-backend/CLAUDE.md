# Rube Backend - Claude Code Context

**Last Updated:** January 26, 2026
**Project Version:** 0.1.0
**Framework:** Next.js 15.5.7 (App Router)

---

## Quick Start for AI Assistants

This is a **Next.js backend API** for an iOS mobile app that provides AI chat capabilities with 500+ app integrations. When working on this codebase, prioritize understanding the authentication flow, session management, and tool integration patterns.

### Critical Files to Read First

1. **[app/api/chat/route.ts](./app/api/chat/route.ts)** (314 lines) - Main chat endpoint with streaming
2. **[app/utils/appwrite/token-auth.ts](./app/utils/appwrite/token-auth.ts)** (66 lines) - JWT authentication
3. **[app/utils/chat-history-appwrite.ts](./app/utils/chat-history-appwrite.ts)** (319 lines) - Database operations
4. **[app/utils/composio.ts](./app/utils/composio.ts)** - Composio MCP Tool Router integration
5. **[ARCHITECTURE.md](./ARCHITECTURE.md)** - Complete architectural documentation

---

## Architecture Overview

```
┌─────────────┐
│  iOS Client │
└──────┬──────┘
       │ JWT Bearer Token
       ▼
┌─────────────────────────────────────────┐
│         Next.js API Routes              │
│  ┌────────────────────────────────┐    │
│  │  Middleware (CORS + Auth)      │    │
│  └────────────┬───────────────────┘    │
│               ▼                         │
│  ┌────────────────────────────────┐    │
│  │  POST /api/chat                │    │
│  │  - Validate JWT with Appwrite  │    │
│  │  - Load/cache Composio tools   │    │
│  │  - Stream AI responses (SSE)   │    │
│  └────┬───────────────────┬───────┘    │
│       │                   │             │
│       ▼                   ▼             │
│  ┌─────────┐      ┌──────────────┐    │
│  │Appwrite │      │Custom OpenAI │    │
│  │  Cloud  │      │     API      │    │
│  └─────────┘      └──────┬───────┘    │
│                           │             │
│                           ▼             │
│                   ┌──────────────┐    │
│                   │ Composio MCP │    │
│                   │ Tool Router  │    │
│                   │ (500+ apps)  │    │
│                   └──────────────┘    │
└─────────────────────────────────────────┘
```

---

## Key Technical Decisions

### 1. Authentication Strategy

**JWT-based stateless authentication** using Appwrite tokens:

```typescript
// app/utils/appwrite/token-auth.ts:15-40
export async function getUserFromToken(request: NextRequest) {
  const authHeader = request.headers.get('Authorization');

  if (!authHeader?.startsWith('Bearer ')) {
    return { user: null, error: 'Invalid Authorization format' };
  }

  const token = authHeader.slice(7);

  try {
    const client = new Client()
      .setEndpoint(process.env.NEXT_PUBLIC_APPWRITE_ENDPOINT!)
      .setProject(process.env.NEXT_PUBLIC_APPWRITE_PROJECT!)
      .setJWT(token);

    const account = new Account(client);
    const user = await account.get();

    return {
      user: { id: user.$id, email: user.email, name: user.name },
      error: null
    };
  } catch (error) {
    return { user: null, error: 'Invalid or expired token' };
  }
}
```

**Why this matters:**
- Every API request must include `Authorization: Bearer <jwt_token>`
- No server-side session management needed
- Tokens validated directly with Appwrite Cloud
- iOS client handles token refresh

### 2. Session Caching Pattern

**Per-user, per-conversation tool caching** with 1-hour TTL:

```typescript
// app/api/chat/route.ts:143-226
const SESSION_TTL = 3600000; // 1 hour
const sessionCache = new Map<string, { tools: ToolsRecord; createdAt: number }>();

const sessionKey = `${auth.user.id}-${currentConversationId}`;
let tools: ToolsRecord;

const cached = sessionCache.get(sessionKey);
const now = Date.now();

if (cached && (now - cached.createdAt < SESSION_TTL)) {
  logger.debug('Reusing existing Composio session', { sessionKey });
  tools = cached.tools;
} else {
  logger.info('Creating new MCP session', { sessionKey });
  const composio = getComposio();
  const session = await composio.create(auth.user.id);
  const composioTools = await session.tools();

  // Add custom REQUEST_USER_INPUT tool
  tools = {
    ...composioTools,
    REQUEST_USER_INPUT: tool({...})
  };

  sessionCache.set(sessionKey, { tools, createdAt: Date.now() });
}
```

**Why this matters:**
- Avoids creating new Composio sessions on every request
- Tools persist for entire conversation
- Reduces latency and API overhead
- Automatic cleanup after 1 hour

### 3. Streaming Response Architecture

**Server-Sent Events (SSE)** for real-time AI responses:

```typescript
// app/api/chat/route.ts:238-270
const result = streamText({
  model: customModel(currentModel),
  messages: conversationMessages,
  tools,
  system: SYSTEM_PROMPT,
  maxSteps: 10,
  onStepFinish: async (step) => {
    if (step.stepType === 'done') {
      await addMessage(
        currentConversationId,
        step.request.messages,
        step.response
      );
    }
  },
});

return result.toDataStreamResponse({
  headers: {
    'X-Conversation-Id': currentConversationId,
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Expose-Headers': 'X-Conversation-Id',
  },
});
```

**Why this matters:**
- iOS client receives tokens as they're generated
- Better UX with progressive display
- `X-Conversation-Id` header allows client to track conversations
- Automatic message persistence via `onStepFinish`

### 4. Graceful Degradation

**Database operations fail gracefully** when Appwrite is unavailable:

```typescript
// app/utils/chat-history-appwrite.ts:40-55
export async function createConversation(userId: string, title?: string): Promise<string | null> {
  try {
    const client = getAppwriteClient();
    const databases = new Databases(client);

    const response = await databases.createDocument(
      DATABASE_ID,
      CONVERSATIONS_COLLECTION_ID,
      ID.unique(),
      { user_id: userId, title: title || null },
      [
        Permission.read(Role.user(userId)),
        Permission.update(Role.user(userId)),
        Permission.delete(Role.user(userId))
      ]
    );

    return response.$id;
  } catch (error: unknown) {
    const appwriteError = error as { code?: number };
    if (appwriteError.code === 404) {
      console.warn('⚠️  Database not set up. Run: npm run setup-db');
      return `temp-${Date.now()}`; // Temporary ID for development
    }
    return null;
  }
}
```

**Why this matters:**
- Backend continues functioning without database
- Development workflow doesn't require immediate database setup
- Clear warnings guide developers to setup process
- Production failures don't crash the entire API

---

## Data Flow: Chat Request Lifecycle

```
1. iOS Client Sends Request
   POST /api/chat
   Headers: Authorization: Bearer <jwt>, X-Conversation-Id: <id>
   Body: { messages: [...] }

2. Middleware Processes Request
   └─→ middleware.ts:13-47
       ├─ Handle OPTIONS (CORS preflight)
       ├─ Add CORS headers
       └─ Pass to route handler

3. Authentication
   └─→ token-auth.ts:15-40
       ├─ Extract JWT from Bearer token
       ├─ Validate with Appwrite Cloud
       └─ Return user object { id, email, name }

4. Conversation Management
   └─→ chat/route.ts:95-140
       ├─ Check X-Conversation-Id header
       ├─ Verify conversation belongs to user
       ├─ Create new conversation if needed
       └─ Load conversation history from Appwrite

5. Session & Tool Loading
   └─→ chat/route.ts:143-226
       ├─ Generate session key: userId-conversationId
       ├─ Check session cache (1-hour TTL)
       ├─ If cached: Reuse tools
       └─ If new: Create Composio session → Load 500+ tools
           └─ Add custom REQUEST_USER_INPUT tool

6. Model Discovery
   └─→ chat/route.ts:65-82
       ├─ Fetch available models from custom API
       ├─ Find requested model or default
       └─ Create customModel instance

7. AI Streaming
   └─→ chat/route.ts:238-270
       ├─ Call streamText with model, messages, tools
       ├─ Stream tokens via SSE
       ├─ Execute tool calls as needed
       └─ onStepFinish: Save to Appwrite

8. Response to Client
   └─→ Headers: X-Conversation-Id
       └─→ Body: SSE stream with tokens, tool results
```

---

## Database Schema (Appwrite Cloud)

### Collections

#### 1. `conversations` Collection
```typescript
{
  $id: string;              // Auto-generated unique ID
  user_id: string;          // FK to Appwrite users.$id
  title: string | null;     // Optional conversation title
  $createdAt: string;       // ISO timestamp
  $updatedAt: string;       // ISO timestamp
  $permissions: [           // Per-document permissions
    "read(\"user:{userId}\")",
    "update(\"user:{userId}\")",
    "delete(\"user:{userId}\")"
  ]
}
```

**Indexes:**
- `user_id` (key, ascending) - Required for getUserConversations query

#### 2. `messages` Collection
```typescript
{
  $id: string;                    // Auto-generated unique ID
  conversation_id: string;        // FK to conversations.$id
  content: object;                // Full message object { role, content, toolInvocations }
  created_at: number;             // Unix timestamp (milliseconds)
  $createdAt: string;             // ISO timestamp
  $updatedAt: string;             // ISO timestamp
  $permissions: [                 // Inherited from conversation
    "read(\"user:{userId}\")"
  ]
}
```

**Indexes:**
- `conversation_id` (key, ascending) - Required for message queries
- `created_at` (key, ascending) - For chronological ordering

**Setup:**
```bash
npm run setup-db    # Creates collections and indexes
npm run verify-db   # Verifies schema matches requirements
```

---

## Environment Variables

### Required Variables

```bash
# Appwrite Configuration (Production: Appwrite Cloud)
NEXT_PUBLIC_APPWRITE_ENDPOINT="https://nyc.cloud.appwrite.io/v1"
NEXT_PUBLIC_APPWRITE_PROJECT="6961fcac000432c6a72a"
APPWRITE_API_KEY="standard_8512c544d7fba36f..."  # Admin API key for database ops

# Composio MCP Tool Router
COMPOSIO_API_KEY="your-composio-api-key"

# Custom OpenAI-Compatible API (for model discovery)
CUSTOM_OPENAI_API_BASE_URL="https://your-api-endpoint.com/v1"
CUSTOM_OPENAI_API_KEY="your-api-key"

# Development
NODE_ENV="development" | "production"
```

### Optional Variables

```bash
# Logging
LOG_LEVEL="debug" | "info" | "warn" | "error"  # Default: "info"

# Server Configuration
PORT="3000"  # Default: 3000
```

**Security Notes:**
- `.env.local` is gitignored - never commit API keys
- Use separate Appwrite projects for dev/staging/production
- Rotate `APPWRITE_API_KEY` regularly (has admin privileges)

---

## API Reference

### POST /api/chat

**Main AI chat endpoint with streaming responses**

**Headers:**
```
Authorization: Bearer <jwt_token>    [REQUIRED]
X-Conversation-Id: <conversation_id> [OPTIONAL - creates new if missing]
Content-Type: application/json
```

**Request Body:**
```typescript
{
  messages: Array<{
    role: "user" | "assistant" | "system";
    content: string;
    toolInvocations?: Array<{
      toolCallId: string;
      toolName: string;
      args: Record<string, unknown>;
      result?: unknown;
    }>;
  }>;
  model?: string;  // Optional - defaults to first available model
}
```

**Response:**
```
Status: 200 OK
Content-Type: text/event-stream
X-Conversation-Id: <conversation_id>

# SSE Stream Format:
0:{"type":"text","textDelta":"Hello"}
0:{"type":"text","textDelta":" world"}
0:{"type":"tool-call","toolCallId":"call_123","toolName":"GITHUB_SEARCH"}
...
```

**Error Responses:**
- `401 Unauthorized` - Missing or invalid JWT token
- `403 Forbidden` - Conversation doesn't belong to user
- `500 Internal Server Error` - Database or API failure

**Code Location:** [app/api/chat/route.ts:85-313](./app/api/chat/route.ts#L85-L313)

### GET /api/conversations

**List all conversations for authenticated user**

**Headers:**
```
Authorization: Bearer <jwt_token> [REQUIRED]
```

**Response:**
```typescript
{
  conversations: Array<{
    $id: string;
    user_id: string;
    title: string | null;
    $createdAt: string;
    $updatedAt: string;
  }>;
}
```

**Code Location:** [app/api/conversations/route.ts](./app/api/conversations/route.ts)

### GET /api/conversations/[id]

**Get conversation details with full message history**

**Response:**
```typescript
{
  conversation: {
    $id: string;
    user_id: string;
    title: string | null;
    $createdAt: string;
  };
  messages: Array<{
    $id: string;
    conversation_id: string;
    content: object;
    created_at: number;
  }>;
}
```

**Code Location:** [app/api/conversations/[id]/route.ts](./app/api/conversations/[id]/route.ts)

### DELETE /api/conversations/[id]

**Delete conversation and all its messages**

**Response:**
```typescript
{
  success: true;
  deletedConversation: string;  // Conversation ID
  deletedMessages: number;      // Count of deleted messages
}
```

**Code Location:** [app/api/conversations/[id]/route.ts](./app/api/conversations/[id]/route.ts)

### GET /api/models

**List available AI models from custom OpenAI API**

**Response:**
```typescript
{
  models: Array<{
    id: string;
    name: string;
    provider?: string;
  }>;
}
```

**Code Location:** [app/api/models/route.ts](./app/api/models/route.ts)

---

## Extension Points

### 1. Adding Custom Tools

Add tools alongside Composio tools in the chat endpoint:

```typescript
// app/api/chat/route.ts:180-220
tools = {
  ...composioTools,

  // Your custom tool
  MY_CUSTOM_TOOL: tool({
    description: 'Description for AI to understand when to use this tool',
    inputSchema: z.object({
      param1: z.string().describe('Parameter description'),
      param2: z.number().optional(),
    }),
    execute: async ({ param1, param2 }) => {
      // Tool implementation
      return { result: 'Tool output' };
    }
  }),

  REQUEST_USER_INPUT: tool({...}), // Existing custom tool
};
```

### 2. Adding New API Routes

Follow Next.js App Router conventions:

```typescript
// app/api/your-route/route.ts
import { NextRequest, NextResponse } from 'next/server';
import { getUserFromToken } from '@/app/utils/appwrite/token-auth';

export async function GET(request: NextRequest) {
  // Authenticate
  const auth = await getUserFromToken(request);
  if (!auth.user) {
    return NextResponse.json(
      { error: auth.error },
      { status: 401 }
    );
  }

  // Your logic here
  return NextResponse.json({ data: 'response' });
}
```

**CORS is automatic** via middleware for all `/api/*` routes.

### 3. Customizing the System Prompt

```typescript
// app/api/chat/route.ts:24-59
const SYSTEM_PROMPT = `
Your custom system prompt here.
Guide AI behavior, define personality, set constraints.
`;
```

### 4. Adding Database Collections

```typescript
// scripts/setup-database.js:50-100
const collections = [
  {
    id: 'your_collection',
    name: 'Your Collection',
    permissions: [
      Permission.read(Role.users()),
      Permission.create(Role.users()),
    ],
    attributes: [
      { key: 'field_name', type: 'string', size: 255, required: true },
      { key: 'user_id', type: 'string', size: 255, required: true },
    ],
    indexes: [
      { key: 'user_id_index', type: 'key', attributes: ['user_id'], orders: ['ASC'] },
    ],
  },
];
```

Then run: `npm run setup-db`

### 5. Switching AI Providers

Replace the custom OpenAI API with any provider:

```typescript
// app/api/chat/route.ts:238-270
import { openai } from '@ai-sdk/openai';
import { anthropic } from '@ai-sdk/anthropic';

const result = streamText({
  model: openai('gpt-4'),  // or anthropic('claude-3-opus')
  messages: conversationMessages,
  tools,
  // ...rest
});
```

---

## Common Development Tasks

### 1. Testing Locally

```bash
# Install dependencies
npm install

# Set up environment variables
cp .env.example .env.local
# Edit .env.local with your API keys

# Set up Appwrite database
npm run setup-db

# Run development server
npm run dev

# Test the chat endpoint
curl -X POST http://localhost:3000/api/chat \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"messages":[{"role":"user","content":"Hello"}]}'
```

### 2. Debugging Authentication Issues

```typescript
// app/utils/appwrite/token-auth.ts
// Add console.log statements:

export async function getUserFromToken(request: NextRequest) {
  const authHeader = request.headers.get('Authorization');
  console.log('Auth header:', authHeader); // Debug

  const token = authHeader?.slice(7);
  console.log('Extracted token:', token); // Debug

  // ... rest of function
}
```

Check logs for JWT validation errors.

### 3. Inspecting Session Cache

```typescript
// app/api/chat/route.ts
// Add after line 226:

console.log('Session cache size:', sessionCache.size);
console.log('Cache entries:', Array.from(sessionCache.keys()));
```

Monitor cache growth and TTL behavior.

### 4. Adding Logging

```typescript
// Use the logger utility
import logger from '@/app/utils/logger';

logger.debug('Debug info', { context: 'data' });
logger.info('Info message');
logger.warn('Warning', { userId: 'user-123' });
logger.error('Error occurred', { error: err });
```

**Set log level:**
```bash
LOG_LEVEL=debug npm run dev
```

### 5. Database Migrations

```typescript
// scripts/update-collections.js
// Add new attributes or indexes to existing collections

await databases.createStringAttribute(
  DATABASE_ID,
  COLLECTION_ID,
  'new_field',
  255,
  false // not required
);

await databases.createIndex(
  DATABASE_ID,
  COLLECTION_ID,
  'new_field_index',
  'key',
  ['new_field'],
  ['ASC']
);
```

---

## Troubleshooting

### Issue: "Database not set up" warnings

**Cause:** Appwrite collections don't exist
**Solution:**
```bash
npm run setup-db
npm run verify-db  # Confirm setup
```

### Issue: CORS errors from iOS client

**Cause:** Missing CORS headers
**Check:** [middleware.ts:13-47](./middleware.ts#L13-L47)
**Solution:** Ensure middleware is configured for `/api/*` routes

### Issue: Session cache memory growth

**Cause:** Long-running server with many users
**Solution:** The 1-hour TTL prevents unbounded growth, but consider:
```typescript
// Add periodic cleanup
setInterval(() => {
  const now = Date.now();
  for (const [key, value] of sessionCache.entries()) {
    if (now - value.createdAt >= SESSION_TTL) {
      sessionCache.delete(key);
    }
  }
}, 3600000); // Clean every hour
```

### Issue: Tool calls not working

**Causes:**
1. Composio API key invalid
2. Session cache stale
3. Tool schema mismatch

**Debug:**
```typescript
// app/api/chat/route.ts:226
console.log('Available tools:', Object.keys(tools));
console.log('Tool schemas:', tools);
```

### Issue: Streaming stops mid-response

**Causes:**
1. Model API timeout
2. Vercel deployment timeout (60s limit on Hobby plan)
3. Network interruption

**Solutions:**
- Use shorter `maxSteps` value
- Upgrade Vercel plan for longer timeouts
- Implement retry logic in iOS client

---

## Performance Considerations

### 1. Session Cache Optimization

**Current:** In-memory Map (single process)
**Limitation:** Cache lost on server restart, not shared across instances
**Scaling Solution:**
```typescript
// Replace Map with Redis
import { createClient } from 'redis';

const redis = createClient({ url: process.env.REDIS_URL });

// Get from cache
const cached = await redis.get(sessionKey);
const tools = cached ? JSON.parse(cached) : await createNewSession();

// Set in cache
await redis.setEx(sessionKey, 3600, JSON.stringify(tools));
```

### 2. Database Query Optimization

**Appwrite indexes are critical:**
- `user_id` index on conversations (prevents full scan)
- `conversation_id` + `created_at` on messages (efficient chronological queries)

**Monitor query performance:**
```bash
# Appwrite Console → Database → Query Logs
```

### 3. Streaming Response Buffering

**Current:** Immediate token streaming
**Optimization for mobile:**
```typescript
// Buffer tokens to reduce HTTP overhead
let buffer = '';
const BUFFER_SIZE = 10;

onChunk: (chunk) => {
  buffer += chunk;
  if (buffer.length >= BUFFER_SIZE) {
    stream.write(buffer);
    buffer = '';
  }
}
```

### 4. Model Selection Strategy

**Current:** Load all models on every request
**Optimization:**
```typescript
// Cache model list
let modelCache: { models: ModelInfo[], timestamp: number } | null = null;
const MODEL_CACHE_TTL = 600000; // 10 minutes

async function getModels() {
  if (modelCache && Date.now() - modelCache.timestamp < MODEL_CACHE_TTL) {
    return modelCache.models;
  }

  const models = await fetchModelsFromAPI();
  modelCache = { models, timestamp: Date.now() };
  return models;
}
```

---

## Security Considerations

### 1. JWT Validation

**Every protected route must validate:**
```typescript
const auth = await getUserFromToken(request);
if (!auth.user) {
  return NextResponse.json({ error: auth.error }, { status: 401 });
}
```

**Never trust client-provided user IDs** - always use `auth.user.id` from JWT.

### 2. Conversation Ownership

**Always verify conversation belongs to user:**
```typescript
// app/utils/chat-history-appwrite.ts:107-130
const conversation = await databases.getDocument(...);
if (conversation.user_id !== userId) {
  throw new Error('Unauthorized');
}
```

### 3. Appwrite Permissions

**Per-document permissions enforce access control:**
```typescript
[
  Permission.read(Role.user(userId)),    // Only this user can read
  Permission.update(Role.user(userId)),  // Only this user can update
  Permission.delete(Role.user(userId))   // Only this user can delete
]
```

**Critical:** Never use `Permission.read(Role.any())` for user data.

### 4. Environment Variables

**Sensitive data must never be exposed:**
- `APPWRITE_API_KEY` - Admin access to entire database
- `COMPOSIO_API_KEY` - Access to all integrated apps
- `CUSTOM_OPENAI_API_KEY` - API billing credentials

**Use Vercel environment variables** for production (never hardcode).

### 5. Input Validation

**Validate all user inputs:**
```typescript
// Use Zod schemas for type safety
import { z } from 'zod';

const messageSchema = z.object({
  messages: z.array(z.object({
    role: z.enum(['user', 'assistant', 'system']),
    content: z.string().min(1).max(10000),
  })),
  model: z.string().optional(),
});

const body = messageSchema.parse(await request.json());
```

### 6. Rate Limiting

**Not currently implemented** - Add for production:
```typescript
// middleware.ts - Add rate limiting
import { Ratelimit } from '@upstash/ratelimit';
import { Redis } from '@upstash/redis';

const ratelimit = new Ratelimit({
  redis: Redis.fromEnv(),
  limiter: Ratelimit.slidingWindow(10, '1 m'), // 10 requests per minute
});

const { success } = await ratelimit.limit(auth.user.id);
if (!success) {
  return NextResponse.json({ error: 'Rate limit exceeded' }, { status: 429 });
}
```

---

## Migration History

### From Supabase to Appwrite (Completed: January 2026)

**Motivation:**
- Better SDK for mobile development
- Per-document permissions model
- Simpler authentication flow
- Built-in realtime subscriptions

**Key Changes:**
1. Authentication: Supabase JWT → Appwrite JWT
2. Database: PostgreSQL → Appwrite NoSQL
3. Storage: Supabase Storage → Appwrite Storage
4. Functions: Supabase Edge Functions → Kept in Next.js API routes

**Files Changed:**
- `app/utils/appwrite/` (new directory)
- `app/utils/chat-history-appwrite.ts` (replaced Supabase version)
- `scripts/setup-database.js` (new setup script)
- `.env.local` (updated environment variables)

**Documentation:**
- [MIGRATION_STATUS.md](./MIGRATION_STATUS.md) - Detailed migration log
- [APPWRITE_SETUP.md](./APPWRITE_SETUP.md) - Setup instructions

---

## Additional Resources

### Documentation
- **[ARCHITECTURE.md](./ARCHITECTURE.md)** - Comprehensive architectural analysis
- **[MIGRATION_STATUS.md](./MIGRATION_STATUS.md)** - Supabase → Appwrite migration details
- **[APPWRITE_SETUP.md](./APPWRITE_SETUP.md)** - Appwrite configuration guide

### External Documentation
- [Next.js App Router](https://nextjs.org/docs/app)
- [Appwrite Documentation](https://appwrite.io/docs)
- [Composio MCP](https://docs.composio.dev/)
- [Vercel AI SDK](https://sdk.vercel.ai/docs)

### Package Dependencies
```json
{
  "next": "15.5.7",
  "react": "^19.0.0",
  "appwrite": "^17.0.2",
  "composio-core": "^0.9.13",
  "ai": "^4.0.56",
  "zod": "^3.24.2",
  "winston": "^3.18.1"
}
```

---

## Questions to Ask When Modifying This Codebase

1. **Does this change affect authentication?**
   - Test with valid/invalid JWT tokens
   - Verify conversation ownership checks

2. **Does this change affect the database schema?**
   - Update `scripts/setup-database.js`
   - Document migration steps
   - Test with `npm run verify-db`

3. **Does this change affect the streaming response?**
   - Test with iOS client (not just curl)
   - Verify SSE format compatibility
   - Check `X-Conversation-Id` header handling

4. **Does this add new environment variables?**
   - Update `.env.example`
   - Document in this file
   - Add validation in code

5. **Does this change tool integration?**
   - Test session cache behavior
   - Verify tools load correctly
   - Check for memory leaks

6. **Does this affect API contracts?**
   - Update API documentation in this file
   - Notify iOS client developers
   - Version the API if breaking changes

---

## Code Style & Conventions

### TypeScript
- **Strict mode enabled** - No implicit `any` types
- **Prefer interfaces over types** for object shapes
- **Use Zod for runtime validation** of external data

### Error Handling
```typescript
// Preferred pattern
try {
  const result = await operation();
  return NextResponse.json({ data: result });
} catch (error) {
  logger.error('Operation failed', { error, context });
  return NextResponse.json(
    { error: 'User-friendly message' },
    { status: 500 }
  );
}
```

### Logging
```typescript
// Use structured logging
logger.info('Event happened', {
  userId: auth.user.id,
  conversationId,
  model: currentModel,
});

// NOT console.log in production code
```

### Naming Conventions
- **Files:** kebab-case (`chat-history-appwrite.ts`)
- **Functions:** camelCase (`getUserFromToken`)
- **Constants:** UPPER_SNAKE_CASE (`SESSION_TTL`)
- **Types/Interfaces:** PascalCase (`ModelInfo`)

### Comments
- **JSDoc for public functions:**
  ```typescript
  /**
   * Validates JWT token and returns user information.
   * @param request - Next.js request object
   * @returns User object or error
   */
  ```
- **Inline comments for complex logic** (not obvious code)
- **No commented-out code** (use git history)

---

## Getting Help

### For AI Assistants Working on This Codebase

1. **Start with ARCHITECTURE.md** - Comprehensive system overview
2. **Read the specific file** you're modifying - Don't guess behavior
3. **Check environment variables** in `.env.local` (or `.env.example`)
4. **Test locally** before suggesting changes - Run `npm run dev`
5. **Follow existing patterns** - This codebase has established conventions

### For Human Developers

1. **Run setup scripts:**
   ```bash
   npm install
   npm run setup-db
   npm run dev
   ```

2. **Check the logs:**
   ```bash
   LOG_LEVEL=debug npm run dev
   ```

3. **Verify database:**
   ```bash
   npm run verify-db
   ```

4. **Read the documentation:**
   - Start with this file (CLAUDE.md)
   - Then ARCHITECTURE.md for deep dives
   - Check MIGRATION_STATUS.md for historical context

---

**Last Updated:** January 26, 2026
**Maintained By:** Craft Agent
**Questions?** Check [ARCHITECTURE.md](./ARCHITECTURE.md) for comprehensive technical details.
