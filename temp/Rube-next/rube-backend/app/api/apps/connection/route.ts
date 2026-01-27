import { NextRequest, NextResponse } from 'next/server';
import { getAuthenticatedUser } from '@/app/utils/appwrite/token-auth';
import { getComposio } from '../../../utils/composio';

// GET: Check connection status for all toolkits for authenticated user
export async function GET(request: NextRequest) {
  try {
    // Get authenticated user
    const auth = await getAuthenticatedUser(request);

    if (!auth.user) {
      return NextResponse.json(
        { error: 'Unauthorized - Please sign in' },
        { status: 401 }
      );
    }

    const userEmail = auth.user.email;
    const composio = getComposio();

    // Fetch connected accounts for the user
    const connectedAccounts = await composio.connectedAccounts.list({
      userIds: [userEmail]
    });

    console.log('Connected accounts for user:', userEmail, `(${connectedAccounts.items?.length || 0} accounts)`);

    // Get detailed info for each connected account
    const detailedAccounts = await Promise.all(
      (connectedAccounts.items || []).map(async (account) => {
        try {
          const accountDetails = await composio.connectedAccounts.get(account.id);
          // Log only essential info without sensitive data
          console.log('Account details for', account.id, ':', {
            toolkit: accountDetails.toolkit?.slug,
            connectionId: accountDetails.id,
            authConfigId: accountDetails.authConfig?.id,
            status: accountDetails.status
          });
          return accountDetails;
        } catch (error) {
          console.error('Error fetching account details for', account.id, ':', error);
          return account; // fallback to original if details fetch fails
        }
      })
    );

    return NextResponse.json({ connectedAccounts: detailedAccounts });
  } catch (error) {
    console.error('Error fetching connection status:', error);
    return NextResponse.json(
      { error: 'Failed to fetch connection status' },
      { status: 500 }
    );
  }
}

// POST: Create auth link for connecting a toolkit
export async function POST(request: NextRequest) {
  try {
    const body = await request.json();
    const { authConfigId, toolkitSlug } = body;

    if (!authConfigId) {
      return NextResponse.json(
        { error: 'authConfigId is required' },
        { status: 400 }
      );
    }

    // Get authenticated user
    const auth = await getAuthenticatedUser(request);

    if (!auth.user) {
      return NextResponse.json(
        { error: 'Unauthorized - Please sign in' },
        { status: 401 }
      );
    }

    const userEmail = auth.user.email;
    console.log('Creating auth link for user:', userEmail, 'toolkit:', toolkitSlug);

    const composio = getComposio();
    const connectionRequest = await composio.connectedAccounts.link(
      userEmail,
      authConfigId,
      {
        callbackUrl: `${process.env.NEXT_PUBLIC_APP_URL || 'http://localhost:3000'}/apps`
      }
    );

    // Return response with redirectUrl for the iOS client
    console.log('Auth link created:', connectionRequest);
    return NextResponse.json({
      ...connectionRequest,
      redirectUrl: connectionRequest.redirectUrl  // Ensure iOS client can access the redirect URL
    });
  } catch (error) {
    console.error('Error creating auth link:', error);
    return NextResponse.json(
      { error: 'Failed to create auth link' },
      { status: 500 }
    );
  }
}

// DELETE: Disconnect a toolkit
export async function DELETE(request: NextRequest) {
  try {
    const body = await request.json();
    const { accountId } = body;

    if (!accountId) {
      return NextResponse.json(
        { error: 'accountId is required' },
        { status: 400 }
      );
    }

    // Get authenticated user
    const auth = await getAuthenticatedUser(request);

    if (!auth.user) {
      return NextResponse.json(
        { error: 'Unauthorized - Please sign in' },
        { status: 401 }
      );
    }

    console.log('Disconnecting account:', accountId, 'for user:', auth.user.email);

    const composio = getComposio();
    const result = await composio.connectedAccounts.delete(accountId);

    console.log('Disconnect result:', result);
    return NextResponse.json({ success: true, result });
  } catch (error) {
    console.error('Error disconnecting account:', error);
    return NextResponse.json(
      { error: 'Failed to disconnect account' },
      { status: 500 }
    );
  }
}