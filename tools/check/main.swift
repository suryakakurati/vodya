// End-to-end check: media-control -> JSON -> TrackInfo.
import AppKit
import Foundation

let service = NowPlayingService()
print("binary found: \(service.isAvailable)")
service.refresh()
RunLoop.main.run(until: Date().addingTimeInterval(2.5))
let t = service.track
print("title:      \(t.title)")
print("artist:     \(t.artist)")
print("album:      \(t.album)")
print("playing:    \(t.isPlaying)")
print("duration:   \(Int(t.duration))s  position: \(Int(t.position(at: Date())))s")
print("artwork:    \(t.artwork.map { "\($0.size.width)x\($0.size.height)" } ?? "none")")
