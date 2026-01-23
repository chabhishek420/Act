//
//  ConnectionPromptView.swift
//  Rube-ios
//
//  Connection prompt for OAuth and app connections
//

import SwiftUI

struct ConnectionPromptView: View {
    let request: RubeConnectionRequest
    let onConnect: (String) -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 12) {
                if let logoUrl = request.logoUrl, let url = URL(string: logoUrl) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .scaledToFit()
                    } placeholder: {
                        Image(systemName: "app.fill")
                            .resizable()
                            .scaledToFit()
                    }
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    Image(systemName: "app.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.blue)
                }

                Text("Connect \(request.provider)")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Rube needs access to your \(request.provider) account to complete this action")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Divider()

            // OAuth flow or custom fields
            if request.isOAuthOnly, let oauthUrl = request.oauthUrl {
                // Simple OAuth button
                VStack(spacing: 16) {
                    Label {
                        Text("Continue with \(request.provider)")
                    } icon: {
                        Image(systemName: "checkmark.shield.fill")
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                    Button {
                        onConnect(oauthUrl)
                    } label: {
                        Text("Connect")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            } else {
                // Custom fields (for services like Pipedrive)
                VStack(alignment: .leading, spacing: 16) {
                    Text("Additional Information Required")
                        .font(.headline)

                    ForEach(Array(request.fields.enumerated()), id: \.offset) { _, field in
                        if let label = field["label"] as? String {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(label)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)

                                TextField(
                                    field["placeholder"] as? String ?? "",
                                    text: .constant("")
                                )
                                .textFieldStyle(.roundedBorder)
                            }
                        }
                    }

                    Button {
                        // Handle custom field submission
                        if let oauthUrl = request.oauthUrl {
                            onConnect(oauthUrl)
                        }
                    } label: {
                        Text("Continue")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }

            // Cancel button
            Button("Cancel", role: .cancel) {
                onDismiss()
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .padding(24)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(radius: 20)
        .padding()
    }
}

// Preview
#Preview {
    ConnectionPromptView(
        request: RubeConnectionRequest(
            provider: "Gmail",
            fields: [],
            authConfigId: nil,
            logoUrl: nil,
            oauthUrl: "https://accounts.google.com/o/oauth2/v2/auth"
        ),
        onConnect: { _ in },
        onDismiss: {}
    )
}
