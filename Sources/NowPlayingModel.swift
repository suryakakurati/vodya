import AppKit
import Foundation

struct TrackInfo: Equatable {
    var title: String = ""
    var artist: String = ""
    var album: String = ""
    var isPlaying: Bool = false
    var elapsed: Double = 0
    var duration: Double = 0
    var timestamp: Date?
    var artwork: NSImage?
    var artworkKey: String = ""
    var sourceBundleID: String = ""

    static let idle = TrackInfo()

    var hasTrack: Bool { !title.isEmpty }

    /// Estimated playhead, interpolated from the polled elapsed time.
    func position(at date: Date) -> Double {
        guard duration > 0 else { return max(elapsed, 0) }
        if isPlaying, let timestamp {
            return min(max(elapsed + date.timeIntervalSince(timestamp), 0), duration)
        }
        return min(max(elapsed, 0), duration)
    }

    func progress(at date: Date) -> Double {
        guard duration > 0 else { return 0 }
        return min(max(position(at: date) / duration, 0), 1)
    }

    static func == (lhs: TrackInfo, rhs: TrackInfo) -> Bool {
        lhs.title == rhs.title
            && lhs.artist == rhs.artist
            && lhs.album == rhs.album
            && lhs.isPlaying == rhs.isPlaying
            && lhs.duration == rhs.duration
            && lhs.artworkKey == rhs.artworkKey
    }
}

final class NowPlayingService: ObservableObject {
    enum Command: String {
        case togglePlayPause = "toggle-play-pause"
        case next = "next-track"
        case previous = "previous-track"
        case forward15 = "skip-fifteen-seconds"
        case backward15 = "go-back-fifteen-seconds"
        case shuffle = "toggle-shuffle"
        case repeatMode = "toggle-repeat"
    }

    @Published private(set) var track: TrackInfo = .idle

    private let binary: URL?
    private var timer: Timer?
    private var isPolling = false
    private var lastArtworkKey = ""
    private var cachedArtwork: NSImage?

    init() {
        binary = Self.locateBinary()
    }

    /// Offline instance for previews: fixed track, no polling, no CLI.
    init(snapshot: TrackInfo) {
        binary = nil
        track = snapshot
    }

    private static func locateBinary() -> URL? {
        let candidates = [
            "/opt/homebrew/bin/media-control",
            "/usr/local/bin/media-control",
            "/usr/bin/media-control",
        ]
        return candidates
            .first { FileManager.default.isExecutableFile(atPath: $0) }
            .map { URL(fileURLWithPath: $0) }
    }

    var isAvailable: Bool { binary != nil }

    func startPolling(interval: TimeInterval = 1.0) {
        stopPolling()
        refresh()
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stopPolling() {
        timer?.invalidate()
        timer = nil
    }

    func refresh() {
        guard !isPolling, let binary else { return }
        isPolling = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let output = Self.run(binary, ["get"])
            let parsed = Self.parse(output)
            DispatchQueue.main.async {
                guard let self else { return }
                self.apply(parsed)
                self.isPolling = false
            }
        }
    }

    func send(_ command: Command) {
        let knownSource = track.sourceBundleID
        let binary = self.binary
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let source = knownSource.isEmpty
                ? (binary.map(Self.currentSourceID) ?? "")
                : knownSource

            if source == Self.spotifyBundleID, let body = Self.scriptBody(for: command) {
                if !Self.runSpotifyScript(body) {
                    NSLog("Vodya: Spotify scripting failed for \(command.rawValue)")
                }
            } else if let binary {
                _ = Self.run(binary, [command.rawValue])
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.refresh()
            }
        }
    }

    // MARK: - Spotify

    /// Spotify ignores MediaRemote seeks, shuffle and repeat, so those four go
    /// through AppleScript instead. Playback and track skipping keep using
    /// media-control, which Spotify does honour.
    private static let spotifyBundleID = "com.spotify.client"

    private static func scriptBody(for command: Command) -> String? {
        switch command {
        case .forward15:
            return seekScript(by: 15)
        case .backward15:
            return seekScript(by: -15)
        case .shuffle:
            return "set shuffling to not shuffling"
        case .repeatMode:
            return "set repeating to not repeating"
        case .togglePlayPause, .next, .previous:
            return nil
        }
    }

    private static func seekScript(by seconds: Int) -> String {
        """
        set p to player position
        set d to (duration of current track) / 1000
        set t to p + \(seconds)
        if t < 0 then set t to 0
        if d > 0 and t > d - 1 then set t to d - 1
        set player position to t
        """
    }

    private static func runSpotifyScript(_ body: String) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", "tell application \"Spotify\"\n\(body)\nend tell"]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        do {
            try process.run()
        } catch {
            return false
        }
        process.waitUntilExit()
        return process.terminationStatus == 0
    }

    private static func currentSourceID(_ binary: URL) -> String {
        let output = run(binary, ["get", "--no-artwork"])
        guard let data = output.data(using: .utf8),
              let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        else { return "" }
        return (object["bundleIdentifier"] as? String) ?? ""
    }

    // MARK: - Parsing

    private func apply(_ raw: [String: Any]?) {
        guard let raw, let title = raw["title"] as? String, !title.isEmpty else {
            lastArtworkKey = ""
            cachedArtwork = nil
            track = .idle
            return
        }

        var next = TrackInfo()
        next.title = title
        next.artist = (raw["artist"] as? String) ?? ""
        next.album = (raw["album"] as? String) ?? ""
        next.isPlaying = (raw["playing"] as? Bool) ?? false
        next.elapsed = (raw["elapsedTime"] as? Double) ?? 0
        next.duration = (raw["duration"] as? Double) ?? 0
        next.sourceBundleID = (raw["bundleIdentifier"] as? String) ?? ""
        if let stamp = raw["timestamp"] as? String {
            next.timestamp = Self.isoFormatter.date(from: stamp)
        }

        if let art = raw["artworkData"] as? String, !art.isEmpty {
            let key = "\(art.count):\(art.prefix(48))"
            if key != lastArtworkKey {
                lastArtworkKey = key
                cachedArtwork = Data(base64Encoded: art).flatMap { NSImage(data: $0) }
            }
            next.artwork = cachedArtwork
            next.artworkKey = key
        } else {
            lastArtworkKey = ""
            cachedArtwork = nil
        }

        track = next
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static func parse(_ output: String) -> [String: Any]? {
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != "null", let data = trimmed.data(using: .utf8) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    private static func run(_ binary: URL, _ arguments: [String]) -> String {
        let process = Process()
        process.executableURL = binary
        process.arguments = arguments
        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = Pipe()
        do {
            try process.run()
        } catch {
            return ""
        }
        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(data: data, encoding: .utf8) ?? ""
    }
}
