#!/bin/bash
# Builds Vodya.app from Sources/ into build/
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="Vodya"
BUNDLE="build/${APP_NAME}.app"

rm -rf "${BUNDLE}"
mkdir -p "${BUNDLE}/Contents/MacOS" "${BUNDLE}/Contents/Resources"

echo "==> Compiling"
swiftc \
  -O \
  -swift-version 5 \
  -target arm64-apple-macosx14.0 \
  -framework AppKit \
  -framework SwiftUI \
  -framework Carbon \
  Sources/*.swift \
  -o "${BUNDLE}/Contents/MacOS/${APP_NAME}"

echo "==> Assembling bundle"
cp Info.plist "${BUNDLE}/Contents/Info.plist"
cp assets/vodya-figure.png "${BUNDLE}/Contents/Resources/vodya-figure.png"
cp assets/vodya-background.jpg "${BUNDLE}/Contents/Resources/vodya-background.jpg"

echo "==> Signing (ad-hoc)"
codesign --force --sign - "${BUNDLE}" >/dev/null

echo "Built: ${PWD}/${BUNDLE}"
