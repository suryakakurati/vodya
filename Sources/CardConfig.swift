import AppKit
import Darwin
import Foundation
import SwiftUI

extension KeyedDecodingContainer {
    /// Decodes a value when present and well typed, otherwise keeps the fallback.
    /// Keeps a hand-edited config.json from failing to load over one bad key.
    func lenient<T: Decodable>(_ key: Key, _ fallback: T) -> T {
        ((try? decodeIfPresent(T.self, forKey: key)) ?? nil) ?? fallback
    }
}

struct CardConfig: Codable, Equatable {
    static let defaultHotKey = "option+p"
    static let defaultPinHotKey = "option+shift+p"

    struct Appearance: Codable, Equatable {
        var size: String = "medium"
        var palette: String = "petal"
        var material: String = "blur"
        var showFigure: Bool = true
        var cornerRadius: Double = 16
        var accent: String = "auto"
        /// File name inside Application Support/Vodya/Assets, never an absolute path.
        var customBackground: String? = nil
        var customFigure: String? = nil
        var glowEnabled: Bool = true
        var glowStrength: Double = 0.4
        /// "auto" follows the accent, otherwise "#RRGGBB".
        var glowColor: String = "auto"

        init() {}

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let fallback = Appearance()
            size = container.lenient(.size, fallback.size)
            palette = container.lenient(.palette, fallback.palette)
            material = container.lenient(.material, fallback.material)
            showFigure = container.lenient(.showFigure, fallback.showFigure)
            cornerRadius = container.lenient(.cornerRadius, fallback.cornerRadius)
            accent = container.lenient(.accent, fallback.accent)
            customBackground = container.lenient(.customBackground, fallback.customBackground)
            customFigure = container.lenient(.customFigure, fallback.customFigure)
            glowEnabled = container.lenient(.glowEnabled, fallback.glowEnabled)
            glowStrength = container.lenient(.glowStrength, fallback.glowStrength)
            glowColor = container.lenient(.glowColor, fallback.glowColor)
        }
    }

    struct Behavior: Codable, Equatable {
        var pinned: Bool = false
        var closeOnClickOutside: Bool = true
        var pollInterval: Double = 1.0
        var hotkey: String = CardConfig.defaultHotKey
        var pinHotkey: String = CardConfig.defaultPinHotKey

        init() {}

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let fallback = Behavior()
            pinned = container.lenient(.pinned, fallback.pinned)
            closeOnClickOutside = container.lenient(.closeOnClickOutside, fallback.closeOnClickOutside)
            pollInterval = container.lenient(.pollInterval, fallback.pollInterval)
            hotkey = container.lenient(.hotkey, fallback.hotkey)
            pinHotkey = container.lenient(.pinHotkey, fallback.pinHotkey)
        }
    }

    var appearance = Appearance()
    var behavior = Behavior()

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = CardConfig()
        appearance = container.lenient(.appearance, fallback.appearance)
        behavior = container.lenient(.behavior, fallback.behavior)
    }
}

/// A named snapshot of the look, so a whole theme can be recalled in one click.
struct CardPreset: Codable, Identifiable, Equatable {
    var id: String
    var name: String
    var appearance: CardConfig.Appearance

    init(id: String = UUID().uuidString, name: String, appearance: CardConfig.Appearance) {
        self.id = id
        self.name = name
        self.appearance = appearance
    }
}

/// Persisted appearance/behaviour, mirrored to a human-editable config.json and
/// hot-reloaded when that file changes on disk. Presets live beside it.
final class CardStore: ObservableObject {
    @Published private(set) var config: CardConfig
    @Published private(set) var presets: [CardPreset]

    let fileURL: URL
    let presetsURL: URL
    private let isPreview: Bool
    private var watcher: DispatchSourceFileSystemObject?
    private var reloadWork: DispatchWorkItem?

    static var supportDirectory: URL {
        if let override = ProcessInfo.processInfo.environment["VODYA_SUPPORT_DIR"], !override.isEmpty {
            return URL(fileURLWithPath: override, isDirectory: true)
        }
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Vodya", isDirectory: true)
    }

    static var defaultFileURL: URL {
        supportDirectory.appendingPathComponent("config.json")
    }

    static var defaultPresetsURL: URL {
        supportDirectory.appendingPathComponent("presets.json")
    }

    init(preview: CardConfig? = nil) {
        let previewing = preview != nil
        isPreview = previewing
        fileURL = Self.defaultFileURL
        presetsURL = Self.defaultPresetsURL

        let loaded = Self.normalized(preview ?? Self.read(fileURL) ?? CardConfig())
        config = loaded
        presets = Self.readPresets(presetsURL)
        Theme.apply(Palettes.resolve(name: loaded.appearance.palette, accent: loaded.appearance.accent))

        guard !previewing else { return }
        Self.write(config, to: fileURL)
        startWatching()
    }

    deinit {
        reloadWork?.cancel()
        watcher?.cancel()
    }

    func update(_ mutate: (inout CardConfig) -> Void) {
        var next = config
        mutate(&next)
        next = Self.normalized(next)
        guard next != config else { return }
        apply(next)
        if !isPreview { Self.write(next, to: fileURL) }
    }

    func reloadFromDisk() {
        guard !isPreview, let loaded = Self.read(fileURL) else { return }
        let next = Self.normalized(loaded)
        guard next != config else { return }
        apply(next)
        NSLog("Vodya: config reloaded (size \(next.appearance.size), palette \(next.appearance.palette), pinned \(next.behavior.pinned))")
    }

    func resetToDefaults() {
        update { $0 = CardConfig() }
    }

    // MARK: - Presets

    func savePreset(named raw: String) {
        let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        var next = presets
        if let index = next.firstIndex(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
            next[index].appearance = config.appearance
        } else {
            next.append(CardPreset(name: name, appearance: config.appearance))
        }
        setPresets(next)
    }

    func applyPreset(_ preset: CardPreset) {
        update { $0.appearance = preset.appearance }
    }

    func deletePreset(id: String) {
        setPresets(presets.filter { $0.id != id })
    }

    private func setPresets(_ next: [CardPreset]) {
        presets = next
        guard !isPreview else { return }
        Self.writePresets(next, to: presetsURL)
    }

    // MARK: - Artwork

    var figureImage: NSImage? {
        Assets.image(config.appearance.customFigure) ?? FigureAsset.image
    }

    var figureAspect: CGFloat {
        guard let size = figureImage?.size, size.height > 0 else { return FigureAsset.aspect }
        return size.width / size.height
    }

    /// The single source of truth for card size, including the room a glow needs.
    var metrics: CardMetrics {
        CardMetrics(
            size: config.appearance.size,
            showFigure: config.appearance.showFigure,
            figureAspect: figureAspect,
            glowInset: config.appearance.glowEnabled ? 10 * config.appearance.glowStrength : 0
        )
    }

    private func apply(_ next: CardConfig) {
        config = next
        Theme.apply(Palettes.resolve(name: next.appearance.palette, accent: next.appearance.accent))
    }

    // MARK: - Validation

    private static func normalized(_ input: CardConfig) -> CardConfig {
        var next = input
        next.appearance.size = CardMetrics.normalizedSize(next.appearance.size)
        next.appearance.material = next.appearance.material.lowercased() == "solid" ? "solid" : "blur"
        if !Palettes.all.contains(where: { $0.id == next.appearance.palette }) {
            next.appearance.palette = "petal"
        }
        if !Palettes.accentIDs.contains(next.appearance.accent) {
            next.appearance.accent = "auto"
        }
        next.appearance.cornerRadius = min(max(next.appearance.cornerRadius, 0), 28)
        next.appearance.glowStrength = min(max(next.appearance.glowStrength, 0), 1)
        if next.appearance.glowColor != "auto", Theme.color(hex: next.appearance.glowColor) == nil {
            next.appearance.glowColor = "auto"
        }
        if let name = next.appearance.customBackground, !Assets.exists(name) {
            next.appearance.customBackground = nil
        }
        if let name = next.appearance.customFigure, !Assets.exists(name) {
            next.appearance.customFigure = nil
        }
        next.behavior.pollInterval = min(max(next.behavior.pollInterval, 0.5), 5)
        if HotKeySpec.parse(next.behavior.hotkey) == nil {
            next.behavior.hotkey = CardConfig.defaultHotKey
        }
        if HotKeySpec.parse(next.behavior.pinHotkey) == nil {
            next.behavior.pinHotkey = CardConfig.defaultPinHotKey
        }
        return next
    }

    // MARK: - Disk

    static func read(_ url: URL) -> CardConfig? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(CardConfig.self, from: data)
    }

    static func write(_ config: CardConfig, to url: URL) {
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        guard let data = try? encoder.encode(config) else { return }
        // Deliberately non-atomic so the watched inode survives our own writes.
        try? data.write(to: url)
    }

    static func readPresets(_ url: URL) -> [CardPreset] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([CardPreset].self, from: data)) ?? []
    }

    static func writePresets(_ presets: [CardPreset], to url: URL) {
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        guard let data = try? encoder.encode(presets) else { return }
        try? data.write(to: url)
    }

    private func scheduleReload() {
        reloadWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.reloadFromDisk() }
        reloadWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: work)
    }

    private func startWatching() {
        stopWatching()
        try? FileManager.default.createDirectory(
            at: Self.supportDirectory,
            withIntermediateDirectories: true
        )
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            Self.write(config, to: fileURL)
        }

        let descriptor = open(fileURL.path, O_EVTONLY)
        guard descriptor >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .extend, .delete, .rename, .attrib],
            queue: .main
        )
        source.setEventHandler { [weak self] in
            guard let self, let watcher = self.watcher else { return }
            let flags = watcher.data
            if flags.contains(.delete) || flags.contains(.rename) {
                // An editor saved atomically: re-arm against the new inode.
                self.stopWatching()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                    self?.startWatching()
                    self?.reloadFromDisk()
                }
            } else {
                self.scheduleReload()
            }
        }
        source.setCancelHandler { close(descriptor) }
        source.resume()
        watcher = source
    }

    private func stopWatching() {
        watcher?.cancel()
        watcher = nil
    }
}
