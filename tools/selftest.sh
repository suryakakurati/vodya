#!/bin/bash
# Runs the preset / PNG-import / sizing logic checks against a throwaway support dir.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build
swiftc -O -swift-version 5 -target arm64-apple-macosx14.0 \
  -framework AppKit -framework SwiftUI \
  Sources/Palette.swift \
  Sources/Theme.swift \
  Sources/CardConfig.swift \
  Sources/CardMetrics.swift \
  Sources/FigureAsset.swift \
  Sources/Assets.swift \
  Sources/HotKeySpec.swift \
  tools/selftest/main.swift \
  -o build/selftest
rm -rf build/selftest-support
mkdir -p build/selftest-support
VODYA_SUPPORT_DIR="$PWD/build/selftest-support" ./build/selftest
