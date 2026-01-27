import { NextRequest, NextResponse } from "next/server";
import { getAuthenticatedUser } from '@/app/utils/appwrite/token-auth';
import { getConversationMessages } from '@/app/utils/chat-history-appwrite';

export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id } = await params;
    const auth = await getAuthenticatedUser(request);

    if (!auth.user) {
      return NextResponse.json(
        { error: 'Unauthorized' },
        { status: 401 }
      );
    }

    // Get messages for this conversation
    // Document-level permissions in Appwrite will ensure user can only access their own conversations
    const messages = await getConversationMessages(id);

    return NextResponse.json({ messages });
  } catch (error) {
    console.error('Error fetching conversation messages:', error);
    return NextResponse.json(
      { error: 'Failed to fetch messages' },
      { status: 500 }
    );
  }
}