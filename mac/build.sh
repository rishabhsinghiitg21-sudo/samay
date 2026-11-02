#!/bin/bash
# Builds Samay.saver from sources.
#
#   ./build.sh              → build/Samay.saver
#   ./build.sh some/folder  → some/folder/Samay.saver
#
# Requires the Xcode command-line tools (`xcode-select --install`).
# No Xcode project and no signing team: the bundle is built unsigned.

set -e
cd "$(dirname "$0")"

OUT_DIR="${1:-build}"
BUNDLE="$OUT_DIR/Samay.saver"
EXEC_NAME="Samay"

# Clean previous build
rm -rf "$BUNDLE"

# Bundle directory structure
mkdir -p "$BUNDLE/Contents/MacOS"
mkdir -p "$BUNDLE/Contents/Resources"

# Bundle Info.plist
cp Info.plist "$BUNDLE/Contents/"

# Bundle thumbnails used as the System Settings preview tile.
# Apple convention: thumbnail.png (1x, 90x58) + thumbnail@2x.png (2x, 180x116).
cp assets/thumbnail.png     "$BUNDLE/Contents/Resources/"
cp assets/thumbnail@2x.png  "$BUNDLE/Contents/Resources/"

# Pick build target for current Mac architecture
ARCH="$(uname -m)"
if [ "$ARCH" = "arm64" ]; then
  TARGET="arm64-apple-macos11.0"
else
  TARGET="x86_64-apple-macos11.0"
fi

echo "Compiling for $TARGET..."

swiftc \
  -O \
  -target "$TARGET" \
  -emit-library \
  -Xlinker -bundle \
  -framework Cocoa \
  -framework ScreenSaver \
  -framework QuartzCore \
  -module-name "$EXEC_NAME" \
  -o "$BUNDLE/Contents/MacOS/$EXEC_NAME" \
  sources/*.swift

echo ""
echo "✓ Built $BUNDLE"
echo ""
echo "To install for your user only, double-click the .saver, or:"
echo "    cp -R '$BUNDLE' ~/Library/Screen\\ Savers/"
echo ""
echo "Then open System Settings → Screen Saver and select Samay."
