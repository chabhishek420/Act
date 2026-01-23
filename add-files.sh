#!/bin/bash
# Simple Xcode File Addition Helper
# Run this to open Xcode and get ready to add files

echo "🔧 Opening Xcode project..."
open Rube-ios.xcodeproj

echo ""
echo "📝 TO ADD FILES:"
echo "1. In Project Navigator, right-click 'Models' folder"
echo "2. Choose 'Add Files to Rube-ios...'"
echo "3. Select: ConversationModel.swift and MessageModel.swift"  
echo "4. Right-click 'Services' folder"
echo "5. Choose 'Add Files to Rube-ios...'"
echo "6. Select: LocalConversationService.swift"
echo "7. Make sure 'Add to targets: Rube-ios' is checked"
echo "8. Click Add"
echo "9. Build (⌘B)"
echo ""
echo "✨ Files to add:"
echo "   - Models/ConversationModel.swift"
echo "   - Models/MessageModel.swift"
echo "   - Services/LocalConversationService.swift"
