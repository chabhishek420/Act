import { NextRequest, NextResponse } from 'next/server';
import { getAuthenticatedUser } from '@/app/utils/appwrite/token-auth';
import { deleteConversation } from '@/app/utils/chat-history-appwrite';

export async function DELETE(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id: conversationId } = await params;

    // Get authenticated user
    const auth = await getAuthenticatedUser(request);

    if (!auth.user) {
      return NextResponse.json(
        { error: 'Unauthorized - Please sign in' },
        { status: 401 }
      );
    }

    // Delete conversation and all its messages
    const success = await deleteConversation(conversationId, auth.user.id);

    if (!success) {
      return NextResponse.json(
        { error: 'Failed to delete conversation' },
        { status: 500 }
      );
    }

    return NextResponse.json({ success: true });
  } catch (error) {
    console.error('Error in delete conversation endpoint:', error);
    return NextResponse.json(
      { error: 'Failed to delete conversation' },
      { status: 500 }
    );
  }
}
