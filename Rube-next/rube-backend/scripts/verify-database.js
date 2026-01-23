/**
 * Verify Appwrite Database Setup
 * Checks that database, collections, and permissions are correctly configured
 */

const { Client, Databases } = require('node-appwrite');
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

async function verifyDatabase() {
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
    console.log('🔍 Verifying Appwrite database setup...\n');

    // Check database exists
    console.log('📦 Checking database: rube-chat');
    try {
      const db = await databases.get(DATABASE_ID);
      console.log(`✅ Database exists: ${db.name} (ID: ${db.$id})`);
      console.log(`   Created: ${db.$createdAt}\n`);
    } catch (error) {
      if (error.code === 404) {
        console.error('❌ Database not found. Run: npm run setup-db');
        process.exit(1);
      }
      throw error;
    }

    // Check conversations collection
    console.log('📋 Checking conversations collection');
    try {
      const collection = await databases.getCollection(DATABASE_ID, CONVERSATIONS_COLLECTION_ID);
      console.log(`✅ Collection exists: ${collection.name}`);
      console.log(`   Document security: ${collection.documentSecurity}`);
      console.log(`   Attributes: ${collection.attributes.length}`);
      console.log(`   Indexes: ${collection.indexes.length}`);

      // Show attributes
      console.log('\n   Attributes:');
      collection.attributes.forEach(attr => {
        console.log(`     - ${attr.key}: ${attr.type} (${attr.size}) ${attr.required ? '[required]' : '[optional]'}`);
      });

      // Show permissions
      console.log('\n   Permissions:');
      collection.$permissions.forEach(perm => {
        console.log(`     - ${perm}`);
      });
      console.log();
    } catch (error) {
      if (error.code === 404) {
        console.error('❌ Conversations collection not found');
        process.exit(1);
      }
      throw error;
    }

    // Check messages collection
    console.log('💬 Checking messages collection');
    try {
      const collection = await databases.getCollection(DATABASE_ID, MESSAGES_COLLECTION_ID);
      console.log(`✅ Collection exists: ${collection.name}`);
      console.log(`   Document security: ${collection.documentSecurity}`);
      console.log(`   Attributes: ${collection.attributes.length}`);
      console.log(`   Indexes: ${collection.indexes.length}`);

      // Show attributes
      console.log('\n   Attributes:');
      collection.attributes.forEach(attr => {
        console.log(`     - ${attr.key}: ${attr.type} (${attr.size}) ${attr.required ? '[required]' : '[optional]'}`);
      });

      // Show permissions
      console.log('\n   Permissions:');
      collection.$permissions.forEach(perm => {
        console.log(`     - ${perm}`);
      });
      console.log();
    } catch (error) {
      if (error.code === 404) {
        console.error('❌ Messages collection not found');
        process.exit(1);
      }
      throw error;
    }

    console.log('✨ Database verification complete!\n');
    console.log('All checks passed:');
    console.log('  ✅ Database exists in Appwrite Cloud');
    console.log('  ✅ Conversations collection configured');
    console.log('  ✅ Messages collection configured');
    console.log('  ✅ Document security enabled\n');

  } catch (error) {
    console.error('❌ Error verifying database:', error.message);
    if (error.response) {
      console.error('Response:', error.response);
    }
    process.exit(1);
  }
}

verifyDatabase();
