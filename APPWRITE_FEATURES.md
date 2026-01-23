# Appwrite Features & Implementation Guide

**Project:** Rube iOS  
**Current Usage:** ~30% of Appwrite capabilities  
**Potential:** 10x improvement with full feature adoption

---

## Currently Implemented ✅

### 1. Authentication
```swift
// AuthService.swift
let account = Account(client)
try await account.createEmailPasswordSession(email: email, password: password)
```
- ✅ Email/password login
- ✅ JWT token generation
- ✅ Session management
- ❌ OAuth (Google, Apple, GitHub)
- ❌ MFA
- ❌ Anonymous sessions

### 2. Databases
```swift
// AppwriteConversationService.swift
let databases = Databases(client)
try await databases.createDocument(...)
```
- ✅ Conversations collection
- ✅ Messages collection
- ✅ User-scoped permissions
- ❌ Realtime subscriptions
- ❌ Full-text search
- ❌ Advanced queries

---

## High-Priority Features (Implement First) 🔥

### 3. Realtime API - **2 hours, HUGE impact**

**What it does:** Live updates without polling

**Implementation:**
```swift
// Add to AppwriteConversationService.swift

import Appwrite

class AppwriteConversationService {
    private let realtime: Realtime
    private var messageSubscription: RealtimeSubscription?
    
    init() {
        self.realtime = Realtime(AppwriteClient.client)
    }
    
    // Subscribe to conversation updates
    func subscribeToConversation(_ conversationId: String, 
                                 onUpdate: @escaping (Message) -> Void) {
        let channel = "databases.\(AppwriteDatabase.databaseId).collections.\(AppwriteDatabase.messagesCollection).documents"
        
        messageSubscription = realtime.subscribe(channels: [channel]) { response in
            guard let events = response.events else { return }
            
            // Check if it's our conversation
            if events.contains(where: { $0.contains("documents.\(conversationId)") }) {
                if let payload = response.payload {
                    // Parse new message
                    if let message = self.parseMessage(payload) {
                        Task { @MainActor in
                            onUpdate(message)
                        }
                    }
                }
            }
        }
    }
    
    func unsubscribe() {
        messageSubscription?.close()
    }
    
    private func parseMessage(_ payload: [String: Any]) -> Message? {
        guard let id = payload["$id"] as? String,
              let content = payload["content"] as? String,
              let roleStr = payload["role"] as? String else {
            return nil
        }
        
        let role = MessageRole(rawValue: roleStr) ?? .assistant
        return Message(id: id, content: content, role: role)
    }
}
```

**Usage in ChatViewModel:**
```swift
class ChatViewModel {
    func startRealtimeUpdates() {
        conversationService.subscribeToConversation(currentConversationId) { [weak self] newMessage in
            self?.messages.append(newMessage)
        }
    }
    
    deinit {
        conversationService.unsubscribe()
    }
}
```

**Benefits:**
- ✅ Multi-device sync
- ✅ Instant message updates
- ✅ Typing indicators possible
- ✅ No polling overhead

---

### 4. Storage API - **4 hours, HIGH impact**

**What it does:** Store files, images, voice messages

**Setup:**
```bash
# Create bucket in Appwrite Console
# Bucket ID: chat-attachments
# Permissions: User read/write
# Max file size: 50MB
# Allowed extensions: jpg, png, pdf, mp3, m4a
```

**Implementation:**
```swift
// Create new file: Services/AppwriteStorageService.swift

import Appwrite
import Foundation

@Observable
final class AppwriteStorageService {
    private let storage: Storage
    private let bucketId = "chat-attachments"
    
    init() {
        self.storage = Storage(AppwriteClient.client)
    }
    
    // Upload file
    func uploadFile(_ data: Data, 
                   filename: String,
                   mimeType: String) async throws -> String {
        let file = InputFile.fromData(data, 
                                     filename: filename, 
                                     mimeType: mimeType)
        
        let uploadedFile = try await storage.createFile(
            bucketId: bucketId,
            fileId: ID.unique(),
            file: file
        )
        
        return uploadedFile.id
    }
    
    // Get file URL
    func getFileURL(_ fileId: String) -> URL {
        let endpoint = Config.appwriteEndpoint
        let projectId = Config.appwriteProjectId
        return URL(string: "\(endpoint)/storage/buckets/\(bucketId)/files/\(fileId)/view?project=\(projectId)")!
    }
    
    // Download file
    func downloadFile(_ fileId: String) async throws -> Data {
        let bytes = try await storage.getFileDownload(
            bucketId: bucketId,
            fileId: fileId
        )
        return Data(bytes)
    }
    
    // Delete file
    func deleteFile(_ fileId: String) async throws {
        try await storage.deleteFile(
            bucketId: bucketId,
            fileId: fileId
        )
    }
}
```

**Update Message Model:**
```swift
// Models/Message.swift
struct Message: Identifiable, Equatable {
    let id: String
    let content: String
    let role: MessageRole
    let timestamp: Date
    var toolCalls: [ToolCall]?
    var attachments: [Attachment]? // NEW
}

struct Attachment: Identifiable, Codable, Equatable {
    let id: String
    let filename: String
    let mimeType: String
    let fileId: String // Appwrite file ID
    let size: Int
}
```

**Usage in ChatView:**
```swift
struct ChatView: View {
    @State private var showImagePicker = false
    @State private var selectedImage: UIImage?
    
    var body: some View {
        VStack {
            // ... messages
            
            HStack {
                Button(action: { showImagePicker = true }) {
                    Image(systemName: "photo")
                }
                TextField("Message", text: $inputText)
                Button("Send", action: sendMessage)
            }
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(image: $selectedImage)
        }
        .onChange(of: selectedImage) { _, newImage in
            if let image = newImage {
                Task { await uploadAndSendImage(image) }
            }
        }
    }
    
    func uploadAndSendImage(_ image: UIImage) async {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return }
        
        do {
            let fileId = try await storageService.uploadFile(
                data,
                filename: "image_\(Date().timeIntervalSince1970).jpg",
                mimeType: "image/jpeg"
            )
            
            let attachment = Attachment(
                id: UUID().uuidString,
                filename: "image.jpg",
                mimeType: "image/jpeg",
                fileId: fileId,
                size: data.count
            )
            
            // Send message with attachment
            await viewModel.sendMessage("Sent an image", attachments: [attachment])
        } catch {
            print("Upload failed: \(error)")
        }
    }
}
```

---

### 5. Advanced Queries - **1 hour, MEDIUM impact**

**What it does:** Search, filter, paginate efficiently

**Implementation:**
```swift
// Update AppwriteConversationService.swift

// Full-text search
func searchMessages(_ query: String, conversationId: String) async -> [Message] {
    do {
        let result = try await databases.listDocuments(
            databaseId: AppwriteDatabase.databaseId,
            collectionId: AppwriteDatabase.messagesCollection,
            queries: [
                Query.equal("conversationId", value: conversationId),
                Query.search("content", query),
                Query.orderDesc("createdAt"),
                Query.limit(50)
            ]
        )
        
        return result.documents.compactMap { parseMessage($0) }
    } catch {
        print("Search failed: \(error)")
        return []
    }
}

// Cursor-based pagination (better than offset)
func loadMoreMessages(conversationId: String, 
                     after lastMessageId: String? = nil) async -> [Message] {
    var queries: [String] = [
        Query.equal("conversationId", value: conversationId),
        Query.orderDesc("createdAt"),
        Query.limit(20)
    ]
    
    if let lastId = lastMessageId {
        queries.append(Query.cursorAfter(lastId))
    }
    
    do {
        let result = try await databases.listDocuments(
            databaseId: AppwriteDatabase.databaseId,
            collectionId: AppwriteDatabase.messagesCollection,
            queries: queries
        )
        
        return result.documents.compactMap { parseMessage($0) }
    } catch {
        return []
    }
}

// Date range queries
func getMessagesByDateRange(conversationId: String, 
                           from: Date, 
                           to: Date) async -> [Message] {
    let formatter = ISO8601DateFormatter()
    
    let result = try? await databases.listDocuments(
        databaseId: AppwriteDatabase.databaseId,
        collectionId: AppwriteDatabase.messagesCollection,
        queries: [
            Query.equal("conversationId", value: conversationId),
            Query.greaterThanEqual("createdAt", value: formatter.string(from: from)),
            Query.lessThanEqual("createdAt", value: formatter.string(from: to)),
            Query.orderDesc("createdAt")
        ]
    )
    
    return result?.documents.compactMap { parseMessage($0) } ?? []
}

// Complex filters
func getErrorMessages(conversationId: String) async -> [Message] {
    let result = try? await databases.listDocuments(
        databaseId: AppwriteDatabase.databaseId,
        collectionId: AppwriteDatabase.messagesCollection,
        queries: [
            Query.equal("conversationId", value: conversationId),
            Query.and([
                Query.equal("role", value: "assistant"),
                Query.contains("content", value: "error")
            ])
        ]
    )
    
    return result?.documents.compactMap { parseMessage($0) } ?? []
}
```

---

## Medium-Priority Features 🟡

### 6. Messaging API - **3 hours**

**What it does:** Push notifications, emails, SMS

**Setup in Appwrite Console:**
1. Enable Messaging
2. Add provider (APNs for iOS)
3. Upload APNs certificate
4. Create topics

**Implementation:**
```swift
// Services/AppwriteMessagingService.swift

import Appwrite

class AppwriteMessagingService {
    private let messaging: Messaging
    
    init() {
        self.messaging = Messaging(AppwriteClient.client)
    }
    
    // Send push notification
    func sendPushNotification(title: String, 
                             body: String, 
                             userId: String) async throws {
        try await messaging.createPush(
            messageId: ID.unique(),
            subject: title,
            content: body,
            users: [userId]
        )
    }
    
    // Send email
    func sendEmail(subject: String, 
                  content: String, 
                  userId: String) async throws {
        try await messaging.createEmail(
            messageId: ID.unique(),
            subject: subject,
            content: content,
            users: [userId]
        )
    }
    
    // Subscribe to topic
    func subscribeToTopic(_ topicId: String) async throws {
        try await messaging.createSubscriber(
            topicId: topicId,
            subscriberId: ID.unique(),
            targetId: AuthService.shared.userId ?? ""
        )
    }
}
```

**Use Cases:**
```swift
// Notify when tool execution completes
func notifyToolComplete(toolName: String) async {
    try? await messagingService.sendPushNotification(
        title: "Task Complete",
        body: "\(toolName) finished successfully",
        userId: AuthService.shared.userId ?? ""
    )
}

// Daily conversation summary
func sendDailySummary() async {
    let summary = generateSummary()
    try? await messagingService.sendEmail(
        subject: "Your Daily Digest",
        content: summary,
        userId: AuthService.shared.userId ?? ""
    )
}
```

---

### 7. Functions - **5 hours**

**What it does:** Serverless background tasks

**Create Function in Appwrite Console:**
```javascript
// functions/summarize-conversation/index.js

import { Client, Databases } from 'node-appwrite';

export default async ({ req, res, log, error }) => {
  const client = new Client()
    .setEndpoint(process.env.APPWRITE_ENDPOINT)
    .setProject(process.env.APPWRITE_PROJECT_ID)
    .setKey(process.env.APPWRITE_API_KEY);

  const databases = new Databases(client);
  const conversationId = req.body.conversationId;

  // Get all messages
  const messages = await databases.listDocuments(
    'rube_database',
    'messages',
    [Query.equal('conversationId', conversationId)]
  );

  // Generate summary (call LLM)
  const summary = await generateSummary(messages.documents);

  // Save summary
  await databases.updateDocument(
    'rube_database',
    'conversations',
    conversationId,
    { summary: summary }
  );

  return res.json({ success: true, summary });
};
```

**Trigger from iOS:**
```swift
// Services/AppwriteFunctionsService.swift

class AppwriteFunctionsService {
    private let functions: Functions
    
    init() {
        self.functions = Functions(AppwriteClient.client)
    }
    
    func summarizeConversation(_ conversationId: String) async throws -> String {
        let execution = try await functions.createExecution(
            functionId: "summarize-conversation",
            body: "{\"conversationId\": \"\(conversationId)\"}"
        )
        
        // Parse response
        if let responseData = execution.responseBody.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
           let summary = json["summary"] as? String {
            return summary
        }
        
        throw NSError(domain: "FunctionError", code: -1)
    }
}
```

---

## Low-Priority Features (Nice to Have) 🟢

### 8. OAuth 2.0 - **2 hours**

```swift
// Add to AuthService.swift

func signInWithGoogle() async throws {
    try await account.createOAuth2Session(
        provider: "google",
        success: "rube://oauth/success",
        failure: "rube://oauth/failure"
    )
}

func signInWithApple() async throws {
    try await account.createOAuth2Session(
        provider: "apple",
        success: "rube://oauth/success"
    )
}
```

### 9. Teams - **3 hours**

```swift
// Shared workspaces
let teams = Teams(client)
let team = try await teams.create(
    teamId: ID.unique(),
    name: "Project Team"
)

// Add member
try await teams.createMembership(
    teamId: team.id,
    email: "user@example.com",
    roles: ["member"]
)
```

### 10. Webhooks - **2 hours**

**Configure in Console:**
- Event: `databases.*.collections.messages.documents.*.create`
- URL: `https://your-analytics.com/webhook`

**Receives:**
```json
{
  "event": "databases.messages.documents.create",
  "payload": {
    "$id": "msg_123",
    "conversationId": "conv_456",
    "content": "Hello",
    "role": "user"
  }
}
```

---

## Implementation Roadmap

### Week 1: Foundation (8 hours)
- [x] ✅ Auth (already done)
- [x] ✅ Databases (already done)
- [ ] 🔥 Realtime (2h)
- [ ] 🔥 Advanced Queries (1h)
- [ ] 🔥 Storage (4h)

### Week 2: Engagement (8 hours)
- [ ] 🟡 Messaging (3h)
- [ ] 🟡 Functions (5h)

### Week 3: Polish (7 hours)
- [ ] 🟢 OAuth (2h)
- [ ] 🟢 Teams (3h)
- [ ] 🟢 Webhooks (2h)

**Total: 23 hours for 10 features**

---

## Quick Wins (< 1 hour each)

1. **Enable Realtime** - Biggest impact
2. **Add search** - User delight
3. **Cursor pagination** - Better performance
4. **Push notifications** - Re-engagement

---

## Resources

- [Appwrite Docs](https://appwrite.io/docs)
- [Swift SDK Reference](https://appwrite.io/docs/sdks#client)
- [Realtime Guide](https://appwrite.io/docs/apis/realtime)
- [Storage Guide](https://appwrite.io/docs/products/storage)
- [Functions Guide](https://appwrite.io/docs/products/functions)

---

**Next Step:** Implement Realtime API (2 hours, 10x impact) 🚀
