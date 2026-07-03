#!/bin/bash

# Script to start iPhone 17 simulator and install the app
# Usage: ./scripts/run_on_iphone17.sh

set -e

DEVICE_NAME="iPhone 17"
DEVICE_ID=$(xcrun simctl list devices available | grep "$DEVICE_NAME" | grep "Shutdown" | head -1 | awk -F'[()]' '{print $2}')

if [ -z "$DEVICE_ID" ]; then
    echo "❌ iPhone 17 simulator not found. Please ensure iOS 26+ is installed."
    exit 1
fi

echo "📱 Starting $DEVICE_NAME (ID: $DEVICE_ID)..."
xcrun simctl boot "$DEVICE_ID" &
sleep 5

echo "🔨 Building and installing app..."
flutter build ios --debug --no-codesign --simulator

echo "📲 Installing to simulator..."
APP_PATH=$(find build/ios/Debug-iphonesimulator -name "*.app" -type d 2>/dev/null | head -1)
if [ -z "$APP_PATH" ]; then
    echo "❌ Build failed or .app not found."
    echo "💡 Note: Xcode 26 beta may have compatibility issues with Flutter."
    echo "   Try running 'flutter clean && flutter pub get && pod install' first."
    exit 1
fi

xcrun simctl install "$DEVICE_ID" "$APP_PATH"

echo "🚀 Launching app..."
APP_BUNDLE_ID=$(defaults read "$APP_PATH/Info" CFBundleIdentifier 2>/dev/null || echo "com.example.languageTrainer")
xcrun simctl launch "$DEVICE_ID" "$APP_BUNDLE_ID"

echo "✅ App is running on $DEVICE_NAME!"
