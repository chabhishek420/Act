# Supabase → Appwrite Migration Status

**Date:** January 13, 2026
**Migration Scope:** Backend API + iOS App

---

## ✅ Completed: iOS Backend Migration

### Migrated Components

#### 1. Backend API Routes (6 routes)
All API routes used by the iOS app have been migrated to Appwrite:

- **`/api/chat`** - Chat completions with streaming
  - Auth: Appwrite JWT
  - Database: Appwrite (chat-history-appwrite.ts)
  - Features: Message persistence, conversation creation, Tool Router integration

- **`/api/conversations`** - List user's conversations
  - Auth: Appwrite JWT
  - Database: Appwrite

- **`/api/conversations/[id]/messages`** - Get messages for a conversation
  - Auth: Appwrite JWT
  - Database: Appwrite

- **`/api/conversations/[id]`** - Delete conversation
  - Auth: Appwrite JWT
  - Database: Appwrite

- **`/api/connectedAccounts/disconnect`** - Disconnect Composio account
  - Auth: Appwrite JWT
  - External API: Composio

- **`/api/apps/connection`** - Manage app connections
  - Auth: Appwrite JWT
  - External API: Composio

#### 2. Appwrite Database
**Database ID:** `rube-chat`

**Collections:**
- **conversations**
  - Attributes: user_id (required), title (optional)
  - Index: user_id_idx
  - Permissions: Collection-level create("users"), document-level read/update/delete per user
  - Document security: ✅ Enabled

- **messages**
  - Attributes: conversation_id (required), user_id (required), content (required), role (required)
  - Index: conversation_id_idx
  - Permissions: Collection-level create("users"), document-level read/update/delete per user
  - Document security: ✅ Enabled

#### 3. Authentication
**iOS App:**
- Uses Appwrite Web SDK for authentication
- JWT tokens sent in `Authorization: Bearer <token>` header
- Backend validates JWT using `app/utils/appwrite/token-auth.ts`

#### 4. Database Utility
**File:** `app/utils/chat-history-appwrite.ts`

**Functions:**
- `getUserConversations(userId)` - Get user's conversations
- `getConversationMessages(conversationId)` - Get messages in a conversation
- `createConversation(userId, title?)` - Create new conversation
- `addMessage(conversationId, userId, content, role)` - Add message to conversation
- `deleteConversation(conversationId, userId)` - Delete conversation and messages
- `getConversation(conversationId, userId)` - Get single conversation
- `updateConversationTitle(conversationId, title)` - Update conversation title
- `generateConversationTitle(firstMessage)` - Generate title from first message

**Features:**
- Automatic per-document permissions (read/update/delete scoped to creating user)
- Graceful degradation (returns temp IDs if database not set up)
- Comprehensive error logging

#### 5. Environment Configuration
```bash
# Appwrite
NEXT_PUBLIC_APPWRITE_ENDPOINT=https://nyc.cloud.appwrite.io/v1
NEXT_PUBLIC_APPWRITE_PROJECT=6961fcac000432c6a72a
APPWRITE_API_KEY=[your-api-key]

# Custom OpenAI API
CUSTOM_API_URL=http://143.198.174.251:8317/v1
CUSTOM_API_KEY=anything
OPENAI_MODEL=gemini-claude-sonnet-4-5
```

#### 6. Dynamic Model Loading
The chat endpoint now:
- Fetches available models from the custom OpenAI API on first request
- Prefers `gemini-claude-sonnet-4-5` if available
- Falls back to GPT-5 models or first available model
- Respects `OPENAI_MODEL` environment variable if specified

---

## ❌ Not Migrated: Web Frontend

### Components Still Using Supabase

The following files remain on Supabase and are **NOT functional** for web users:

#### Authentication Pages
- `app/auth/page.tsx` - OAuth login page
- `app/auth/callback/route.ts` - OAuth callback handler

#### Frontend Components
- `app/components/UserMenu.tsx` - User menu dropdown
- `app/components/ChatContainer.tsx` - Chat UI (may use Supabase)
- `app/components/AppsPageWithAuth.tsx` - Apps page
- `app/components/AuthWrapper.tsx` - Patched to return null (no web auth)

#### Supabase Utilities (Unused)
- `app/utils/supabase/client.ts` - Browser Supabase client
- `app/utils/supabase/server.ts` - Server Supabase client
- `app/utils/supabase/token-auth.ts` - Supabase JWT validation
- `app/utils/chat-history-supabase-OLD.ts` - Old Supabase database utilities (renamed)

### Impact
- **iOS App:** ✅ Fully functional (uses Appwrite)
- **Web Interface:** ❌ Broken (authentication fails)

**Recommendation:** If web interface is needed, migrate OAuth flows to Appwrite Web SDK or implement alternative authentication.

---

## Setup Instructions

### 1. Database Setup
```bash
npm run setup-db
```

This creates the `rube-chat` database with proper collections and permissions.

### 2. Verify Database
```bash
node scripts/verify-database.js
```

### 3. Recreate Collections (if permissions wrong)
```bash
node scripts/update-collections.js
```

---

## Verification Checklist

- [x] iOS app authenticates with Appwrite
- [x] Chat messages persist to Appwrite database
- [x] Conversations list loads correctly
- [x] Message history loads correctly
- [x] Conversation deletion works
- [x] Document-level permissions enforce user isolation
- [x] Tool Router (MCP) sessions work
- [x] Dynamic model loading from custom API
- [x] Graceful degradation if database unavailable
- [ ] Web interface authentication (intentionally not migrated)

---

## Technical Debt

### Minor Issues
1. ~~Auth destructuring inconsistency in chat route~~ ✅ Fixed
2. ~~Old Supabase chat-history.ts file present~~ ✅ Renamed to `-supabase-OLD.ts`
3. ~~Missing `updateConversationTitle()` function~~ ✅ Added to Appwrite version

### Future Improvements
1. Consider deleting unused Supabase files entirely (currently just renamed)
2. Migrate web OAuth to Appwrite if web interface is needed
3. Add integration tests for Appwrite database operations
4. Document rollback procedure if needed

---

## Migration Timeline

- **2026-01-13 06:00 UTC** - Started migration
- **2026-01-13 06:25 UTC** - Database created in Appwrite Cloud
- **2026-01-13 11:35 UTC** - Fixed permissions (document security enabled)
- **2026-01-13 11:39 UTC** - All API routes migrated
- **2026-01-13 11:46 UTC** - Dynamic model loading implemented
- **2026-01-13 06:17 UTC** - First successful iOS chat with tools
- **2026-01-13 06:25 UTC** - Migration audit completed
- **2026-01-13 06:30 UTC** - Code quality fixes applied

---

## Contact

For questions about this migration, refer to:
- `APPWRITE_SETUP.md` - Appwrite database setup guide
- `scripts/verify-database.js` - Database verification script
- `app/utils/chat-history-appwrite.ts` - Database utility source code
