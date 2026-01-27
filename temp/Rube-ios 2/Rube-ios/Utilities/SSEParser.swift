//
//  SSEParser.swift
//  Rube-ios
//
//  Server-Sent Events parser for chat streaming
//

import Foundation

enum SSEEvent {
    case textDelta(String)
    case toolInputStart(id: String, name: String)
    case toolInputAvailable(id: String, input: [String: Any])
    case toolOutputAvailable(id: String, output: Any)
    case connectionRequest(ConnectionRequest)
    case done
    case error(String)
}

struct ConnectionRequest {
    let provider: String
    let fields: [[String: Any]]
    let authConfigId: String?
    let logoUrl: String?
    let oauthUrl: String?

    var isOAuthOnly: Bool {
        fields.isEmpty && oauthUrl != nil
    }
}

struct SSEParser {
    /// Parse a single SSE line into an event
    static func parse(line: String) -> SSEEvent? {
        // SSE lines start with "data: "
        guard line.hasPrefix("data: ") else { return nil }

        let data = String(line.dropFirst(6)) // Remove "data: " prefix

        // Check for done signal
        if data == "[DONE]" {
            return .done
        }

        // Parse JSON
        guard let jsonData = data.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let type = json["type"] as? String else {
            return nil
        }

        // Log ALL events for debugging
        print("📨 SSE EVENT: type=\(type)")

        switch type {
        case "text-delta":
            if let delta = json["delta"] as? String {
                return .textDelta(delta)
            }

        case "tool-input-start":
            if let id = json["toolCallId"] as? String,
               let name = json["toolName"] as? String {
                print("🔧 TOOL START: \(name)")
                return .toolInputStart(id: id, name: name)
            }

        case "tool-input-available":
            if let id = json["toolCallId"] as? String,
               let input = json["input"] as? [String: Any] {
                return .toolInputAvailable(id: id, input: input)
            }

        case "tool-output-available":
            if let id = json["toolCallId"] as? String,
               let toolName = json["toolName"] as? String,
               let output = json["output"] {

                print("🔧 TOOL OUTPUT: \(toolName)")
                if let outputData = try? JSONSerialization.data(withJSONObject: output, options: .prettyPrinted),
                   let outputStr = String(data: outputData, encoding: .utf8) {
                    print("📦 OUTPUT JSON:\n\(outputStr)")
                }

                // Check if this is a connection request from REQUEST_USER_INPUT tool
                if let outputDict = output as? [String: Any],
                   let outputType = outputDict["type"] as? String,
                   outputType == "user_input_request" {

                    let provider = outputDict["provider"] as? String ?? "Unknown"
                    let fields = outputDict["fields"] as? [[String: Any]] ?? []
                    let authConfigId = outputDict["authConfigId"] as? String
                    let logoUrl = outputDict["logoUrl"] as? String
                    let oauthUrl = outputDict["oauthUrl"] as? String

                    let request = ConnectionRequest(
                        provider: provider,
                        fields: fields,
                        authConfigId: authConfigId,
                        logoUrl: logoUrl,
                        oauthUrl: oauthUrl
                    )
                    return .connectionRequest(request)
                }

                // Check if this is a connection management tool output
                // Supports both COMPOSIO_MANAGE_CONNECTIONS and RUBE_MANAGE_CONNECTIONS
                // The output can have multiple structures:
                // 1. Direct auth_url (custom flow)
                // 2. Nested data.results with redirect_url (official Composio format)
                // 3. Wrapped in content[0].text as JSON string (official Rube format)
                if toolName == "COMPOSIO_MANAGE_CONNECTIONS" || toolName == "RUBE_MANAGE_CONNECTIONS" {
                    print("✅ MATCHED connection tool: \(toolName)")

                    guard let outputDict = output as? [String: Any] else {
                        print("❌ Output is not a dictionary")
                        return .toolOutputAvailable(id: id, output: output)
                    }

                    var provider = "App"
                    var oauthUrl: String?
                    var authConfigId: String?
                    var logoUrl: String?

                    // Try to extract the actual data from various wrapper formats
                    var dataToProcess: [String: Any]? = nil

                    // Format 1: Check for content[0].text wrapper (official Rube format)
                    // The output is wrapped in content array with text field containing JSON string
                    if let content = outputDict["content"] as? [[String: Any]],
                       let firstContent = content.first,
                       let textString = firstContent["text"] as? String,
                       let textData = textString.data(using: .utf8),
                       let parsedText = try? JSONSerialization.jsonObject(with: textData) as? [String: Any] {
                        print("📋 Parsed content[0].text wrapper")
                        dataToProcess = parsedText
                    }
                    // Format 2: Direct dictionary (no wrapper)
                    else {
                        print("📋 Using direct dictionary (no wrapper)")
                        dataToProcess = outputDict
                    }

                    guard let processDict = dataToProcess else {
                        return .toolOutputAvailable(id: id, output: output)
                    }

                    // Check for direct auth_url first
                    if let authUrl = processDict["auth_url"] as? String {
                        print("🔗 Found direct auth_url: \(authUrl)")
                        provider = (processDict["toolkit"] as? String) ?? "App"
                        oauthUrl = authUrl
                        authConfigId = processDict["auth_config_id"] as? String
                        logoUrl = processDict["logo_url"] as? String
                    }
                    // Check for nested data.results structure (official Composio/Rube format)
                    else if let data = processDict["data"] as? [String: Any],
                            let results = data["results"] as? [String: Any] {
                        print("📊 Found data.results structure with \(results.count) results")
                        // Iterate through toolkit results
                        for (toolkitName, result) in results {
                            print("  🔍 Checking toolkit: \(toolkitName)")
                            if let resultDict = result as? [String: Any],
                               let status = resultDict["status"] as? String {
                                print("    Status: \(status)")
                                if status == "initiated",
                                   let redirectUrl = resultDict["redirect_url"] as? String {
                                    print("    🔗 Found redirect_url: \(redirectUrl)")
                                    provider = toolkitName
                                    oauthUrl = redirectUrl
                                    break
                                }
                            }
                        }
                    } else {
                        print("❌ No matching structure found in processDict")
                        print("   Keys: \(processDict.keys.joined(separator: ", "))")
                    }

                    // If we found an OAuth URL, create connection request
                    if let oauthUrl = oauthUrl {
                        print("🎉 CREATING CONNECTION REQUEST: provider=\(provider), url=\(oauthUrl)")
                        let request = ConnectionRequest(
                            provider: provider,
                            fields: [],
                            authConfigId: authConfigId,
                            logoUrl: logoUrl,
                            oauthUrl: oauthUrl
                        )
                        return .connectionRequest(request)
                    }
                }

                return .toolOutputAvailable(id: id, output: output)
            }

        case "error":
            if let message = json["message"] as? String {
                return .error(message)
            }

        default:
            break
        }

        return nil
    }

    /// Parse multiple lines from a buffer, returning events and remaining buffer
    static func parseBuffer(_ buffer: String) -> (events: [SSEEvent], remaining: String) {
        var events: [SSEEvent] = []
        let lines = buffer.components(separatedBy: "\n")

        // Keep the last line (might be incomplete)
        let completeLines = lines.dropLast()
        let remaining = lines.last ?? ""

        for line in completeLines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if let event = parse(line: trimmed) {
                events.append(event)
            }
        }

        return (events, remaining)
    }
}
