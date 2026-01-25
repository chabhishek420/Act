# Tool Router Verified Capabilities for iOS

**Verification Date:** 2026-01-24  
**API Version:** v3  
**Session Created:** `trs_PTncEoK-r2ZE`  
**Verified With:** `ak_zADvaco59jaMiHrqpjj4`

---

## ✅ Confirmed Available Meta-Tools

Based on live API verification, the following meta-tools are available in Tool Router sessions:

| Meta-Tool | Available | Purpose |
|-----------|-----------|---------|
| **COMPOSIO_SEARCH_TOOLS** | ✅ Yes | Discover tools, get execution plan, check connections |
| **COMPOSIO_MULTI_EXECUTE_TOOL** | ✅ Yes | Execute discovered tools in parallel (up to 50) |
| **COMPOSIO_GET_TOOL_SCHEMAS** | ✅ Yes | Fetch complete input schemas for tools |
| **COMPOSIO_MANAGE_CONNECTIONS** | ✅ Yes | Initiate OAuth connections, get auth links |
| **COMPOSIO_REMOTE_WORKBENCH** | ✅ Yes | Python sandbox for bulk operations |
| **COMPOSIO_REMOTE_BASH_TOOL** | ✅ Yes | Bash command execution in sandbox |

---

## ❌ NOT Available (Rube-Specific Tools)

These tools from the Rube web app are **NOT** present in Tool Router:

| Tool | Status | Alternative |
|------|--------|-------------|
| `RUBE_CREATE_UPDATE_RECIPE` | ❌ Not found | No direct equivalent |
| `RUBE_EXECUTE_RECIPE` | ❌ Not found | No direct equivalent |
| `RUBE_FIND_RECIPE` | ❌ Not found | No direct equivalent |
| `RUBE_GET_RECIPE_DETAILS` | ❌ Not found | No direct equivalent |
| `RUBE_MANAGE_RECIPE_SCHEDULE` | ❌ Not found | No direct equivalent |
| `RUBE_WAIT_FOR_CONNECTIONS` | ❌ Not found | Use connection polling |

---

## 🔧 Session Configuration

When creating a session, the following configuration is returned:

```json
{
  "session_id": "trs_PTncEoK-r2ZE",
  "mcp": {
    "type": "http",
    "url": "https://backend.composio.dev/tool_router/trs_PTncEoK-r2ZE/mcp"
  },
  "tool_router_tools": [
    "COMPOSIO_MULTI_EXECUTE_TOOL",
    "COMPOSIO_REMOTE_WORKBENCH",
    "COMPOSIO_SEARCH_TOOLS",
    "COMPOSIO_GET_TOOL_SCHEMAS",
    "COMPOSIO_REMOTE_BASH_TOOL",
    "COMPOSIO_MANAGE_CONNECTIONS"
  ],
  "config": {
    "user_id": "ios_test_user",
    "manage_connections": {
      "enabled": true,
      "enable_wait_for_connections": false  // ⚠️ Not available
    },
    "workbench": {
      "proxy_execution_enabled": true
    }
  },
  "experimental": {
    "assistive_prompt": "When you choose to use Composio ToolRouter..."
  }
}
```

### Key Findings:
- ❌ **WAIT_FOR_CONNECTIONS is disabled** (`enable_wait_for_connections: false`)
- ✅ **Workbench proxy execution is enabled**
- ✅ **Manage connections is enabled**

---

## 📋 iOS System Prompt Recommendations

### **Section 1: Remove Recipe Instructions**

Since recipes are not available via Tool Router, **remove all recipe-related sections** from the iOS prompt:

❌ **Remove:**
- "Recipe Instructions" section
- "RECIPE EXECUTION" section  
- "RECIPE RECOVERY (CRITICAL - Healing Loop)" section
- All mentions of `RUBE_CREATE_UPDATE_RECIPE`
- All mentions of `RUBE_EXECUTE_RECIPE`
- All mentions of `RUBE_FIND_RECIPE`
- All mentions of `RUBE_GET_RECIPE_DETAILS`
- All mentions of `RUBE_MANAGE_RECIPE_SCHEDULE`

✅ **Replace with:**
```markdown
## AUTOMATIONS & RECIPES

For complex, repetitive workflows:
- Execute the task manually using the tool workflow
- Suggest: "Would you like to create an automation for this on rube.app?"
- Direct user to web app for recipe creation
```

---

### **Section 2: Remove Wait for Connections**

Since `RUBE_WAIT_FOR_CONNECTIONS` is not available:

❌ **Remove all mentions of:**
- `RUBE_WAIT_FOR_CONNECTIONS`
- `COMPOSIO_WAIT_FOR_CONNECTIONS`
- Auto-continuation after showing auth links

✅ **Replace workflow with:**
```markdown
2. **After COMPOSIO_SEARCH_TOOLS, proceed based on connection status:**
   - If connected: Execute immediately with COMPOSIO_MULTI_EXECUTE_TOOL
   - If not connected: 
     → Call COMPOSIO_MANAGE_CONNECTIONS
     → Show auth link as clickable markdown
     → STOP and wait for user to confirm "I've connected"
     → Then execute tools
```

---

### **Section 3: Workbench Instructions**

✅ **Keep these sections** but mark them as advanced:

```markdown
## ADVANCED: REMOTE TOOLS (Use Sparingly on iOS)

### COMPOSIO_REMOTE_WORKBENCH
**Use only when:**
- Processing 100+ items in parallel
- Complex data transformations requiring Python
- Bulk operations across many records

**Mobile Considerations:**
- Heavier latency than meta-tools
- User may not see progress during execution
- Prefer COMPOSIO_MULTI_EXECUTE_TOOL when possible

### COMPOSIO_REMOTE_BASH_TOOL
**Use only when:**
- File system operations required
- Data extraction with jq/awk/sed
- Processing large tool responses saved to sandbox

**Mobile Considerations:**
- Limited visibility into execution
- Prefer native tool execution
```

---

### **Section 4: Memory Instructions**

✅ **Keep memory instructions verbatim** — they're critical:

```markdown
**Memory Storage:**
- CRITICAL FORMAT: Memory must be a dictionary where keys are app names (strings) and values are arrays of strings
- CORRECT: `{"slack": ["Channel general has ID C1234567"], "gmail": ["John's email is john@example.com"]}`
- WRONG: Nested objects, key-value pairs, action logs
- STORE: ID mappings, entity relationships, user preferences
- DO NOT STORE: "sent email", "fetched data", temporary status
```

---

### **Section 5: iOS-Specific Adaptations**

✅ **Add iOS-specific context:**

```markdown
## iOS PLATFORM CONTEXT

- **Network Latency:** Prefer fewer, batched tool calls over many sequential calls
- **User Visibility:** After each major step, show progress updates
- **File Handling:** iOS doesn't have direct file system access like web
- **Background Limits:** All operations must complete while app is active
- **UI Threading:** Tool execution happens async; keep UI responsive

## PROHIBITED ON iOS

- ❌ Direct file system writes (no /tmp, /home/user paths)
- ❌ Long-running workbench tasks (>30 seconds may timeout)
- ❌ Assuming bash/shell environment exists
- ❌ Recipe creation/execution (not supported)
```

---

## 📐 Recommended iOS Prompt Structure

### **Total Target Size:** ~2,500 tokens

| Section | Tokens | Keep/Modify/Remove |
|---------|--------|-------------------|
| Role & Mandate | 200 | ✅ Keep |
| When to Use/Not Use Tools | 150 | ✅ Keep |
| Mandatory Tool Workflow | 300 | ⚠️ Modify (remove WAIT) |
| ~~Recipe Instructions~~ | ~~800~~ | ❌ Remove completely |
| Critical Rules | 200 | ✅ Keep |
| Memory Storage | 250 | ✅ Keep verbatim |
| Security Rules (Workbench) | 150 | ⚠️ Mark as advanced |
| User Confirmation | 200 | ✅ Keep (via ExecutionMode) |
| Response Format | 150 | ✅ Keep |
| Forbidden/Preferred | 100 | ✅ Keep |
| **iOS-Specific Context** | 150 | ✅ **ADD NEW** |
| Dynamic Context | 100 | ✅ Keep (timezone, mode) |
| Execution Mode Fragment | 200 | ✅ Keep (YOLO/Safe) |
| **TOTAL** | **~2,350 tokens** | ✅ **Mobile-optimized** |

---

## 🚀 Next Steps

1. **Remove Recipe Code:**
   - Delete all recipe-related sections from the prompt
   - Remove recipe examples from workflow patterns

2. **Update Connection Workflow:**
   - Remove `WAIT_FOR_CONNECTIONS` references
   - Add clear "wait for user confirmation" step

3. **Add iOS Context:**
   - Include platform-specific constraints
   - Add mobile best practices

4. **Test Against Live API:**
   - Verify `COMPOSIO_SEARCH_TOOLS` returns plans
   - Confirm `COMPOSIO_MANAGE_CONNECTIONS` works
   - Test `COMPOSIO_MULTI_EXECUTE_TOOL` with memory

5. **Update NativeChatService.swift:**
   - Implement the revised prompt structure
   - Add iOS-specific error handling
   - Integrate ExecutionModeSettings

---

## 🔗 API Endpoints Reference

```bash
# Create session
POST https://backend.composio.dev/api/v3/tool_router/session
Body: {"user_id": "user@example.com"}

# Get session tools
GET https://backend.composio.dev/api/v3/tool_router/session/{session_id}/tools

# Execute meta-tool
POST https://backend.composio.dev/api/v3/tool_router/session/{session_id}/execute_meta
Body: {"tool_name": "COMPOSIO_SEARCH_TOOLS", "arguments": {...}}

# Execute regular tool
POST https://backend.composio.dev/api/v3/tool_router/session/{session_id}/execute
Body: {"tool_name": "GMAIL_SEND_EMAIL", "arguments": {...}}

# Create auth link
POST https://backend.composio.dev/api/v3/tool_router/session/{session_id}/link
Body: {"toolkit": "gmail"}
```

---

## ✅ Verification Checklist

- [x] API v3 endpoints work
- [x] Session creation successful
- [x] 6 meta-tools confirmed available
- [x] Workbench enabled
- [x] Manage connections enabled
- [x] Wait for connections NOT available
- [x] Recipes NOT available
- [x] Memory format documented
- [x] iOS constraints identified

---

**Conclusion:** The iOS app should use Tool Router meta-tools WITHOUT recipe functionality. The prompt should be ~2,350 tokens, focused on core execution workflow with iOS-specific adaptations.
