#!/bin/bash

# Configuration
APP_NAME="RestaurApp Print"
APP_BUILD_PATH="build/macos/Build/Products/Release/$APP_NAME.app"
DMG_NAME="RestaurApp_Print_Installer.dmg"
VOLUME_NAME="RestaurApp Print Installer"

# 1. Ensure the app is built
if [ ! -d "$APP_BUILD_PATH" ]; then
    echo "❌ Error: App not found at $APP_BUILD_PATH"
    echo "Please run 'flutter build macos --release' first."
    exit 1
fi

# 2. Cleanup old DMGs
if [ -f "$DMG_NAME" ]; then
    echo "🗑️ Removing old DMG..."
    rm "$DMG_NAME"
fi

# 3. Create the DMG using create-dmg
# This tool allows adjusting window size, icon size, and positions for a "Premium" look.
echo "💿 Creating beautiful DMG..."

create-dmg \
  --volname "$VOLUME_NAME" \
  --volicon "$APP_BUILD_PATH/Contents/Resources/AppIcon.icns" \
  --window-pos 200 120 \
  --window-size 600 400 \
  --icon-size 100 \
  --text-size 14 \
  --icon "$APP_NAME" 175 190 \
  --hide-extension "$APP_NAME.app" \
  --app-drop-link 425 190 \
  "$DMG_NAME" \
  "$APP_BUILD_PATH"

echo "✅ Success! Premium Installer created: $DMG_NAME"
