#!/bin/bash
# Renders card previews offline to build/preview-*.png (no app launch needed).
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build
swiftc -O -swift-version 5 -target arm64-apple-macosx14.0 \
  -framework AppKit -framework SwiftUI -framework Carbon \
  Sources/Palette.swift \
  Sources/Theme.swift \
  Sources/CardConfig.swift \
  Sources/CardMetrics.swift \
  Sources/FigureAsset.swift \
  Sources/BackgroundAsset.swift \
  Sources/Assets.swift \
  Sources/HotKeySpec.swift \
  Sources/NowPlayingModel.swift \
  Sources/GlobalHotKey.swift \
  Sources/ContentView.swift \
  tools/preview/main.swift \
  -o build/render-preview
cp assets/vodya-figure.png build/
cp assets/vodya-background.jpg build/
./build/render-preview
