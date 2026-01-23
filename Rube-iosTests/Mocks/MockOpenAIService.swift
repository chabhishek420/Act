import Foundation
import SwiftOpenAI
@testable import Rube_ios

final class MockOpenAIService: OpenAIStreamService, @unchecked Sendable {
    var responsesToStream: [ChatCompletionChunkObject] = []
    var sequentialResponses: [[ChatCompletionChunkObject]] = []
    var modelsToReturn: [String] = ["gpt-4", "gpt-3.5-turbo"]
    private var callCount = 0
    var errorToThrow: Error?
    
    func startStreamedChat(parameters: ChatCompletionParameters) async throws -> AsyncThrowingStream<ChatCompletionChunkObject, Error> {
        if let error = errorToThrow {
            throw error
        }
        
        let responses = sequentialResponses.indices.contains(callCount) ? sequentialResponses[callCount] : responsesToStream
        callCount += 1
        
        return AsyncThrowingStream { continuation in
            for response in responses {
                continuation.yield(response)
            }
            continuation.finish()
        }
    }

    func listModels() async throws -> [String] {
        return modelsToReturn
    }
}

extension ChatCompletionChunkObject {
    static func mock(json: String) -> ChatCompletionChunkObject {
        let decoder = JSONDecoder()
        return try! decoder.decode(ChatCompletionChunkObject.self, from: json.data(using: .utf8)!)
    }
    
    static func mock(content: String) -> ChatCompletionChunkObject {
        let payload: [String: Any] = [
            "id": "chatcmpl-123",
            "object": "chat.completion.chunk",
            "created": 1234567,
            "model": "gpt-4",
            "choices": [
                [
                    "index": 0,
                    "delta": [
                        "content": content
                    ]
                ]
            ]
        ]
        let data = try! JSONSerialization.data(withJSONObject: payload)
        return try! JSONDecoder().decode(ChatCompletionChunkObject.self, from: data)
    }
    
    static func mockToolCall(id: String, name: String, arguments: String) -> ChatCompletionChunkObject {
        let payload: [String: Any] = [
            "id": "chatcmpl-tool",
            "object": "chat.completion.chunk",
            "created": 1234567,
            "model": "gpt-4",
            "choices": [
                [
                    "index": 0,
                    "delta": [
                        "tool_calls": [
                            [
                                "index": 0,
                                "id": id,
                                "type": "function",
                                "function": [
                                    "name": name,
                                    "arguments": arguments
                                ]
                            ]
                        ]
                    ]
                ]
            ]
        ]
        let data = try! JSONSerialization.data(withJSONObject: payload)
        return try! JSONDecoder().decode(ChatCompletionChunkObject.self, from: data)
    }
}
