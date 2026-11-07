// Logic checks for presets, PNG import validation and card sizing.
// Runs against an isolated support directory (VODYA_SUPPORT_DIR), never your real config.
import AppKit
import Foundation

var failures = 0
func check(_ label: String, _ condition: Bool) {
    print("\(condition ? "PASS" : "FAIL")  \(label)")
    if !condition { failures += 1 }
}

let store = CardStore()
check("defaults: glow on", store.config.appearance.glowEnabled)
check("defaults: glow strength", store.config.appearance.glowStrength > 0)
check("defaults: no custom art", store.config.appearance.customBackground == nil && store.config.appearance.customFigure == nil)

// Only genuine PNGs are accepted.
let jpeg = URL(fileURLWithPath: "assets/vodya-background.jpg")
do {
    _ = try Assets.importPNG(from: jpeg)
    check("jpeg rejected", false)
} catch {
    check("jpeg rejected", true)
}

let fake = Assets.directory.appendingPathComponent("fake.png")
try? FileManager.default.createDirectory(at: Assets.directory, withIntermediateDirectories: true)
try? Data(contentsOf: jpeg).write(to: fake)
do {
    _ = try Assets.importPNG(from: fake)
    check("jpeg renamed .png rejected", false)
} catch {
    check("jpeg renamed .png rejected", true)
}

let png = URL(fileURLWithPath: "assets/vodya-figure.png")
do {
    let name = try Assets.importPNG(from: png)
    let image = Assets.image(name)
    check("png imported", name.hasSuffix(".png") && image != nil)
    if let image {
        store.update { $0.appearance.customFigure = name }
        check("custom figure stored", store.config.appearance.customFigure == name)
        check("figure aspect follows custom art", abs(store.figureAspect - image.size.width / image.size.height) < 0.001)
    }
} catch {
    check("png imported", false)
}

// A stale asset name is dropped rather than breaking the card.
store.update { $0.appearance.customBackground = "missing.png" }
check("missing asset cleared", store.config.appearance.customBackground == nil)

// Presets round-trip the whole look.
store.update {
    $0.appearance.palette = "mist"
    $0.appearance.glowColor = "#FF00AA"
    $0.appearance.glowStrength = 0.8
}
store.savePreset(named: "  Test Mist  ")
check("preset saved and trimmed", store.presets.count == 1 && store.presets[0].name == "Test Mist")

store.update {
    $0.appearance.palette = "mono"
    $0.appearance.glowColor = "auto"
}
if let preset = store.presets.first { store.applyPreset(preset) }
check(
    "preset applied",
    store.config.appearance.palette == "mist"
        && store.config.appearance.glowColor == "#FF00AA"
        && store.config.appearance.glowStrength == 0.8
)
check("presets persisted", CardStore.readPresets(store.presetsURL).count == 1)

store.savePreset(named: "test mist")
check("same name updates in place", store.presets.count == 1)

store.deletePreset(id: store.presets[0].id)
check("preset deleted", store.presets.isEmpty && CardStore.readPresets(store.presetsURL).isEmpty)

// Glow colour parsing.
check("hex parses", Theme.color(hex: "#f8cadd") != nil)
if let color = Theme.color(hex: "#F8CADD") {
    check("hex round-trips", Theme.hex(from: color) == "#F8CADD")
}
check("bad hex rejected", Theme.color(hex: "not-a-colour") == nil)
store.update { $0.appearance.glowColor = "not-a-colour" }
check("bad glow colour reset", store.config.appearance.glowColor == "auto")

// Sizing follows the figure; the edge light sits on the border and adds no space.
let plain = CardMetrics(size: "medium", showFigure: true, figureAspect: 0.5)
let wideFigure = CardMetrics(size: "medium", showFigure: true, figureAspect: 0.9)
let noFigure = CardMetrics(size: "medium", showFigure: false, figureAspect: 0.5)
let tallFigure = CardMetrics(size: "medium", showFigure: true, figureAspect: 0.3)
check("figure aspect widens the slot", wideFigure.cardWidth > plain.cardWidth)
check("hiding the figure narrows the card", noFigure.cardWidth < plain.cardWidth)
check("figure aspect leaves the height alone", tallFigure.cardHeight == plain.cardHeight)

print(failures == 0 ? "ALL PASS" : "\(failures) FAILURE(S)")
exit(failures == 0 ? 0 : 1)
