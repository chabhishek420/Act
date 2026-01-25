# Rube iOS - Task List

**Last Updated:** 2026-01-23  
**Total Estimated Time:** 24 hours

## 🟢 Integration Testing (In Progress)
- [ ] **Fix Appwrite Integration Tests**
  - [x] Add anonymous authentication for tests
  - [ ] Resolve 'No permissions provided for action create' error
- [ ] **Verify Composio Tool Execution**
  - [x] Switch to Gemini model to avoid 429 rate limits
  - [x] Fix GITHUB_STAR_A_REPOSITORY -> GITHUB_ACTIVITY_STAR_REPO_FOR_AUTHENTICATED_USER
  - [ ] Successfully execute direct tool call

---

## 🔴 Critical Fixes (Week 1) - 6 hours

### Thread Safety
- [x] **Fix `@unchecked Sendable` in NativeChatService** (2h)
  - Location: `Services/NativeChatService.swift:32`
  - Action: Replace with `@MainActor` and `ObservableObject`
  - Risk: Race conditions, random crashes

- [x] **Fix `@unchecked Sendable` in ComposioManager** (30m)
  - Location: `Services/ComposioManager.swift:15`
  - Action: Use `@MainActor` or convert to actor
  - Risk: Thread-unsafe singleton

### Security
- [ ] **Move API keys to Keychain** (1h)
  - Location: `Config/ComposioConfig.swift:31`
  - Action: Create KeychainManager, store keys securely
  - Risk: App Store rejection, key exposure

- [ ] **Remove hardcoded keys from xcconfig** (30m)
  - Location: `Secrets.xcconfig`
  - Action: Use build-time injection or Keychain

### Network Resilience
- [ ] **Add retry logic with exponential backoff** (1.5h)
  - Location: `Services/NativeChatService.swift:196`
  - Action: Create `executeWithRetry()` helper
  - Pattern: 3 attempts, 2s/4s/8s delays

### Session Management
- [ ] **Add session persistence** (30m)
  - Location: `Services/ComposioManager.swift:58`
  - Action: Cache sessionId in UserDefaults
  - Benefit: Faster startup, fewer API calls

---

## 🟡 Appwrite Enhancements (Week 2) - 8 hours

### Realtime API
- [ ] **Add Realtime subscription for messages** (2h)
  - Location: `Services/AppwriteConversationService.swift`
  - Action: Subscribe to message changes
  - Benefit: Live updates, multi-device sync
  ```swift
  // Add to AppwriteConversationService
  func subscribeToConversation(_ id: String)
  func unsubscribe()
  ```

- [ ] **Add typing indicators** (1h)
  - Depends on: Realtime subscription
  - Action: Broadcast typing state

### Storage API
- [ ] **Create AppwriteStorageService** (2h)
  - Action: New file `Services/AppwriteStorageService.swift`
  - Features: Upload/download files, image compression

- [ ] **Add file attachments to Message model** (1h)
  - Location: `Models/Message.swift`
  - Action: Add `attachments: [Attachment]?` property

- [ ] **Implement file picker in ChatView** (1h)
  - Location: `Views/Chat/ChatView.swift`
  - Action: Add photo Library picker, camera access

### Advanced Queries
- [ ] **Implement cursor-based pagination** (30m)
  - Location: `Services/AppwriteConversationService.swift:81`
  - Action: Replace `limit(100)` with `cursorAfter(lastId)`

- [ ] **Add full-text search** (30m)
  - Action: Add `searchMessages(_ query: String)` method
  - Uses: `Query.search("content", query)`

---

## 🟡 Composio Enhancements (Week 2) - 6 hours

### Session Management
- [ ] **Add session persistence with validation** (1h)
  - Location: `Services/ComposioManager.swift`
  - Action: Save to UserDefaults, validate on restore

- [ ] **Add session expiry handling** (30m)
  - Action: Track creation time, refresh after 1 hour

### Authentication
- [ ] **Add manual connection flow for onboarding** (1.5h)
  - Location: New `Views/Settings/ConnectionsView.swift`
  - Action: List connected accounts, add new connections

- [ ] **Implement white-label OAuth** (2h)
  - Action: Create custom OAuth apps in Composio Console
  - Benefit: Your branding on consent screens

### Error Handling
- [ ] **Add rate limit handling** (30m)
  - Location: `Services/ComposioManager.swift:152`
  - Action: Detect 429, wait and retry

- [ ] **Improve tool execution error messages** (30m)
  - Location: `Services/NativeChatService.swift:312`
  - Action: Parse Composio error codes, show friendly messages

---

## 🟢 Production Polish (Week 3) - 4 hours

### Monitoring
- [ ] **Add Crashlytics** (1h)
  - Action: Add Firebase SDK, configure crash reporting

- [ ] **Add analytics events** (1h)
  - Events: Message sent, tool executed, OAuth connected

### UX Improvements
- [ ] **Add error recovery UI** (1h)
  - Action: "Retry" button for failed messages
  - Location: `Views/Chat/ChatView.swift`

- [ ] **Add pull-to-refresh** (30m)
  - Location: `Views/Chat/ChatView.swift`
  - Action: Refresh conversations list

- [ ] **Add empty states** (30m)
  - Action: Empty conversation, no connections, etc.

---

## 📋 Task Summary

| Category | Tasks | Estimated Time | Priority |
|----------|-------|----------------|----------|
| Critical Fixes | 6 | 6 hours | 🔴 This Week |
| Appwrite | 8 | 8 hours | 🟡 Next Week |
| Composio | 6 | 6 hours | 🟡 Next Week |
| Production Polish | 5 | 4 hours | 🟢 Week 3 |
| **Total** | **25** | **24 hours** | - |

---

## 📅 Suggested Timeline

### Week 1: Critical Fixes
- Day 1: Thread safety (2.5h)
- Day 2: Security + retry logic (2h)
- Day 3: Session persistence (1.5h)

### Week 2: Feature Enhancements
- Day 4-5: Appwrite Realtime + Storage (4h)
- Day 6: Appwrite queries + Composio session (2h)
- Day 7: Composio auth + errors (2h)

### Week 3: Production Polish
- Day 8: Crashlytics + analytics (2h)
- Day 9: UX improvements (2h)

---

## 🎯 Definition of Done

Each task is complete when:
- [ ] Code implemented and compiles
- [ ] Works on device (not just simulator)
- [ ] Error cases handled
- [ ] Logging added for debugging
- [ ] Tested with real API calls

---

## 📝 Notes

**Dependencies:**
- Keychain task blocks security tasks
- Realtime blocks typing indicators
- Storage blocks file attachments

**Testing Required:**
- Thread safety: Run under stress, check for crashes
- Retry logic: Test with airplane mode toggle
- Realtime: Test multi-device sync

**API Limits to Watch:**
- Composio: 100 calls/min (free tier)
- Appwrite: 75K MAU (free tier)
- Custom LLM: Unknown limits
