#!/bin/bash

# Example usage of the Flutter app cloning script
# This demonstrates how to use the clone_app.sh script

echo "=== Flutter App Cloning Examples ==="
echo ""

# Example 1: Interactive mode (recommended)
echo "Example 1: Interactive Mode (Recommended)"
echo "./clone_app.sh"
echo "This will prompt you for all configurations interactively"
echo ""

# Example 2: Non-interactive mode
echo "Example 2: Non-interactive Mode"
echo "./clone_app.sh --source patelmart --new-name idlibykilo --package com.idlibykilo.app"
echo ""

# Example 3: With Firebase config
echo "Example 3: With Firebase Configuration"
echo "./clone_app.sh --source patelmart --new-name idlibykilo --package com.idlibykilo.app --firebase-config ./idlibykilo"
echo ""

# Example 4: Full configuration with keystore
echo "Example 4: Full Configuration with Keystore"
echo "./clone_app.sh --source patelmart --new-name idlibykilo --package com.idlibykilo.app \\"
echo "  --firebase-config ./idlibykilo \\"
echo "  --keystore ./idlibykilo/idlibykilo.jks \\"
echo "  --keystore-password idlibykilo \\"
echo "  --keystore-alias idlibykilo"
echo ""

# Example 5: Show help
echo "Example 5: Show Help"
echo "./clone_app.sh --help"
echo ""

echo "=== Interactive Mode Experience ==="
echo "When you run ./clone_app.sh without arguments:"
echo ""
echo "1. You'll be prompted for source app name"
echo "2. You'll be asked for new app name"
echo "3. You'll be prompted for package name"
echo "4. You'll be asked if you want Firebase config"
echo "5. You'll be asked if you want keystore config"
echo "6. You'll see a summary and confirmation"
echo ""

echo "=== Directory Structure for Firebase Config ==="
echo "idlibykilo/"
echo "├── google-services.json          # Android Firebase config"
echo "├── GoogleService-Info.plist      # iOS/macOS Firebase config"
echo "└── idlibykilo.jks               # Keystore file"
echo ""

echo "=== What Gets Changed ==="
echo "✅ App name in pubspec.yaml"
echo "✅ Android package name and app label"
echo "✅ iOS bundle identifier and display name"
echo "✅ Firebase configuration files (if provided)"
echo "✅ Keystore configuration (if provided)"
echo "✅ Project initialization (flutter clean && flutter pub get)"
echo ""

echo "=== Output ==="
echo "📁 New app directory: [new_app_name]"
echo "📄 Summary report: [new_app_name]/CLONE_SUMMARY.md"
echo "🚀 Ready to run: cd [new_app_name] && flutter run"
echo ""

echo "=== Tips ==="
echo "💡 Use interactive mode for one-off cloning"
echo "💡 Use non-interactive mode for automation/scripts"
echo "💡 Always test the cloned app before deploying"
echo "💡 Update app icons and branding after cloning" 