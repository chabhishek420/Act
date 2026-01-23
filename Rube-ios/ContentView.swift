//
//  ContentView.swift
//  Rube-ios
//
//  Root content view with auth routing
//

import SwiftUI
import Appwrite

struct ContentView: View {
    @State private var authService = AuthService.shared
    @State private var pingResult: String?
    @State private var isPinging = false

    var body: some View {
        Group {
            if authService.isAuthenticated {
                ChatView()
            } else {
                VStack(spacing: 20) {
                    AuthView()

                    // Ping button for testing Appwrite connection
                    Button {
                        Task { await sendPing() }
                    } label: {
                        HStack {
                            if isPinging {
                                ProgressView()
                                    .tint(.white)
                            }
                            Text("Send a ping")
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(.green)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .disabled(isPinging)

                    if let pingResult = pingResult {
                        Text(pingResult)
                            .font(.caption)
                            .foregroundStyle(pingResult.contains("Success") ? .green : .red)
                    }
                }
            }
        }
        .animation(.easeInOut, value: authService.isAuthenticated)
    }

    private func sendPing() async {
        isPinging = true
        pingResult = nil

        do {
            let _ = try await client.ping()
            pingResult = "Success! Appwrite is connected."
        } catch {
            pingResult = "Error: \(error.localizedDescription)"
        }

        isPinging = false
    }
}

#Preview {
    ContentView()
}
