#!/bin/bash
# Builds a universal (arm64 + x86_64) Vodya.app and packages it for a release.
set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME="Vodya"
BUILD="build/release"
BUNDLE="${BUILD}/${APP_NAME}.app"
DIST="dist"
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Info.plist)
ZIP="${DIST}/${APP_NAME}-${VERSION}-universal.zip"

rm -rf "${BUILD}"
mkdir -p "${BUNDLE}/Contents/MacOS" "${BUNDLE}/Contents/Resources" "${DIST}"

for arch in arm64 x86_64; do
  echo "==> Compiling ${arch}"
  swiftc \
    -O \
    -swift-version 5 \
    -target "${arch}-apple-macosx14.0" \
    -framework AppKit \
    -framework SwiftUI \
    -framework Carbon \
    Sources/*.swift \
    -o "${BUILD}/${APP_NAME}-${arch}"
done

echo "==> Merging slices"
lipo -create "${BUILD}/${APP_NAME}-arm64" "${BUILD}/${APP_NAME}-x86_64" \
  -output "${BUNDLE}/Contents/MacOS/${APP_NAME}"

cp Info.plist "${BUNDLE}/Contents/Info.plist"
cp assets/vodya-figure.png "${BUNDLE}/Contents/Resources/"
cp assets/vodya-background.jpg "${BUNDLE}/Contents/Resources/"

echo "==> Signing (ad-hoc)"
codesign --force --sign - "${BUNDLE}" >/dev/null

echo "==> Packaging"
rm -f "${ZIP}"
ditto -c -k --keepParent "${BUNDLE}" "${ZIP}"
shasum -a 256 "${ZIP}" > "${ZIP}.sha256"
lipo -archs "${BUNDLE}/Contents/MacOS/${APP_NAME}"
echo "Release: ${PWD}/${ZIP}"
