//
//  UserInputFormView.swift
//  Rube-ios
//
//  Created by Rube Agent on 2026-01-24.
//

import SwiftUI

/// A form view that displays when REQUEST_USER_INPUT tool is triggered.
/// Collects custom input fields required before proceeding with OAuth.
struct UserInputFormView: View {
    let request: UserInputRequest
    let onSubmit: (UserInputResponse) -> Void
    let onDismiss: () -> Void
    
    @State private var values: [String: String] = [:]
    @State private var isSubmitting = false
    @FocusState private var focusedField: String?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            Divider()
            
            // Form Fields
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(request.fields) { field in
                        fieldView(for: field)
                    }
                }
                .padding()
            }
            
            Divider()
            
            // Actions
            actionButtons
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.15), radius: 20, y: 10)
        .padding(.horizontal, 24)
        .onAppear {
            // Initialize values dictionary
            for field in request.fields {
                values[field.name] = ""
            }
            // Focus first field
            if let firstField = request.fields.first {
                focusedField = firstField.name
            }
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        VStack(spacing: 12) {
            // Provider logo or icon
            if let logoUrl = request.logoUrl, let url = URL(string: logoUrl) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFit()
                } placeholder: {
                    providerIcon
                }
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                providerIcon
            }
            
            Text("Connect to \(request.provider.capitalized)")
                .font(.headline)
                .fontWeight(.semibold)
            
            Text("This service requires additional information to connect.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
    
    private var providerIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.accentColor.opacity(0.1))
            
            Image(systemName: "link.circle.fill")
                .font(.system(size: 24))
                .foregroundStyle(Color.accentColor)
        }
        .frame(width: 48, height: 48)
    }
    
    // MARK: - Field View
    
    @ViewBuilder
    private func fieldView(for field: UserInputField) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            // Label
            HStack(spacing: 4) {
                Text(field.label)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if field.required {
                    Text("*")
                        .foregroundStyle(.red)
                }
            }
            
            // Input field
            Group {
                switch field.type {
                case .password:
                    SecureField(field.placeholder ?? "", text: binding(for: field.name))
                case .url:
                    TextField(field.placeholder ?? "https://", text: binding(for: field.name))
                        .keyboardType(.URL)
                        .textContentType(.URL)
                        .autocapitalization(.none)
                case .email:
                    TextField(field.placeholder ?? "email@example.com", text: binding(for: field.name))
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .autocapitalization(.none)
                case .number:
                    TextField(field.placeholder ?? "", text: binding(for: field.name))
                        .keyboardType(.numberPad)
                default:
                    TextField(field.placeholder ?? "", text: binding(for: field.name))
                        .autocapitalization(.none)
                }
            }
            .textFieldStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .focused($focusedField, equals: field.name)
        }
    }
    
    // MARK: - Action Buttons
    
    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button(action: onDismiss) {
                Text("Cancel")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.bordered)
            
            Button(action: submitForm) {
                if isSubmitting {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                } else {
                    Text("Continue")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!allRequiredFieldsFilled || isSubmitting)
        }
        .padding()
    }
    
    // MARK: - Helpers
    
    private func binding(for key: String) -> Binding<String> {
        Binding(
            get: { values[key] ?? "" },
            set: { values[key] = $0 }
        )
    }
    
    private var allRequiredFieldsFilled: Bool {
        request.fields.filter(\.required).allSatisfy { field in
            guard let value = values[field.name] else { return false }
            return !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
    
    private func submitForm() {
        isSubmitting = true
        
        let response = UserInputResponse(
            requestId: request.id,
            provider: request.provider,
            values: values,
            authConfigId: request.authConfigId
        )
        
        onSubmit(response)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.opacity(0.4)
            .ignoresSafeArea()
        
        UserInputFormView(
            request: UserInputRequest(
                provider: "pipedrive",
                fields: [
                    UserInputField(
                        name: "subdomain",
                        label: "Subdomain",
                        type: .text,
                        required: true,
                        placeholder: "your-company"
                    ),
                    UserInputField(
                        name: "instance_url",
                        label: "Instance URL",
                        type: .url,
                        required: false,
                        placeholder: "https://api.pipedrive.com"
                    )
                ],
                authConfigId: "test-auth-config",
                logoUrl: nil
            ),
            onSubmit: { response in
                print("Submitted: \(response)")
            },
            onDismiss: {
                print("Dismissed")
            }
        )
    }
}
