import XCTest
import Composio
@testable import Rube_ios

@MainActor
final class ToolRouterIntegrationTests: XCTestCase {

    var composioManager: ComposioManager!

    override func setUp() {
        super.setUp()
        // Set up API key from test configuration
        setenv("COMPOSIO_API_KEY", "ak_zADvaco59jaMiHrqpjj4", 1)
        composioManager = ComposioManager.shared
    }

    override func tearDown() {
        composioManager.clearSession()
        unsetenv("COMPOSIO_API_KEY")
        super.tearDown()
    }

    func testToolRouterWorkflow() async throws {
        let userId = "ios_e2e_test_user"

        // 1. Create Session
        let session = try await composioManager.getSession(for: userId, conversationId: "test_conversation")
        XCTAssertFalse(session.sessionId.isEmpty)
        print("✅ Session Created: \(session.sessionId)")

        // 2. Fetch Meta Tools
        // Note: getMetaTools intentionally returns empty to avoid iOS memory limits.
        // Meta-tools are defined in system prompt and executed directly via executeMetaTool.
        let metaTools = try await composioManager.getMetaTools(sessionId: session.sessionId)
        XCTAssertTrue(metaTools.isEmpty, "Meta-tools intentionally not fetched in iOS (defined in system prompt)")
        print("✅ Meta Tools Fetched: \(metaTools.count)")

        // 3. Search for a tool
        let searchResult = try await composioManager.executeMetaTool(
            "COMPOSIO_SEARCH_TOOLS",
            sessionId: session.sessionId,
            arguments: [
                "queries": [["use_case": "star a repo on github"]]
            ]
        )

        XCTAssertTrue(searchResult.isSuccess)

        // Verify tool schemas are returned in search
        // Access data directly and convert AnyCodable values to Any
        let data = searchResult.data.mapValues { $0.value }
        let toolSchemas = data["tool_schemas"] as? [String: Any]
        XCTAssertNotNil(toolSchemas)
        XCTAssertTrue(toolSchemas?.keys.contains(where: { $0.contains("STAR") }) ?? false)
        print("✅ Search Successful, found \(toolSchemas?.count ?? 0) schemas")
    }
}
