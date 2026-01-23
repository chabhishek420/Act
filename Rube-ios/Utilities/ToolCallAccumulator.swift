//
//  ToolCallAccumulator.swift
//  Rube-ios
//

import Foundation

/// Internal representation of a tool call part from streaming delta
struct ToolCallPart {
    let index: Int
    let id: String?
    let name: String?
    let argumentsPart: String?
}

/// Accumulates tool call delta parts into finalized tool calls
class ToolCallAccumulator {
    
    private var toolCalls: [Int: (id: String?, name: String?, arguments: String)] = [:]
    
    func add(_ part: ToolCallPart) {
        var current = toolCalls[part.index] ?? (id: nil, name: nil, arguments: "")
        
        if let id = part.id {
            current.id = id
        }
        if let name = part.name {
            current.name = name
        }
        if let arguments = part.argumentsPart {
            current.arguments += arguments
        }
        
        toolCalls[part.index] = current
    }
    
    struct FinalizedToolCall {
        let index: Int
        let id: String
        let name: String
        let arguments: [String: AnyCodable]
    }
    
    func finalize() -> [FinalizedToolCall] {
        return toolCalls.compactMap { (index, data) -> FinalizedToolCall? in
            guard let id = data.id, let name = data.name else { return nil }
            
            let argsData = data.arguments.data(using: .utf8) ?? Data()
            let decodedArgs = (try? JSONDecoder().decode([String: AnyCodable].self, from: argsData)) ?? [:]
            
            return FinalizedToolCall(
                index: index,
                id: id,
                name: name,
                arguments: decodedArgs
            )
        }
        .sorted { $0.index < $1.index }
    }
}
