/**
 * Update Appwrite Collections with Correct Permissions
 * Deletes and recreates collections with document-level permissions
 */

const { Client, Databases, Permission, Role } = require('node-appwrite');
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

const APPWRITE_ENDPOINT = process.env.NEXT_PUBLIC_APPWRITE_ENDPOINT || 'https://nyc.cloud.appwrite.io/v1';
const APPWRITE_PROJECT = process.env.NEXT_PUBLIC_APPWRITE_PROJECT || '6961fcac000432c6a72a';
const APPWRITE_API_KEY = process.env.APPWRITE_API_KEY;

const DATABASE_ID = 'rube-chat';
const CONVERSATIONS_COLLECTION_ID = 'conversations';
const MESSAGES_COLLECTION_ID = 'messages';

async function updateCollections() {
  if (!APPWRITE_API_KEY) {
    console.error('❌ Error: APPWRITE_API_KEY environment variable is required');
    process.exit(1);
  }

  const client = new Client()
    .setEndpoint(APPWRITE_ENDPOINT)
    .setProject(APPWRITE_PROJECT)
    .setKey(APPWRITE_API_KEY);

  const databases = new Databases(client);

  try {
    console.log('🔄 Updating Appwrite collections with correct permissions...\n');

    // Delete old conversations collection
    console.log('🗑️  Deleting old conversations collection');
    try {
      await databases.deleteCollection(DATABASE_ID, CONVERSATIONS_COLLECTION_ID);
      console.log('✅ Conversations collection deleted');
    } catch (error) {
      if (error.code !== 404) {
        throw error;
      }
      console.log('ℹ️  Conversations collection does not exist');
    }

    // Delete old messages collection
    console.log('🗑️  Deleting old messages collection');
    try {
      await databases.deleteCollection(DATABASE_ID, MESSAGES_COLLECTION_ID);
      console.log('✅ Messages collection deleted\n');
    } catch (error) {
      if (error.code !== 404) {
        throw error;
      }
      console.log('ℹ️  Messages collection does not exist\n');
    }

    // Recreate conversations collection with document security
    console.log('📋 Creating conversations collection with document security');
    await databases.createCollection(
      DATABASE_ID,
      CONVERSATIONS_COLLECTION_ID,
      'Conversations',
      [
        Permission.create(Role.users()),
      ],
      true // Enable document security
    );
    console.log('✅ Conversations collection created');

    // Add attributes to conversations collection
    console.log('📝 Adding attributes to conversations collection...');

    await databases.createStringAttribute(
      DATABASE_ID,
      CONVERSATIONS_COLLECTION_ID,
      'user_id',
      255,
      true
    );
    console.log('  ✅ Added attribute: user_id');

    await databases.createStringAttribute(
      DATABASE_ID,
      CONVERSATIONS_COLLECTION_ID,
      'title',
      500,
      false
    );
    console.log('  ✅ Added attribute: title');

    // Wait for attributes to be available
    console.log('⏳ Waiting for attributes to be available...');
    await new Promise(resolve => setTimeout(resolve, 2000));

    // Create index on user_id
    console.log('🔍 Creating index on user_id...');
    await databases.createIndex(
      DATABASE_ID,
      CONVERSATIONS_COLLECTION_ID,
      'user_id_idx',
      'key',
      ['user_id'],
      ['asc']
    );
    console.log('✅ Index created\n');

    // Recreate messages collection with document security
    console.log('💬 Creating messages collection with document security');
    await databases.createCollection(
      DATABASE_ID,
      MESSAGES_COLLECTION_ID,
      'Messages',
      [
        Permission.create(Role.users()),
      ],
      true // Enable document security
    );
    console.log('✅ Messages collection created');

    // Add attributes to messages collection
    console.log('📝 Adding attributes to messages collection...');

    await databases.createStringAttribute(
      DATABASE_ID,
      MESSAGES_COLLECTION_ID,
      'conversation_id',
      255,
      true
    );
    console.log('  ✅ Added attribute: conversation_id');

    await databases.createStringAttribute(
      DATABASE_ID,
      MESSAGES_COLLECTION_ID,
      'user_id',
      255,
      true
    );
    console.log('  ✅ Added attribute: user_id');

    await databases.createStringAttribute(
      DATABASE_ID,
      MESSAGES_COLLECTION_ID,
      'content',
      10000,
      true
    );
    console.log('  ✅ Added attribute: content');

    await databases.createStringAttribute(
      DATABASE_ID,
      MESSAGES_COLLECTION_ID,
      'role',
      50,
      true
    );
    console.log('  ✅ Added attribute: role');

    // Wait for attributes to be available
    console.log('⏳ Waiting for attributes to be available...');
    await new Promise(resolve => setTimeout(resolve, 2000));

    // Create index on conversation_id
    console.log('🔍 Creating index on conversation_id...');
    await databases.createIndex(
      DATABASE_ID,
      MESSAGES_COLLECTION_ID,
      'conversation_id_idx',
      'key',
      ['conversation_id'],
      ['asc']
    );
    console.log('✅ Index created\n');

    console.log('✨ Collections updated successfully!\n');
    console.log('Configuration:');
    console.log('  ✅ Document security enabled on both collections');
    console.log('  ✅ Collection permissions: create("users")');
    console.log('  ✅ Document permissions: Set per-document when creating');
    console.log('\nNext: Run `node scripts/verify-database.js` to verify\n');

  } catch (error) {
    console.error('❌ Error updating collections:', error.message);
    if (error.response) {
      console.error('Response:', error.response);
    }
    process.exit(1);
  }
}

updateCollections();
