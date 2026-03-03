#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

CONFIGURATION="${1:-debug}"
APP_NAME="Connections"
APP_BUNDLE="$SCRIPT_DIR/.build/$APP_NAME.app"

echo "==> Building $APP_NAME ($CONFIGURATION)..."
if [ "$CONFIGURATION" = "release" ]; then
    swift build -c release
    BINARY_PATH=".build/release/$APP_NAME"
else
    swift build
    BINARY_PATH=".build/debug/$APP_NAME"
fi

echo "==> Assembling $APP_NAME.app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BINARY_PATH" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cp "$SCRIPT_DIR/Connections/Info.plist" "$APP_BUNDLE/Contents/Info.plist"

# Compile asset catalog if actool is available
if command -v actool &> /dev/null; then
    actool \
        --compile "$APP_BUNDLE/Contents/Resources" \
        --platform macosx \
        --minimum-deployment-target 14.0 \
        --app-icon AppIcon \
        --output-partial-info-plist /dev/null \
        "$SCRIPT_DIR/Connections/Assets.xcassets" 2>/dev/null || true
fi

echo ""
echo "Built: $APP_BUNDLE"
echo ""
echo "Run with:"
echo "  open $APP_BUNDLE"
