//
//  AuthView.swift
//  Rube-ios
//
//  Authentication view with email/password sign-in
//

import SwiftUI

struct AuthView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var name = ""
    @State private var isSignUp = false
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Logo
            Image(systemName: "sparkles")
                .font(.system(size: 64))
                .foregroundStyle(.blue)

            VStack(spacing: 8) {
                Text("Welcome to Rube")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Your AI assistant for 500+ apps")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Form
            VStack(spacing: 16) {
                if isSignUp {
                    TextField("Name (optional)", text: $name)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.name)
                        .autocapitalization(.words)
                }

                TextField("Email", text: $email)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.emailAddress)
                    .autocapitalization(.none)
                    .keyboardType(.emailAddress)

                SecureField("Password", text: $password)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(isSignUp ? .newPassword : .password)
            }
            .padding(.horizontal, 32)

            // Error message
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            // Submit button
            Button {
                Task { await submit() }
            } label: {
                HStack {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    }
                    Text(isSignUp ? "Create Account" : "Sign In")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(.blue)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(isLoading || email.isEmpty || password.isEmpty)
            .padding(.horizontal, 32)

            // Toggle sign up / sign in
            Button {
                withAnimation {
                    isSignUp.toggle()
                    errorMessage = nil
                }
            } label: {
                Text(isSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                    .font(.subheadline)
                    .foregroundStyle(.blue)
            }

            Spacer()
        }
        .padding()
    }

    private func submit() async {
        isLoading = true
        errorMessage = nil

        do {
            if isSignUp {
                try await AuthService.shared.signUp(
                    email: email,
                    password: password,
                    name: name.isEmpty ? nil : name
                )
            } else {
                try await AuthService.shared.signIn(
                    email: email,
                    password: password
                )
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

#Preview {
    AuthView()
}
