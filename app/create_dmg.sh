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

# 2. Prepare a temporary directory for the DMG content
echo "📂 Preparing DMG content..."
if [ -d "build/dmg_temp" ]; then
    rm -rf "build/dmg_temp"
fi
mkdir -p "build/dmg_temp"

# 3. Copy the App to the temp directory
cp -r "$APP_BUILD_PATH" "build/dmg_temp/"

# 4. Create a symlink to Applications folder (The "Drag here" shortcut)
ln -s /Applications "build/dmg_temp/Applications"

# 5. Create the DMG using hdiutil (macOS native tool)
echo "💿 Creating .dmg file..."
if [ -f "$DMG_NAME" ]; then
    rm "$DMG_NAME"
fi

hdiutil create \
  -volname "$VOLUME_NAME" \
  -srcfolder "build/dmg_temp" \
  -ov -format UDZO \
  "$DMG_NAME"

# 6. Cleanup
rm -rf "build/dmg_temp"

echo "✅ Success! Installer created: $DMG_NAME"
