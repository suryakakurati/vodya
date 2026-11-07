import AppKit
import Foundation

/// User-supplied artwork, copied into Application Support so a config file never
/// points at a path that can move or disappear. Only PNG files are accepted.
enum Assets {
    static var directory: URL {
        CardStore.supportDirectory.appendingPathComponent("Assets", isDirectory: true)
    }

    private static var cache: [String: NSImage] = [:]
    private static let pngSignature: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]

    static func image(_ fileName: String?) -> NSImage? {
        guard let fileName, !fileName.isEmpty else { return nil }
        if let cached = cache[fileName] { return cached }
        let url = directory.appendingPathComponent(fileName)
        guard let image = NSImage(contentsOf: url) else { return nil }
        cache[fileName] = image
        return image
    }

    static func exists(_ fileName: String) -> Bool {
        FileManager.default.fileExists(atPath: directory.appendingPathComponent(fileName).path)
    }

    /// Validates and copies a PNG into the assets folder, returning its file name.
    static func importPNG(from source: URL) throws -> String {
        guard source.pathExtension.lowercased() == "png" else { throw AssetError.notPNG }
        let data: Data
        do {
            data = try Data(contentsOf: source)
        } catch {
            throw AssetError.unreadable
        }
        // A .png extension is not proof: check the file signature and that
        // AppKit can actually decode it.
        guard data.count > 8, Array(data.prefix(8)) == pngSignature,
              NSBitmapImageRep(data: data) != nil else {
            throw AssetError.notPNG
        }

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let name = UUID().uuidString + ".png"
        try data.write(to: directory.appendingPathComponent(name))
        return name
    }

    static func remove(_ fileName: String?) {
        guard let fileName, !fileName.isEmpty else { return }
        try? FileManager.default.removeItem(at: directory.appendingPathComponent(fileName))
        cache[fileName] = nil
    }

    enum AssetError: LocalizedError {
        case notPNG
        case unreadable

        var errorDescription: String? {
            switch self {
            case .notPNG: return "Vodya only accepts PNG images."
            case .unreadable: return "That file could not be read."
            }
        }
    }
}
