import { Client, Account } from 'node-appwrite';
import { NextRequest } from 'next/server';

/**
 * Token-based authentication for iOS/mobile clients using Appwrite JWT.
 * Extracts Bearer token from Authorization header and validates via Appwrite.
 */
export async function getUserFromToken(request: NextRequest) {
  const authHeader = request.headers.get('Authorization');

  // No auth header provided
  if (!authHeader) {
    return { user: null, error: 'No Authorization header' };
  }

  // Must be Bearer token
  if (!authHeader.startsWith('Bearer ')) {
    return { user: null, error: 'Invalid Authorization format (expected Bearer token)' };
  }

  const token = authHeader.slice(7); // Remove 'Bearer ' prefix

  if (!token) {
    return { user: null, error: 'Empty token' };
  }

  try {
    // Create Appwrite client with JWT
    const client = new Client()
      .setEndpoint(process.env.NEXT_PUBLIC_APPWRITE_ENDPOINT!)
      .setProject(process.env.NEXT_PUBLIC_APPWRITE_PROJECT!)
      .setJWT(token);

    const account = new Account(client);

    // Verify JWT by getting the user - this will throw if invalid
    const user = await account.get();

    return {
      user: {
        id: user.$id,
        email: user.email,
        name: user.name,
      },
      error: null
    };
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : 'Invalid or expired token';
    return { user: null, error: message };
  }
}

/**
 * Helper to get user from token (for iOS/mobile clients).
 * Unlike the Supabase version, Appwrite doesn't need cookie fallback
 * since we're not using Appwrite cookies on the web.
 */
export async function getAuthenticatedUser(request: NextRequest) {
  const tokenAuth = await getUserFromToken(request);
  if (tokenAuth.user) {
    return { user: tokenAuth.user, source: 'token' as const };
  }

  return { user: null, source: null, error: tokenAuth.error };
}
