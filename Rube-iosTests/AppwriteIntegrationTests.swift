import Testing
import Foundation
@testable import Rube_ios

@Suite("Appwrite Persistence Tests")
struct AppwriteIntegrationTests {
    
    @Test("Verify Message Persistence (Save and Load)")
    func testMessagePersistence() async throws {
        // Ensure we starting with a clean session
        try? await account.deleteSession(sessionId: "current")
        
        // Use a real user for the test to avoid permission issues with anonymous sessions
        let testEmail = "test_\(UUID().uuidString.prefix(4))@example.com"
        let testPassword = "Password123!"
        
        // Sign up and sign in automatically
        try await AuthService.shared.signUp(email: testEmail, password: testPassword, name: "Test User")
        
        let conversationService = AppwriteConversationService()
        conversationService.testUserId = "test_integration_user"
        
        let testConversationId = "test_conv_" + UUID().uuidString.prefix(8)
        let testMessages = [
            Message(content: "Hello from test", role: .user),
            Message(content: "Hello back", role: .assistant)
        ]
        
        // 1. Save messages
        let savedId = await conversationService.saveConversation(
            id: testConversationId,
            messages: testMessages
        )
        
        #expect(!savedId.isEmpty)
        
        // 2. Clear cache and reload
        conversationService.clearMessageCache()
        let loadedMessages = await conversationService.getMessages(conversationId: savedId)
        
        // 3. Verify
        #expect(loadedMessages.count >= 2)
        #expect(loadedMessages.contains(where: { $0.content == "Hello from test" }))
        #expect(loadedMessages.contains(where: { $0.content == "Hello back" }))
        
        print("✅ Appwrite: Successfully saved and reloaded messages for ID: \(savedId)")
    }
}
