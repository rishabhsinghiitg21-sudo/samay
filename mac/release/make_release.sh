#!/bin/bash
# Build a shareable Samay DMG.
#
#   1. Rebuilds Samay.saver from source into build/.
#   2. Codesigns it ad hoc (no Apple Developer ID, so not notarised).
#   3. Stages Samay.saver + "Read Me First.txt".
#   4. Wraps that into a compressed DMG: dist/Samay-<ver>.dmg
#
# The DMG goes on GitHub Releases, never into the repo.

set -e
cd "$(dirname "$0")/.."   # → mac/

VERSION="1.2"
DMG_NAME="Samay-${VERSION}"
BUILD_DIR="build"
DIST_DIR="dist"
STAGE_DIR="$BUILD_DIR/stage"

echo "═══ 1. Building Samay.saver ═══"
./build.sh "$BUILD_DIR" > /dev/null
codesign --force --deep --sign - "$BUILD_DIR/Samay.saver" 2>&1 | grep -v "replacing" || true

echo "═══ 2. Staging DMG contents ═══"
rm -rf "$STAGE_DIR"
mkdir -p "$STAGE_DIR"
cp -R "$BUILD_DIR/Samay.saver"      "$STAGE_DIR/Samay.saver"
cp    "release/Read Me First.txt"   "$STAGE_DIR/Read Me First.txt"

# The DMG ships only the .saver and the read-me. On macOS Sequoia and
# later, Gatekeeper kills quarantined shell scripts, and a .saver has no
# "Open Anyway" path, so the read-me's xattr line is the reliable way in
# until the bundle is signed and notarised with a Developer ID.

echo "═══ 3. Building DMG ═══"
mkdir -p "$DIST_DIR"
DMG_PATH="$DIST_DIR/${DMG_NAME}.dmg"
rm -f "$DMG_PATH"
hdiutil create \
    -volname "Samay" \
    -srcfolder "$STAGE_DIR" \
    -ov \
    -format UDZO \
    "$DMG_PATH" > /dev/null

rm -rf "$STAGE_DIR"

SIZE=$(du -h "$DMG_PATH" | cut -f1)
echo ""
echo "✓ ${DMG_PATH}  (${SIZE})"
