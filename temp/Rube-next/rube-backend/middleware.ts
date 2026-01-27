import { NextRequest, NextResponse } from 'next/server';

export function middleware(request: NextRequest) {
  // Handle preflight requests
  if (request.method === 'OPTIONS') {
    return new NextResponse(null, {
      status: 200,
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-Conversation-Id',
        'Access-Control-Expose-Headers': 'X-Conversation-Id',
        'Access-Control-Max-Age': '86400',
      },
    });
  }

  // Add CORS headers to all responses
  const response = NextResponse.next();

  response.headers.set('Access-Control-Allow-Origin', '*');
  response.headers.set('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
  response.headers.set('Access-Control-Allow-Headers', 'Content-Type, Authorization, X-Conversation-Id');
  response.headers.set('Access-Control-Expose-Headers', 'X-Conversation-Id');

  return response;
}

// Configure which routes the middleware should run on
export const config = {
  matcher: '/api/:path*',
};
