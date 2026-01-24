# API Configuration Summary

## Configuration Complete ✅

The Rube iOS app has been successfully configured to use the custom API endpoints and Composio API key.

### API Settings

| Setting | Value |
|---------|-------|
| **Custom API URL** | `http://143.198.174.251:8317/` |
| **Custom API Key** | `anything` |
| **Composio API Key** | `ak_zADvaco59jaMiHrqpjj4` |

### Endpoints

The app will use these endpoints from the custom API server:

- **POST** `/v1/chat/completions` - For LLM chat completion requests
- **GET** `/v1/models` - For listing available models

### How Configuration Works

The iOS app uses a two-step configuration process:

1. **Environment Variables (Priority)**: On app launch, `SecureConfig` checks for environment variables first
2. **iOS Keychain (Storage)**: If keys don't exist in Keychain, environment variable values are migrated to secure storage
3. **Subsequent Launches**: Keychain values are used (environment variables still take priority if set)

**Important**: The iOS simulator has a separate sandboxed Keychain from macOS. Configuration must be done via:
- Environment variables in Xcode scheme, OR
- `simctl launch` with `SIMCTL_CHILD_*` prefixed variables

### Configuration Methods

#### Method 1: Xcode Scheme (Recommended for Development)

The scheme has been updated with environment variables. When launching from Xcode:
- Edit Scheme → Run → Environment Variables
- Values are pre-configured

#### Method 2: Command Line with simctl

Launch with environment variables:
```bash
SIMCTL_CHILD_CUSTOM_API_URL="http://143.198.174.251:8317/" \
SIMCTL_CHILD_CUSTOM_API_KEY="anything" \
SIMCTL_CHILD_COMPOSIO_API_KEY="ak_zADvaco59jaMiHrqpjj4" \
xcrun simctl launch booted com.rube.ios
```

#### Method 3: Reset and Re-migrate

To force re-migration from environment variables:
1. Uninstall the app: `xcrun simctl uninstall booted com.rube.ios`
2. Reinstall: `xcrun simctl install booted <path-to-app>`
3. Launch with environment variables (above command)

### Storage Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    App Launch Flow                          │
├─────────────────────────────────────────────────────────────┤
│  1. Rube_iosApp.init() calls SecureConfig.setupDefaultsIfNeeded()
│  2. Check: Does Keychain have keys?                         │
│     ├─ YES → Use Keychain values                           │
│     └─ NO  → Read environment variables → Save to Keychain │
│  3. SecureConfig properties check env vars FIRST, then Keychain
└─────────────────────────────────────────────────────────────┘
```

### How It Works

1. **SecureConfig.swift** reads from environment variables (priority) or Keychain (fallback)
2. **ComposioConfig.swift** provides backward-compatible access to SecureConfig
3. **NativeChatService.swift** uses ComposioConfig to initialize the OpenAI client
4. **ComposioManager.swift** uses SecureConfig to initialize the Composio SDK

### Helper Scripts (macOS Only)

These scripts work on macOS for testing the Keychain code path:

#### `configure-apis.swift`
Saves API keys to **macOS** Keychain (not iOS simulator):
```bash
swift configure-apis.swift
```

#### `verify-config.swift`
Verifies that API keys are in **macOS** Keychain:
```bash
swift verify-config.swift
```

**Note**: These scripts do NOT configure the iOS simulator. Use environment variables instead.

### Verification

✅ Environment variables configured in Xcode scheme
✅ App built successfully
✅ App installed on iPhone 16e simulator
✅ App launches without crashes
✅ ComposioManager initialized with new API key
✅ API endpoint reachability confirmed:
   - GET /v1/models returns 34 available models
   - POST /v1/chat/completions successfully processes requests
   - Response format matches OpenAI API specification

### Available Models

The custom API server provides 34 models including:
- **gemini-claude-sonnet-4-5-thinking** (recommended for production)
- **gemini-claude-opus-4-5-thinking** (highest capability)
- **gemini-3-flash-preview** (fastest responses)
- **gpt-5.2-codex** (code generation)
- **gemini-2.5-pro** (Google's latest)
- and 29 more models for various use cases

To change the model used by the app, update `SecureConfig.llmModel` or use the Settings UI (if implemented).

### Notes

- The custom API URL is automatically prepended to all OpenAI SDK requests
- SwiftOpenAI SDK automatically appends `/v1` to the base URL, so the configured URL should NOT include it
- All API communication uses the configured custom endpoint instead of OpenAI's servers
- Composio tool execution uses the Composio API key to access their backend services

### Troubleshooting

**Configuration not taking effect?**
1. Uninstall the app: `xcrun simctl uninstall booted com.rube.ios`
2. Reinstall and launch with environment variables

**Changing API keys:**
1. Update environment variables in Xcode scheme OR
2. Clear app data and re-launch with new `SIMCTL_CHILD_*` variables

**Clear all credentials (in-app):**
```swift
try SecureConfig.clearAllCredentials()
```

---
*Configuration completed: 2026-01-25*
*Documentation updated to reflect correct iOS/macOS Keychain separation*
