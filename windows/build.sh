#!/bin/bash
# Cross-compile Samay.scr from Mac to Windows x64.
# Outputs to ./out/Samay.scr — a single-file, self-contained executable
# that doesn't require a separate .NET install on Windows. (WebView2
# itself ships with Win10/11 so no separate runtime install is needed.)

set -e
cd "$(dirname "$0")"

# Use the user-scope dotnet install path if dotnet isn't on PATH
if ! command -v dotnet >/dev/null 2>&1; then
  export PATH="$HOME/.dotnet:$PATH"
fi

PROJECT="src/Samay.csproj"
OUT_DIR="out"
PUBLISH_DIR="$OUT_DIR/publish"

rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"

echo "Restoring..."
dotnet restore "$PROJECT"

echo "Publishing for win-x64..."
dotnet publish "$PROJECT" \
  -c Release \
  -r win-x64 \
  --self-contained true \
  -p:PublishSingleFile=true \
  -p:IncludeNativeLibrariesForSelfExtract=true \
  -p:EnableCompressionInSingleFile=true \
  -o "$PUBLISH_DIR"

# Rename Samay.exe → Samay.scr
if [ -f "$PUBLISH_DIR/Samay.exe" ]; then
  mv "$PUBLISH_DIR/Samay.exe" "$OUT_DIR/Samay.scr"
  echo ""
  echo "✓ Built $OUT_DIR/Samay.scr"
  ls -la "$OUT_DIR/Samay.scr"
else
  echo "ERROR: publish did not produce Samay.exe"
  ls -la "$PUBLISH_DIR"
  exit 1
fi

echo ""
echo "To distribute:"
echo "  zip Samay.zip $OUT_DIR/Samay.scr   # email-safe"
echo ""
echo "Friends install by:"
echo "  1. Extract the zip"
echo "  2. Right-click Samay.scr → Install"
echo "  3. Windows opens Screen Saver settings with Samay selected"
