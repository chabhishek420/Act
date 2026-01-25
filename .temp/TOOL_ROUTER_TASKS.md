# Tool Router Integration Tasks (REVISED)

**Last Updated:** 2026-01-24  
**Status:** In Progress / Phase 1 Complete ✅  
**Priority:** High

---

## 🧠 Architectural Shift
Transition from **Direct Tool Fetching** (fetching 100+ individual tools) to **Tool Router Meta-Orchestration** (using 6 high-level tools).

### Current Status:
1. `ComposioManager` now correctly exposes `getMetaTools`, `executeMetaTool`, and `executeSessionTool`. ✅
2. `NativeChatService` now correctly initiates with only meta-tools and handles dynamic discovery. ✅
3. **Execution-First "Rube" System Prompt** implemented and optimized for iOS (~2,350 tokens). ✅

---

## ✅ Phase 1: Core SDK & Service Wiring (COMPLETED)

### 1.1 Expand `ComposioManager` Wrapper
- [x] **Expose Meta-Tool Discovery**
  - Add `func getMetaTools(sessionId: String) async throws -> [Tool]`
  - Use `composio.toolRouter.fetchTools(in:)`
- [x] **Implement Meta-Execution Path**
  - Add `func executeMetaTool(slug: String, sessionId: String, arguments: [String: Any]?) async throws -> ToolRouterExecuteResponse`
  - Use `composio.toolRouter.executeMeta(slug, in: sessionId, arguments: arguments)`

### 1.2 Rewrite `NativeChatService` Tool Loop
- [x] **Switch Tool Source**
  - Replace `composioManager.getTools(...)` with `composioManager.getMetaTools(sessionId:)`
  - Ensure the agent only sees the `COMPOSIO_` meta-tools initially.
- [x] **Remove Tool Name Mapping** (Note: Kept for session tools during execution to ensure safety, but meta-tools are prioritized).

### 1.3 Implement "Rube Core" System Prompt
- [x] **Update System Message**
  - Adapted mandate from `rube-system-prompt.md`.
  - Added XML tagging and iOS-specific constraints.
  - Strictly forbid: "I can help you..." and other non-action-oriented filler.

---

## 🟡 Phase 2: Implementation of Meta-Tools (Medium Priority)

### 2.1 `COMPOSIO_SEARCH_TOOLS` Integration
- [ ] **Plan Parsing**
  - Handle the complex response containing `recommended_plan_steps` and `tool_schemas`.
  - Store discovered tool schemas in a local cache for the duration of the conversation.
- [ ] **Pitfall Awareness**
  - Injected `known_pitfalls` should be formatted into the context for the next LLM turn to avoid errors.

### 2.2 Auth Healing Flow (`COMPOSIO_MANAGE_CONNECTIONS`)
- [ ] **Disconnected State Detection**
  - If search returns `has_active_connection: false` for a toolkit, automatically call `COMPOSIO_MANAGE_CONNECTIONS`.
- [ ] **In-Chat Redirects**
  - Detect `redirect_url` in tool results and emit a special event for the UI to show a "Connect [App]" button.

---

## 🟢 Phase 3: UX & Performance (Low Priority)

### 3.1 Multi-Execute Parallelism
- [ ] **Task Batching**
  - Enable the agent to use `COMPOSIO_MULTI_EXECUTE_TOOL` for independent tasks (e.g., fetching from Gmail and Slack simultaneously).

### 3.2 Workbench Integration
- [ ] **Data Offloading**
  - Use `COMPOSIO_REMOTE_WORKBENCH` when tool results exceed 100k characters to prevent context window overflows.

---

## ✅ Integration Checklist & Testing
- [x] Verify `getMetaTools` correctly shows `COMPOSIO_SEARCH_TOOLS` when using a session.
- [x] Verify LLM starts with a Search call instead of hallucinating tool usage.
- [x] **Verified build successful on physical iPhone device.** ✅

---

**Next Turn**: Implement persistent Memory Storage for tool results.
