//
//  LinkableTextView.swift
//  Rube-ios
//
//  A UITextView wrapper that supports tappable links and text selection.
//

import SwiftUI
import UIKit

/// A SwiftUI view that wraps UITextView to provide tappable links and text selection.
/// This is necessary because SwiftUI's Text view with AttributedString does not support
/// tappable links - it only renders them visually.
struct LinkableTextView: UIViewRepresentable {
    let text: String
    var font: UIFont = .preferredFont(forTextStyle: .body)
    var textColor: UIColor = .label

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isEditable = false
        textView.isScrollEnabled = false
        textView.backgroundColor = .clear
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.dataDetectorTypes = [.link]
        textView.linkTextAttributes = [
            .foregroundColor: UIColor.systemBlue,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.setContentHuggingPriority(.defaultHigh, for: .vertical)
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        // Try to parse as markdown first for styled content
        if let attributedString = parseMarkdown(text) {
            let mutableAttributed = NSMutableAttributedString(attributedString: attributedString)

            // Apply base font and color to the entire string
            let range = NSRange(location: 0, length: mutableAttributed.length)
            mutableAttributed.addAttribute(NSAttributedString.Key.font, value: font, range: range)
            mutableAttributed.addAttribute(NSAttributedString.Key.foregroundColor, value: textColor, range: range)

            uiView.attributedText = mutableAttributed
        } else {
            // Fallback to plain text with data detection
            uiView.font = font
            uiView.textColor = textColor
            uiView.text = text
        }
    }

    /// Parse markdown text into NSAttributedString
    private func parseMarkdown(_ text: String) -> NSAttributedString? {
        // Try to parse markdown links in the format [text](url)
        let pattern = #"\[([^\]]+)\]\(([^)]+)\)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return nil
        }

        let nsText = text as NSString
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length))

        guard !matches.isEmpty else {
            // No markdown links found, return nil to use plain text with data detection
            return nil
        }

        let attributedString = NSMutableAttributedString()
        var lastEnd = 0

        for match in matches {
            // Add text before the match
            if match.range.location > lastEnd {
                let beforeRange = NSRange(location: lastEnd, length: match.range.location - lastEnd)
                let beforeText = nsText.substring(with: beforeRange)
                attributedString.append(NSAttributedString(string: beforeText))
            }

            // Extract link text and URL
            let linkTextRange = match.range(at: 1)
            let urlRange = match.range(at: 2)
            let linkText = nsText.substring(with: linkTextRange)
            let urlString = nsText.substring(with: urlRange)

            // Create linked text with URL scheme validation
            if let url = URL(string: urlString),
               let scheme = url.scheme?.lowercased(),
               ["http", "https", "mailto", "tel"].contains(scheme) {
                // Only allow safe URL schemes
                let linkAttributes: [NSAttributedString.Key: Any] = [
                    .link: url,
                    .foregroundColor: UIColor.systemBlue,
                    .underlineStyle: NSUnderlineStyle.single.rawValue
                ]
                attributedString.append(NSAttributedString(string: linkText, attributes: linkAttributes))
            } else {
                // Invalid URL or unsafe scheme, just add the text without link
                attributedString.append(NSAttributedString(string: linkText))
            }

            lastEnd = match.range.location + match.range.length
        }

        // Add remaining text after last match
        if lastEnd < nsText.length {
            let remainingRange = NSRange(location: lastEnd, length: nsText.length - lastEnd)
            let remainingText = nsText.substring(with: remainingRange)
            attributedString.append(NSAttributedString(string: remainingText))
        }

        return attributedString
    }
}

// MARK: - SwiftUI Preview

#Preview {
    VStack(alignment: .leading, spacing: 20) {
        LinkableTextView(text: "Check out this link: https://example.com and this one too!")

        LinkableTextView(text: "Click [here](https://google.com) to visit Google or [here](https://apple.com) for Apple.")

        LinkableTextView(text: "Plain text without any links.")
    }
    .padding()
}
