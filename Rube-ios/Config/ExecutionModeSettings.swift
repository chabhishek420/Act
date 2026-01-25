import Foundation
import SwiftUI

/// Execution mode determines how the agent handles destructive/sensitive actions
enum ExecutionMode: String, CaseIterable, Codable {
    case yolo = "yolo"
    case askForPermission = "ask_for_permission"
    
    var displayName: String {
        switch self {
        case .yolo:
            return "🚀 YOLO Mode"
        case .askForPermission:
            return "🛡️ Safe Mode"
        }
    }
    
    var description: String {
        switch self {
        case .yolo:
            return "Execute everything immediately without asking. Fast but risky."
        case .askForPermission:
            return "Ask before sending messages, deleting data, or irreversible actions."
        }
    }
    
    /// Returns the system prompt fragment for this mode
    var promptFragment: String {
        switch self {
        case .yolo:
            return """
            ## EXECUTION MODE: YOLO 🚀
            
            **Execute ALL actions immediately without asking for confirmation.**
            - Send emails, messages, and notifications directly
            - Create, update, and delete resources immediately
            - No need to pause for user approval
            - Speed and efficiency are the priority
            
            The user has opted for maximum speed. Trust their intent and execute.
            """
            
        case .askForPermission:
            return """
            ## ⚠️ USER CONFIRMATION REQUIRED:
            
            **MUST confirm before:**
            - Sending messages (email, Slack, Discord, SMS)
            - Overwriting or deleting existing data
            - Sharing resources visible to others
            - Any irreversible action
            
            **After asking confirmation, STOP all tool calls until user replies.**
            
            **No confirmation needed for:**
            - Read-only operations (list, fetch, search)
            - Creating private drafts
            - Creating new private resources
            """
        }
    }
}

/// Manages execution mode settings with UserDefaults persistence
final class ExecutionModeSettings: ObservableObject {
    static let shared = ExecutionModeSettings()
    
    private let userDefaultsKey = "rube_execution_mode"
    
    @Published var currentMode: ExecutionMode {
        didSet {
            UserDefaults.standard.set(currentMode.rawValue, forKey: userDefaultsKey)
        }
    }
    
    private init() {
        if let storedValue = UserDefaults.standard.string(forKey: userDefaultsKey),
           let mode = ExecutionMode(rawValue: storedValue) {
            self.currentMode = mode
        } else {
            // Default to Safe Mode
            self.currentMode = .askForPermission
        }
    }
}
