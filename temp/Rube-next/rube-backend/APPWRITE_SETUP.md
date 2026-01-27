# Appwrite Database Setup for Rube Chat

## Overview

This project now uses **Appwrite Database** instead of Supabase for storing chat conversations and messages.

## Current Status

✅ **Completed:**
- Migrated chat history from Supabase to Appwrite
- Created `chat-history-appwrite.ts` utility
- Updated chat API route to use Appwrite
- Added database setup script

⚠️ **Requires Setup:**
- Appwrite Database needs to be created
- API key needs to be added to environment variables

## Quick Setup

### Step 1: Get Your Appwrite API Key

1. Go to: https://cloud.appwrite.io/console/project-6961fcac000432c6a72a/settings
2. Navigate to **Settings** → **API Keys**
3. Click **Create API Key**
4. Name it: `Database Admin`
5. **Scopes:** Select ALL scopes (or at minimum: `databases.read`, `databases.write`, `collections.read`, `collections.write`, `documents.read`, `documents.write`)
6. Click **Create**
7. **Copy the API key** (you won't be able to see it again!)

### Step 2: Add API Key to Environment

Edit `.env.local` and replace the placeholder:

```bash
# Change this:
APPWRITE_API_KEY=your_api_key_here_from_appwrite_console

# To this (with your actual key):
APPWRITE_API_KEY=standard_a1b2c3d4e5f6...
```

### Step 3: Run Database Setup

```bash
npm run setup-db
```

This script will:
- Create a database called `rube-chat`
- Create `conversations` collection with proper schema
- Create `messages` collection with proper schema
- Set up indexes for efficient queries
- Configure permissions for user access

### Step 4: Restart Next.js Server

```bash
# Stop the current server (Ctrl+C)
npm run dev
```

## Database Schema

### Conversations Collection
```
- id (auto-generated)
- user_id (string, required, indexed)
- title (string, optional)
- $createdAt (auto)
- $updatedAt (auto)
```

### Messages Collection
```
- id (auto-generated)
- conversation_id (string, required, indexed)
- user_id (string, required)
- content (string, required)
- role (string: 'user' | 'assistant' | 'system')
- $createdAt (auto)
```

## Permissions

Both collections use these permissions:
- **Read**: User can read their own documents
- **Create**: All authenticated users can create
- **Update**: User can update their own documents
- **Delete**: User can delete their own documents

## Testing

After setup, test the chat API:

```bash
# This should work and create a conversation
curl -X POST http://localhost:3000/api/chat \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -d '{"messages":[{"role":"user","content":"Hello"}]}'
```

## Troubleshooting

### "Database not found" error

If you see: `⚠️  Database not set up. Run: npm run setup-db`

Solution: Follow steps 1-3 above to create the database.

### "Session not found" error

If using Appwrite CLI and getting session errors:

```bash
appwrite login
# Then run the setup script again
npm run setup-db
```

### API Key Issues

Make sure your API key has these scopes:
- `databases.read`
- `databases.write`
- `collections.read`
- `collections.write`
- `documents.read`
- `documents.write`

## Files Modified

- ✅ `app/utils/chat-history-appwrite.ts` - New Appwrite database utilities
- ✅ `app/api/chat/route.ts` - Updated to use Appwrite
- ✅ `scripts/setup-database.js` - Database setup script
- ✅ `.env.local` - Added APPWRITE_API_KEY
- ✅ `package.json` - Added setup-db script

## Migration Notes

The new Appwrite implementation:
- ✅ Same API as old Supabase version
- ✅ Graceful degradation if database not set up (uses temp IDs)
- ✅ Proper error logging for debugging
- ✅ Automatic timestamps via Appwrite
- ✅ User-based permissions out of the box

## Next Steps

1. Get API key from Appwrite Console
2. Add it to `.env.local`
3. Run `npm run setup-db`
4. Restart server
5. Test chat functionality!
