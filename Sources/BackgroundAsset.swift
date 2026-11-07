import AppKit

/// Artwork used behind the card by palettes that carry a background image.
enum BackgroundAsset {
    private static var cache: [String: NSImage] = [:]

    static func image(named name: String?) -> NSImage? {
        guard let name, !name.isEmpty else { return nil }
        if let cached = cache[name] { return cached }

        var image: NSImage?
        if let url = Bundle.main.url(forResource: name, withExtension: "jpg") {
            image = NSImage(contentsOf: url)
        }
        if image == nil {
            // Offline preview renderer: the asset sits next to the binary.
            let adjacent = Bundle.main.bundleURL.appendingPathComponent("\(name).jpg")
            image = NSImage(contentsOf: adjacent)
        }
        cache[name] = image
        NSLog("Vodya: background art '\(name)' \(image == nil ? "MISSING" : "loaded")")
        return image
    }
}
