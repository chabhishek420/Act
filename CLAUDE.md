# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

# Role & Personality
- You are a senior iOS engineer. Be extremely concise. Sacrifice grammar for concision.
- Pay attention to the task and code. If you see a stupid idea, stop and report it.
- **Native-only architecture**: All logic is client-side. No backend.

# Build & Test
- **Build**: `xcodebuild -scheme Rube-ios -destination 'platform=iOS Simulator,name=iPhone 16e' build`
- **Test**: `xcodebuild -scheme Rube-ios -destination 'platform=iOS Simulator,name=iPhone 16e' test`
- **Run Single Test**: `xcodebuild -scheme Rube-ios -destination 'platform=iOS Simulator,name=iPhone 16e' test -only-testing:Rube-iosTests/ClassName/testMethodName`

# Architecture Overview
- **Type**: Native SwiftUI iOS chat app.
- **Core Stack**:
  - **Composio**: Tool integrations (500+ apps) & OAuth.
  - **Appwrite**: Auth, database, and persistence (Direct SDK usage).
  - **SwiftOpenAI**: Custom LLM streaming (OpenAI-compatible).
  - **AsyncAlgorithms**: Stream processing.
- **Key Patterns**:
  - **Native-Only**: Logic lives in `NativeChatService` (orchestration) and `ComposioManager` (tool execution).
  - **Recursive Tool Loop**: `NativeChatService` handles LLM -> Tool Call -> Execution -> LLM loop recursively.
  - **State**: Uses `@Observable` (iOS 17+) for ViewModels.
  - **Memory**: "Durable Brain" stored in Appwrite conversation metadata.

# Key Files
- `Rube-ios/rube-ios.md`: **MUST READ**. Full architecture, flows, and data models.
- `Rube-ios/Config/Config.swift`: Appwrite endpoints.
- `Rube-ios/Config/ComposioConfig.swift`: LLM & Composio keys/config.
- `project.yml`: Dependency and project definition.
- `Secrets.xcconfig`: Real secrets (not in VCS).

# Development Guidelines
1. **Read `Rube-ios/rube-ios.md`** before touching architecture.
2. **Never leak API keys**. Check `Secrets.xcconfig` usage.
3. **Preserve URL Scheme**: `rube://oauth-callback` is critical for OAuth.
4. **No Backend**: Do not suggest creating backend services; use Appwrite or client-side logic.
5. **Concurrency**: Use Swift 6 concurrency (async/await, actors) over completion handlers.
6. **UI**: Use `@Observable` and lazy loading for performance.

# Directory Structure
- `Rube-ios/`: Main source.
  - `Services/`: Business logic (`NativeChatService`, `ComposioManager`, `AppwriteConversationService`).
  - `ViewModels/`: Presentation logic (`ChatViewModel`).
  - `Views/`: SwiftUI views (`Chat/`, `Auth/`).
  - `Models/`: Data structures (`Message`, `Conversation`).
- `Rube-iosTests/`: Unit and integration tests.
