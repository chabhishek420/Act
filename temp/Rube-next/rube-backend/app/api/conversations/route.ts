import { NextRequest, NextResponse } from "next/server";
import { getAuthenticatedUser } from '@/app/utils/appwrite/token-auth';
import { getUserConversations } from '@/app/utils/chat-history-appwrite';

export async function GET(request: NextRequest) {
  try {
    const auth = await getAuthenticatedUser(request);

    if (!auth.user) {
      return NextResponse.json(
        { error: 'Unauthorized' },
        { status: 401 }
      );
    }

    const conversations = await getUserConversations(auth.user.id);

    return NextResponse.json({ conversations });
  } catch (error) {
    console.error('Error fetching conversations:', error);
    return NextResponse.json(
      { error: 'Failed to fetch conversations' },
      { status: 500 }
    );
  }
}