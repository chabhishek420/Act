import Testing
import Foundation
import SwiftData
@testable import Rube_ios

@Suite("SwiftData Consistency Tests")
struct DatabaseConsistencyTests {
    
    @MainActor
    @Test("Verify in-memory model container isolation")
    func testModelContainerIsolation() throws {
        // Arrange
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: MessageModel.self, ConversationModel.self, configurations: config)
        let context = container.mainContext
        
        // Act
        let message = MessageModel(content: "Test message", role: "user")
        context.insert(message)
        try context.save()
        
        // Assert
        let descriptor = FetchDescriptor<MessageModel>()
        let results = try context.fetch(descriptor)
        #expect(results.count == 1)
        #expect(results.first?.content == "Test message")
    }
}
