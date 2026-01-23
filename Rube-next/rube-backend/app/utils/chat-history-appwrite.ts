import { Client, Databases, ID, Query, Permission, Role } from 'node-appwrite';

// Database configuration
const DATABASE_ID = 'rube-chat';
const CONVERSATIONS_COLLECTION_ID = 'conversations';
const MESSAGES_COLLECTION_ID = 'messages';

export interface Conversation {
  id: string
  title: string | null
  created_at: string
  updated_at: string
  user_id: string
}

export interface Message {
  id: string
  conversation_id: string
  user_id: string
  content: string
  role: 'user' | 'assistant' | 'system'
  created_at: string
}

/**
 * Create an Appwrite client with admin API key
 * Note: This requires APPWRITE_API_KEY in environment variables
 */
function getAppwriteClient() {
  const client = new Client()
    .setEndpoint(process.env.NEXT_PUBLIC_APPWRITE_ENDPOINT!)
    .setProject(process.env.NEXT_PUBLIC_APPWRITE_PROJECT!);

  // Use API key for server-side operations if available
  if (process.env.APPWRITE_API_KEY) {
    client.setKey(process.env.APPWRITE_API_KEY);
  }

  return client;
}

export async function getUserConversations(userId: string): Promise<Conversation[]> {
  if (!userId) {
    console.error('getUserConversations: userId is required');
    return [];
  }

  try {
    const client = getAppwriteClient();
    const databases = new Databases(client);

    const response = await databases.listDocuments(
      DATABASE_ID,
      CONVERSATIONS_COLLECTION_ID,
      [
        Query.equal('user_id', userId),
        Query.orderDesc('$updatedAt'),
        Query.limit(100)
      ]
    );

    return response.documents.map(doc => ({
      id: doc.$id,
      title: doc.title || null,
      created_at: doc.$createdAt,
      updated_at: doc.$updatedAt,
      user_id: doc.user_id
    }));
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : String(error);
    console.error('Error fetching conversations:', message);
    return [];
  }
}

export async function getConversationMessages(conversationId: string): Promise<Message[]> {
  if (!conversationId) {
    console.error('getConversationMessages: conversationId is required');
    return [];
  }

  try {
    const client = getAppwriteClient();
    const databases = new Databases(client);

    const response = await databases.listDocuments(
      DATABASE_ID,
      MESSAGES_COLLECTION_ID,
      [
        Query.equal('conversation_id', conversationId),
        Query.orderAsc('$createdAt'),
        Query.limit(1000)
      ]
    );

    return response.documents.map(doc => ({
      id: doc.$id,
      conversation_id: doc.conversation_id,
      user_id: doc.user_id,
      content: doc.content,
      role: doc.role as 'user' | 'assistant' | 'system',
      created_at: doc.$createdAt
    }));
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : String(error);
    console.error('Error fetching messages:', message);
    return [];
  }
}

export async function createConversation(userId: string, title?: string): Promise<string | null> {
  if (!userId) {
    console.error('createConversation: userId is required');
    return null;
  }

  try {
    const client = getAppwriteClient();
    const databases = new Databases(client);

    const response = await databases.createDocument(
      DATABASE_ID,
      CONVERSATIONS_COLLECTION_ID,
      ID.unique(),
      {
        user_id: userId,
        title: title || null
      },
      [
        Permission.read(Role.user(userId)),
        Permission.update(Role.user(userId)),
        Permission.delete(Role.user(userId))
      ]
    );

    console.log('Created conversation:', response.$id, 'for user:', userId);
    return response.$id;
  } catch (error: unknown) {
    const appwriteError = error as { message?: string; code?: number };
    console.error('Error creating conversation:', appwriteError.message ?? String(error));
    // If database doesn't exist, return a temporary ID and log warning
    if (appwriteError.code === 404) {
      console.warn('⚠️  Database not set up. Run: npm run setup-db');
      console.warn('   Using temporary conversation ID - messages will not persist');
      return `temp-${Date.now()}`;
    }
    return null;
  }
}

export async function addMessage(
  conversationId: string,
  userId: string,
  content: string,
  role: 'user' | 'assistant' | 'system'
): Promise<Message | null> {
  if (!conversationId || !userId || !content) {
    console.error('addMessage: conversationId, userId, and content are required');
    return null;
  }

  try {
    const client = getAppwriteClient();
    const databases = new Databases(client);

    const response = await databases.createDocument(
      DATABASE_ID,
      MESSAGES_COLLECTION_ID,
      ID.unique(),
      {
        conversation_id: conversationId,
        user_id: userId,
        content,
        role
      },
      [
        Permission.read(Role.user(userId)),
        Permission.update(Role.user(userId)),
        Permission.delete(Role.user(userId))
      ]
    );

    console.log('Added message to conversation:', conversationId);
    return {
      id: response.$id,
      conversation_id: response.conversation_id,
      user_id: response.user_id,
      content: response.content,
      role: response.role as 'user' | 'assistant' | 'system',
      created_at: response.$createdAt
    };
  } catch (error: unknown) {
    const appwriteError = error as { message?: string; code?: number };
    console.error('Error adding message:', appwriteError.message ?? String(error));
    // If database doesn't exist, just log warning but don't fail the request
    if (appwriteError.code === 404) {
      console.warn('⚠️  Database not set up - message not saved');
    }
    return null;
  }
}

export function generateConversationTitle(firstMessage: string): string {
  const maxLength = 50;
  const title = firstMessage.slice(0, maxLength);
  return title.length < firstMessage.length ? title + '...' : title;
}

export async function deleteConversation(conversationId: string, userId: string): Promise<boolean> {
  if (!conversationId || !userId) {
    console.error('deleteConversation: conversationId and userId are required');
    return false;
  }

  try {
    const client = getAppwriteClient();
    const databases = new Databases(client);

    // First, delete all messages in the conversation
    const messages = await databases.listDocuments(
      DATABASE_ID,
      MESSAGES_COLLECTION_ID,
      [
        Query.equal('conversation_id', conversationId),
        Query.limit(1000)
      ]
    );

    // Delete messages in batches
    for (const message of messages.documents) {
      try {
        await databases.deleteDocument(
          DATABASE_ID,
          MESSAGES_COLLECTION_ID,
          message.$id
        );
      } catch (error: unknown) {
        const msg = error instanceof Error ? error.message : String(error);
        console.error(`Error deleting message ${message.$id}:`, msg);
      }
    }

    // Then delete the conversation
    await databases.deleteDocument(
      DATABASE_ID,
      CONVERSATIONS_COLLECTION_ID,
      conversationId
    );

    console.log('Deleted conversation:', conversationId);
    return true;
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : String(error);
    console.error('Error deleting conversation:', message);
    return false;
  }
}

export async function getConversation(conversationId: string, userId: string): Promise<Conversation | null> {
  if (!conversationId || !userId) {
    console.error('getConversation: conversationId and userId are required');
    return null;
  }

  try {
    const client = getAppwriteClient();
    const databases = new Databases(client);

    const doc = await databases.getDocument(
      DATABASE_ID,
      CONVERSATIONS_COLLECTION_ID,
      conversationId
    );

    return {
      id: doc.$id,
      title: doc.title || null,
      created_at: doc.$createdAt,
      updated_at: doc.$updatedAt,
      user_id: doc.user_id
    };
  } catch (error: unknown) {
    const appwriteError = error as { message?: string; code?: number };
    console.error('Error fetching conversation:', appwriteError.message ?? String(error));
    if (appwriteError.code === 404) {
      console.warn('Conversation not found');
    }
    return null;
  }
}

export async function updateConversationTitle(conversationId: string, title: string): Promise<boolean> {
  if (!conversationId || !title) {
    console.error('updateConversationTitle: conversationId and title are required');
    return false;
  }

  try {
    const client = getAppwriteClient();
    const databases = new Databases(client);

    await databases.updateDocument(
      DATABASE_ID,
      CONVERSATIONS_COLLECTION_ID,
      conversationId,
      {
        title
      }
    );

    console.log('Updated conversation title:', conversationId);
    return true;
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : String(error);
    console.error('Error updating conversation title:', message);
    return false;
  }
}
