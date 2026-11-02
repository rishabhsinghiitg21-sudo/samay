#!/bin/bash
# Build a shareable Samay Windows release.
#
#   1. Runs the cross-platform unit tests (arg parser, theme catalog,
#      HTML injection, clock.html sanity). If any fail, abort —
#      shipping a regression to Windows when we can't VM-test it on Mac
#      is not worth saving 30 seconds.
#   2. Cross-compiles Samay.scr for win-x64 (single-file, self-contained).
#   3. Bundles Samay.scr + Read Me First.txt into dist/Samay-<ver>-windows.zip.
#
# The ZIP goes on GitHub Releases, never into the repo.

set -e
cd "$(dirname "$0")/.."   # → windows/

VERSION="1.0"
ZIP_NAME="Samay-${VERSION}-windows"
RELEASE_DIR="release"
DIST_DIR="dist"
STAGE_DIR="out/stage"
LOG="out/unit-tests.log"

# Use the user-scope dotnet install path if dotnet isn't on PATH
if ! command -v dotnet >/dev/null 2>&1; then
  export PATH="$HOME/.dotnet:$PATH"
fi

echo "═══ 1. Running unit tests ═══"
mkdir -p out
if ! dotnet run --project tests/UnitTests.csproj > "$LOG" 2>&1; then
    echo "❌ Unit tests failed. Output:"
    cat "$LOG"
    exit 1
fi
TAIL=$(tail -1 "$LOG")
echo "$TAIL"

echo ""
echo "═══ 2. Building Samay.scr (win-x64, self-contained) ═══"
./build.sh > /dev/null

if [ ! -f "out/Samay.scr" ]; then
    echo "❌ build.sh did not produce out/Samay.scr"
    exit 1
fi

SIZE=$(du -h out/Samay.scr | cut -f1)
echo "✓ Built out/Samay.scr (${SIZE})"

echo ""
echo "═══ 3. Staging zip contents ═══"
rm -rf "$STAGE_DIR"
mkdir -p "$STAGE_DIR/Samay"
cp out/Samay.scr                            "$STAGE_DIR/Samay/Samay.scr"
cp "$RELEASE_DIR/Read Me First.txt"         "$STAGE_DIR/Samay/Read Me First.txt"

echo ""
echo "═══ 4. Building ZIP ═══"
mkdir -p "$DIST_DIR"
ZIP_PATH="$DIST_DIR/${ZIP_NAME}.zip"
rm -f "$ZIP_PATH"
(cd "$STAGE_DIR" && zip -r -q "../../$ZIP_PATH" "Samay")

# Clean up the stage dir; the ZIP is the deliverable.
rm -rf "$STAGE_DIR"

ZIP_SIZE=$(du -h "$ZIP_PATH" | cut -f1)
echo ""
echo "✓ ${ZIP_PATH}  (${ZIP_SIZE})"
echo "  Recipients extract → right-click Samay.scr → Install."
