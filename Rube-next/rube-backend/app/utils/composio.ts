import { Composio } from '@composio/core';
import { VercelProvider } from '@composio/vercel';

export const getComposio = () => {
  const apiKey = process.env.COMPOSIO_API_KEY;
  if (!apiKey) {
    throw new Error('COMPOSIO_API_KEY environment variable is not set');
  }

  // Initialize Composio with Vercel provider for AI SDK compatibility
  // Cast through unknown to work around private field type mismatch between SDK packages
  const config = {
    apiKey,
    provider: new VercelProvider(),
  };

  return new Composio(config as unknown as ConstructorParameters<typeof Composio>[0]);
};