import AppKit

/// The figure beside the card. Loaded once from the bundle; its aspect ratio
/// drives how wide the figure slot needs to be.
enum FigureAsset {
    static let image: NSImage? = {
        if let url = Bundle.main.url(forResource: "vodya-figure", withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            return image
        }
        // Fallback for the offline preview renderer, which has no .app bundle.
        let adjacent = Bundle.main.bundleURL.appendingPathComponent("vodya-figure.png")
        return NSImage(contentsOf: adjacent)
    }()

    static var aspect: CGFloat {
        guard let size = image?.size, size.height > 0 else { return 0.62 }
        return size.width / size.height
    }
}
