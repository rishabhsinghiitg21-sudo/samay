#!/bin/bash
# web/index.html is the clock page the Windows screensaver embeds
# (windows/src/Resources/clock.html), copied as is. Run this after
# changing clock.html. The Windows unit tests fail if the two differ.
set -e
cd "$(dirname "$0")"
cp ../windows/src/Resources/clock.html index.html
echo "✓ web/index.html updated"
