import { NextResponse, type NextRequest } from 'next/server'

export async function updateSession(request: NextRequest) {
  // Since we're using Appwrite with JWT authentication,
  // we don't need Supabase session management
  // Just pass the request through
  return NextResponse.next({
    request,
  })
}