//
//  UserInputRequest.swift
//  Rube-ios
//
//  Created by Rube Agent on 2026-01-24.
//

import Foundation

/// Represents a request for user input from the REQUEST_USER_INPUT tool.
/// Used when OAuth flows require additional parameters beyond standard OAuth
/// (e.g., Pipedrive subdomain, Salesforce instance URL).
struct UserInputRequest: Identifiable, Codable {
    let id: String
    let provider: String
    let fields: [UserInputField]
    let authConfigId: String?
    let logoUrl: String?
    
    init(
        id: String = UUID().uuidString,
        provider: String,
        fields: [UserInputField],
        authConfigId: String? = nil,
        logoUrl: String? = nil
    ) {
        self.id = id
        self.provider = provider
        self.fields = fields
        self.authConfigId = authConfigId
        self.logoUrl = logoUrl
    }
    
    /// Initialize from tool call arguments dictionary
    init(from arguments: [String: Any]) {
        self.id = UUID().uuidString
        self.provider = arguments["provider"] as? String ?? "Service"
        self.authConfigId = arguments["authConfigId"] as? String
        self.logoUrl = arguments["logoUrl"] as? String
        
        if let fieldsArray = arguments["fields"] as? [[String: Any]] {
            self.fields = fieldsArray.map { UserInputField(from: $0) }
        } else {
            self.fields = []
        }
    }
}

/// Represents a single input field in a UserInputRequest
struct UserInputField: Identifiable, Codable {
    let id: String
    let name: String
    let label: String
    let type: UserInputFieldType
    let required: Bool
    let placeholder: String?
    
    init(
        id: String = UUID().uuidString,
        name: String,
        label: String,
        type: UserInputFieldType = .text,
        required: Bool = true,
        placeholder: String? = nil
    ) {
        self.id = id
        self.name = name
        self.label = label
        self.type = type
        self.required = required
        self.placeholder = placeholder
    }
    
    /// Initialize from dictionary (from tool call arguments)
    init(from dict: [String: Any]) {
        self.id = UUID().uuidString
        self.name = dict["name"] as? String ?? ""
        self.label = dict["label"] as? String ?? ""
        self.required = dict["required"] as? Bool ?? true
        self.placeholder = dict["placeholder"] as? String
        
        if let typeString = dict["type"] as? String {
            self.type = UserInputFieldType(rawValue: typeString) ?? .text
        } else {
            self.type = .text
        }
    }
}

/// Supported input field types
enum UserInputFieldType: String, Codable {
    case text
    case url
    case email
    case password
    case number
}

/// Response from user after filling out the input form
struct UserInputResponse: Codable {
    let requestId: String
    let provider: String
    let values: [String: String]
    let authConfigId: String?
}
