@preconcurrency import SwiftOpenAI

/// A simplified protocol for OpenAI streaming functionality, 
/// allowing for easier mocking in tests while providing everything NativeChatService needs.
protocol OpenAIStreamService: Sendable {
    func startStreamedChat(parameters: ChatCompletionParameters) async throws -> AsyncThrowingStream<ChatCompletionChunkObject, Error>
    func listModels() async throws -> [String]
}

/// A wrapper that adapts any OpenAIService to OpenAIStreamService.
/// This avoids tricky runtime existential casts.
struct OpenAIServiceWrapper: OpenAIStreamService {
    let service: OpenAIService
    
    func startStreamedChat(parameters: ChatCompletionParameters) async throws -> AsyncThrowingStream<ChatCompletionChunkObject, Error> {
        return try await service.startStreamedChat(parameters: parameters)
    }

    func listModels() async throws -> [String] {
        let response = try await service.listModels()
        return response.data.map { $0.id }
    }
}
