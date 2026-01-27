# Rube Backend API

Standalone backend API for the Rube iOS app.

## Features

- **Appwrite Authentication** - JWT-based auth for iOS clients
- **Chat API** - AI chat with streaming responses (gemini-claude-sonnet-4-5)
- **Tool Router** - 500+ app integrations via Composio MCP
- **Conversation History** - Persistent chat storage in Appwrite Cloud
- **Dynamic Model Loading** - Automatically fetches available models from custom OpenAI API

## Architecture

```
iOS App (Appwrite SDK)
    ↓ JWT Token
Backend API (localhost:3000)
    ├─ /api/chat - Chat completions with streaming
    ├─ /api/conversations - List/delete conversations
    ├─ /api/apps/connection - Manage app connections
    └─ /api/connectedAccounts - Disconnect accounts
    ↓
Appwrite Cloud (Database)
    └─ rube-chat database
        ├─ conversations collection
        └─ messages collection
```

## Quick Start

### 1. Install Dependencies
```bash
npm install
```

### 2. Configure Environment
Edit `.env.local`:

```bash
# Appwrite
NEXT_PUBLIC_APPWRITE_ENDPOINT=https://nyc.cloud.appwrite.io/v1
NEXT_PUBLIC_APPWRITE_PROJECT=your_project_id
APPWRITE_API_KEY=your_api_key

# Composio
COMPOSIO_API_KEY=your_composio_key

# Custom OpenAI API
CUSTOM_API_URL=http://your-api-url/v1
CUSTOM_API_KEY=your_api_key
OPENAI_MODEL=gemini-claude-sonnet-4-5
```

### 3. Setup Database
```bash
npm run setup-db
```

### 4. Start Server
```bash
npm run dev
```

Server runs on `http://localhost:3000`

## API Endpoints

All endpoints require `Authorization: Bearer <jwt_token>` header.

- `POST /api/chat` - Chat with AI (SSE stream)
- `GET /api/conversations` - List conversations
- `GET /api/conversations/:id/messages` - Get messages
- `DELETE /api/conversations/:id` - Delete conversation
- `GET /api/apps/connection` - List connected apps
- `POST /api/apps/connection` - Connect app
- `DELETE /api/apps/connection` - Disconnect app

## Documentation

- **`MIGRATION_STATUS.md`** - Supabase → Appwrite migration details
- **`APPWRITE_SETUP.md`** - Database setup guide

## License

MIT
