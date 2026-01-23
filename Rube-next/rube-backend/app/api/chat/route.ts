import { NextRequest, NextResponse } from "next/server";
import { streamText, stepCountIs, tool, Tool } from 'ai';
import { createOpenAI } from '@ai-sdk/openai';
import { getAuthenticatedUser } from '@/app/utils/appwrite/token-auth';
import { z } from 'zod';
import {
  createConversation,
  addMessage,
  generateConversationTitle
} from '@/app/utils/chat-history-appwrite';
import { getComposio } from "@/app/utils/composio";
import { logger } from '@/app/utils/logger';

type ToolsRecord = Record<string, Tool>;

interface MCPSessionCache {
  tools: ToolsRecord;
  createdAt: number;
}

// Session cache to store MCP sessions per chat session per user
const sessionCache = new Map<string, MCPSessionCache>();
const SESSION_TTL = 3600 * 1000; // 1 hour

// Clean expired sessions
function cleanExpiredSessions() {
  const now = Date.now();
  for (const [key, value] of sessionCache.entries()) {
    if (now - value.createdAt > SESSION_TTL) {
      sessionCache.delete(key);
    }
  }
}

// Configure OpenAI-compatible client (supports custom base URL + key)
const openAIClient = createOpenAI({
  apiKey: process.env.CUSTOM_API_KEY || process.env.OPENAI_API_KEY,
  baseURL: process.env.CUSTOM_API_URL || process.env.OPENAI_BASE_URL,
});

// Fetch available models from the API
let availableModels: string[] = [];
let defaultModel = process.env.OPENAI_MODEL || 'gemini-claude-sonnet-4-5';
let modelsFetched = false;

async function fetchAvailableModels() {
  if (modelsFetched) return defaultModel;

  try {
    const response = await fetch(`${process.env.CUSTOM_API_URL || process.env.OPENAI_BASE_URL}/models`, {
      headers: {
        'Authorization': `Bearer ${process.env.CUSTOM_API_KEY || process.env.OPENAI_API_KEY}`
      }
    });
    const data = await response.json();
    availableModels = data.data?.map((m: { id: string }) => m.id) || [];

    // Use env model if specified and available, otherwise use first available model
    const envModel = process.env.OPENAI_MODEL;
    if (envModel && availableModels.includes(envModel)) {
      defaultModel = envModel;
    } else if (availableModels.length > 0) {
      // Prefer gemini-claude-sonnet-4-5 if available
      defaultModel = availableModels.find(m => m.includes('gemini-claude-sonnet-4-5'))
        || availableModels.find(m => m.includes('gpt-5'))
        || availableModels[0];
    }

    modelsFetched = true;
    console.log(`📋 Loaded ${availableModels.length} models. Using: ${defaultModel}`);
  } catch (error) {
    console.error('Failed to fetch models, using env default:', error);
    defaultModel = process.env.OPENAI_MODEL || 'gemini-claude-sonnet-4-5';
    modelsFetched = true;
  }

  return defaultModel;
}


export async function POST(request: NextRequest) {
  try {
    const { messages, conversationId } = await request.json();

    if (!messages) {
      return NextResponse.json(
        { error: 'messages is required' },
        { status: 400 }
      );
    }

    // Fetch available models if not already done
    const modelToUse = await fetchAvailableModels();

    // Authenticate with Appwrite JWT
    const auth = await getAuthenticatedUser(request);

    if (!auth.user) {
      return NextResponse.json(
        { error: auth.error || 'Unauthorized - Please sign in' },
        { status: 401 }
      );
    }

    const userEmail = auth.user.email;
    if (!userEmail) {
      return NextResponse.json(
        { error: 'User email not found' },
        { status: 400 }
      );
    }

    logger.info('User authenticated', { userId: auth.user.id });

    let currentConversationId = conversationId;
    const latestMessage = messages[messages.length - 1];
    const isFirstMessage = !conversationId;

    // Create new conversation if this is the first message
    if (isFirstMessage) {
      const title = generateConversationTitle(latestMessage.content);
      currentConversationId = await createConversation(auth.user.id, title);

      if (!currentConversationId) {
        return NextResponse.json(
          { error: 'Failed to create conversation' },
          { status: 500 }
        );
      }
    }

    // Save user message to database
    await addMessage(
      currentConversationId,
      auth.user.id,
      latestMessage.content,
      'user'
    );

    logger.info('Starting Tool Router Agent execution', { conversationId: currentConversationId });

    // Clean expired sessions periodically
    cleanExpiredSessions();

    // Create a unique session key based on user and conversation
    const sessionKey = `${auth.user.id}-${currentConversationId}`;

    let tools: ToolsRecord;

    // Check if we have a valid cached session for this chat
    const cached = sessionCache.get(sessionKey);
    const now = Date.now();

    if (cached && (now - cached.createdAt < SESSION_TTL)) {
      logger.debug('Reusing existing Composio session', { sessionKey });
      tools = cached.tools;
    } else {
      // Delete stale session if exists
      if (cached) {
        sessionCache.delete(sessionKey);
        logger.debug('Deleted expired MCP session', { sessionKey });
      }

      logger.info('Creating new MCP session', { sessionKey });
      const composio = getComposio();

      // Use composio.create() with user ID as a string (official API signature from Composio docs)
      const session = await composio.create(auth.user.id);

      // Get tools directly from session (Composio's native Vercel provider handles everything)
      const composioTools = await session.tools();
      const toolNames = Object.keys(composioTools as object);
      logger.debug('Composio tools loaded', {
        toolCount: toolNames.length,
        tools: toolNames
      });

      // Add custom REQUEST_USER_INPUT tool
      // Cast through unknown since Composio tools use a slightly different type structure
      const baseTools = composioTools as unknown as ToolsRecord;
      tools = {
        ...baseTools,
        REQUEST_USER_INPUT: tool({
          description: 'Request custom input fields from the user BEFORE starting OAuth flow. Use ONLY when a service requires additional parameters beyond standard OAuth (e.g., Pipedrive subdomain, Salesforce instance URL, custom API endpoint). DO NOT use for services that only need standard OAuth authorization.',
          inputSchema: z.object({
            provider: z.string().describe('The name of the service/provider (e.g., "pipedrive", "salesforce")'),
            fields: z.array(
              z.object({
                name: z.string().describe('Field name (e.g., "subdomain")'),
                label: z.string().describe('User-friendly label (e.g., "Company Subdomain")'),
                type: z.string().optional().describe('Input type (text, email, password, etc.)'),
                required: z.boolean().optional().describe('Whether this field is required'),
                placeholder: z.string().optional().describe('Placeholder text for the input')
              })
            ).describe('List of input fields to request from the user'),
            authConfigId: z.string().optional().describe('The auth config ID to use after collecting inputs'),
            logoUrl: z.string().optional().describe('URL to the provider logo/icon')
          }),
          execute: async ({ provider, fields, authConfigId, logoUrl }: {
            provider: string;
            fields: Array<{
              name: string;
              label: string;
              type?: string;
              required?: boolean;
              placeholder?: string;
            }>;
            authConfigId?: string;
            logoUrl?: string;
          }) => {
            // Return a special marker that the frontend will detect
            return {
              type: 'user_input_request',
              provider,
              fields,
              authConfigId,
              logoUrl,
              message: `Requesting user input for ${provider}`
            };
          }
        })
      };

      // Cache the tools for this chat
      sessionCache.set(sessionKey, { tools, createdAt: Date.now() });
    }

    const result = await streamText({
      model: openAIClient(modelToUse),
      tools,
      system: `You are a helpful AI assistant called Rube that can interact with 500+ applications through Composio's Tool Router.

            When responding to users:
            - Always format your responses using Markdown syntax
            - Use **bold** for emphasis and important points
            - Use bullet points and numbered lists for clarity
            - Format links as [text](url) so they are clickable
            - Use code blocks with \`\`\` for code snippets
            - Use inline code with \` for commands, file names, and technical terms
            - Use headings (##, ###) to organize longer responses
            - Make your responses clear, concise, and well-structured

            When executing actions:
            - Explain what you're doing before using tools
            - Provide clear feedback about the results
            - Include relevant links when appropriate

            CRITICAL - Source of Truth:
            - For ANY information about connections, toolkits, or app integrations, ALWAYS rely on tool calls
            - Tool call results are the ONLY source of truth - do not rely on memory or assumptions
            - If you need to know about connection status, available tools, or app capabilities, call the relevant tool
            - Examples: Use RUBE_SEARCH_TOOLS to find available tools, RUBE_MANAGE_CONNECTIONS to check connection status
            - Never assume a connection exists or tools are available without checking via tool calls

            IMPORTANT - Custom Input Fields:
            - Some services require additional parameters BEFORE OAuth (e.g., Pipedrive needs company subdomain, Salesforce needs instance URL)
            - When connecting to these services, you MUST use the REQUEST_USER_INPUT tool FIRST to collect required fields
            - Examples that need REQUEST_USER_INPUT: Pipedrive (subdomain), Salesforce (instance URL), custom API endpoints
            - Examples that DON'T need it: Gmail, Slack, GitHub (standard OAuth only)
            - After collecting inputs via REQUEST_USER_INPUT, the user will provide the values, then you can proceed with RUBE_MANAGE_CONNECTIONS

            Always prefer to authenticate with Composio Managed Authentication unless explicitly requested otherwise.
          `,
      messages: messages,
      stopWhen: stepCountIs(50),
      onStepFinish: () => {
        logger.debug('AI step completed');
      },
      onFinish: async (event) => {
        // Save assistant response to database when streaming finishes
        try {
          const result = await addMessage(
            currentConversationId,
            auth.user.id,
            event.text,
            'assistant'
          );

          if (!result) {
            logger.warn('Failed to save assistant message to database', {
              conversationId: currentConversationId,
              userId: auth.user.id,
              textLength: event.text.length
            });
          } else {
            logger.debug('Assistant message saved to database', {
              conversationId: currentConversationId,
              messageLength: event.text.length
            });
          }
        } catch (error) {
          logger.error('Error saving assistant message', error, {
            conversationId: currentConversationId,
            userId: auth.user.id
          });
        }
      },
    });

    // Return streaming response with tool call data
    return result.toUIMessageStreamResponse({
      headers: {
        'X-Conversation-Id': currentConversationId,
      },
    });
  } catch (error) {
    logger.error('Error in chat endpoint', error);
    return NextResponse.json(
      { error: 'Failed to process chat request' },
      { status: 500 }
    );
  }
}
