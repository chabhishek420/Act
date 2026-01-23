/**
 * Appwrite Database Setup Script
 * Creates the database schema for chat history (conversations and messages)
 */

const { Client, Databases, ID, Permission, Role } = require('node-appwrite');
const fs = require('fs');
const path = require('path');

// Load environment variables from .env.local
function loadEnvFile() {
  const envPath = path.join(__dirname, '..', '.env.local');
  if (!fs.existsSync(envPath)) {
    console.error('❌ .env.local file not found');
    process.exit(1);
  }

  const envContent = fs.readFileSync(envPath, 'utf8');
  envContent.split('\n').forEach(line => {
    const trimmed = line.trim();
    if (trimmed && !trimmed.startsWith('#')) {
      const [key, ...valueParts] = trimmed.split('=');
      if (key && valueParts.length > 0) {
        process.env[key.trim()] = valueParts.join('=').trim();
      }
    }
  });
}

loadEnvFile();

// Configuration from .env.local
const APPWRITE_ENDPOINT = process.env.NEXT_PUBLIC_APPWRITE_ENDPOINT || 'https://nyc.cloud.appwrite.io/v1';
const APPWRITE_PROJECT = process.env.NEXT_PUBLIC_APPWRITE_PROJECT || '6961fcac000432c6a72a';
const APPWRITE_API_KEY = process.env.APPWRITE_API_KEY; // Required for admin operations

const DATABASE_ID = 'rube-chat';
const CONVERSATIONS_COLLECTION_ID = 'conversations';
const MESSAGES_COLLECTION_ID = 'messages';

async function setupDatabase() {
  if (!APPWRITE_API_KEY) {
    console.error('❌ Error: APPWRITE_API_KEY environment variable is required');
    console.log('Please add it to your .env.local file');
    console.log('Get it from: https://cloud.appwrite.io/console/project-6961fcac000432c6a72a/settings');
    process.exit(1);
  }

  // Initialize Appwrite client with API key
  const client = new Client()
    .setEndpoint(APPWRITE_ENDPOINT)
    .setProject(APPWRITE_PROJECT)
    .setKey(APPWRITE_API_KEY);

  const databases = new Databases(client);

  try {
    console.log('🚀 Starting Appwrite database setup...\n');

    // Create database
    console.log('📦 Creating database: rube-chat');
    try {
      await databases.create(DATABASE_ID, 'Rube Chat');
      console.log('✅ Database created\n');
    } catch (error) {
      if (error.code === 409) {
        console.log('ℹ️  Database already exists\n');
      } else {
        throw error;
      }
    }

    // Create conversations collection
    console.log('📋 Creating conversations collection');
    try {
      await databases.createCollection(
        DATABASE_ID,
        CONVERSATIONS_COLLECTION_ID,
        'Conversations',
        [
          Permission.create(Role.users()),
        ],
        true // Enable document security - permissions set per-document
      );
      console.log('✅ Conversations collection created');
    } catch (error) {
      if (error.code === 409) {
        console.log('ℹ️  Conversations collection already exists');
      } else {
        throw error;
      }
    }

    // Add attributes to conversations collection
    console.log('📝 Adding attributes to conversations collection...');

    const conversationAttributes = [
      { name: 'user_id', type: 'string', size: 255, required: true },
      { name: 'title', type: 'string', size: 500, required: false },
    ];

    for (const attr of conversationAttributes) {
      try {
        await databases.createStringAttribute(
          DATABASE_ID,
          CONVERSATIONS_COLLECTION_ID,
          attr.name,
          attr.size,
          attr.required
        );
        console.log(`  ✅ Added attribute: ${attr.name}`);
      } catch (error) {
        if (error.code === 409) {
          console.log(`  ℹ️  Attribute ${attr.name} already exists`);
        } else {
          throw error;
        }
      }
    }

    // Create index on user_id for conversations
    console.log('🔍 Creating index on user_id...');
    try {
      await databases.createIndex(
        DATABASE_ID,
        CONVERSATIONS_COLLECTION_ID,
        'user_id_idx',
        'key',
        ['user_id'],
        ['asc']
      );
      console.log('✅ Index created\n');
    } catch (error) {
      if (error.code === 409) {
        console.log('ℹ️  Index already exists\n');
      } else {
        throw error;
      }
    }

    // Create messages collection
    console.log('💬 Creating messages collection');
    try {
      await databases.createCollection(
        DATABASE_ID,
        MESSAGES_COLLECTION_ID,
        'Messages',
        [
          Permission.create(Role.users()),
        ],
        true // Enable document security - permissions set per-document
      );
      console.log('✅ Messages collection created');
    } catch (error) {
      if (error.code === 409) {
        console.log('ℹ️  Messages collection already exists');
      } else {
        throw error;
      }
    }

    // Add attributes to messages collection
    console.log('📝 Adding attributes to messages collection...');

    const messageAttributes = [
      { name: 'conversation_id', type: 'string', size: 255, required: true },
      { name: 'user_id', type: 'string', size: 255, required: true },
      { name: 'content', type: 'string', size: 10000, required: true },
      { name: 'role', type: 'string', size: 50, required: true },
    ];

    for (const attr of messageAttributes) {
      try {
        await databases.createStringAttribute(
          DATABASE_ID,
          MESSAGES_COLLECTION_ID,
          attr.name,
          attr.size,
          attr.required
        );
        console.log(`  ✅ Added attribute: ${attr.name}`);
      } catch (error) {
        if (error.code === 409) {
          console.log(`  ℹ️  Attribute ${attr.name} already exists`);
        } else {
          throw error;
        }
      }
    }

    // Create index on conversation_id for messages
    console.log('🔍 Creating index on conversation_id...');
    try {
      await databases.createIndex(
        DATABASE_ID,
        MESSAGES_COLLECTION_ID,
        'conversation_id_idx',
        'key',
        ['conversation_id'],
        ['asc']
      );
      console.log('✅ Index created\n');
    } catch (error) {
      if (error.code === 409) {
        console.log('ℹ️  Index already exists\n');
      } else {
        throw error;
      }
    }

    console.log('✨ Database setup complete!\n');
    console.log('Database ID:', DATABASE_ID);
    console.log('Collections:');
    console.log('  - conversations');
    console.log('  - messages\n');
    console.log('Next steps:');
    console.log('1. Update app/utils/chat-history.ts to use Appwrite instead of Supabase');
    console.log('2. Restart the Next.js dev server\n');

  } catch (error) {
    console.error('❌ Error setting up database:', error.message);
    if (error.response) {
      console.error('Response:', error.response);
    }
    process.exit(1);
  }
}

setupDatabase();
