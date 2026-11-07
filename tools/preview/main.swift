// Offline preview renderer: draws the card to PNGs without launching the app.
import AppKit
import SwiftUI

func writePNG<V: View>(_ view: V, size: NSSize, to path: String) {
    MainActor.assumeIsolated {
    let renderer = ImageRenderer(content: view.frame(width: size.width, height: size.height))
    renderer.scale = 2
    guard let image = renderer.nsImage,
          let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let png = bitmap.representation(using: .png, properties: [:])
    else {
        FileHandle.standardError.write(Data("render failed for \(path)\n".utf8))
        return
    }
    try? png.write(to: URL(fileURLWithPath: path))
    print("wrote \(path)")
    }
}

MainActor.assumeIsolated {
    let playing = TrackInfo(
        title: "晴る",
        artist: "Yorushika",
        album: "二人称",
        isPlaying: true,
        elapsed: 63,
        duration: 272.6,
        timestamp: Date(),
        artwork: nil,
        artworkKey: "",
        sourceBundleID: "com.spotify.client"
    )

    func render(_ config: CardConfig, _ track: TrackInfo, to path: String) {
        let store = CardStore(preview: config)
        let metrics = store.metrics
        writePNG(
            ContentView(service: NowPlayingService(snapshot: track), store: store, blurredBackground: false),
            size: metrics.size,
            to: path
        )
    }

    render(CardConfig(), playing, to: "build/preview-card.png")
    render(CardConfig(), .idle, to: "build/preview-idle.png")

    var small = CardConfig()
    small.appearance.size = "small"
    small.appearance.showFigure = false
    render(small, playing, to: "build/preview-small.png")

    var mist = CardConfig()
    mist.appearance.palette = "mist"
    mist.appearance.accent = "lavender"
    render(mist, playing, to: "build/preview-mist.png")

    var glow = CardConfig()
    glow.appearance.palette = "softPurple"
    glow.appearance.glowStrength = 0.9
    glow.appearance.glowColor = "#CBD6F2"
    render(glow, playing, to: "build/preview-glow.png")
}
