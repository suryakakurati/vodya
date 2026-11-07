import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct PreferencesView: View {
    @ObservedObject var store: CardStore

    @State private var selectedPresetID = ""
    @State private var presetName = ""
    @State private var savingPreset = false
    @State private var errorMessage: String?
    @State private var showingError = false

    private var config: CardConfig { store.config }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            presetSection
            sizeSection
            paletteSection
            accentSection
            HStack(alignment: .top, spacing: 16) {
                materialSection
                cornerSection
            }
            glowSection
            artworkSection
            toggles
            pollSection
            Divider()
            footer
        }
        .padding(20)
        .frame(width: 440, alignment: .leading)
        .onAppear { syncSelection() }
        .onChange(of: store.presets) { _, _ in syncSelection() }
        .alert("Save the current look as a preset", isPresented: $savingPreset) {
            TextField("Preset name", text: $presetName)
            Button("Cancel", role: .cancel) { presetName = "" }
            Button("Save") {
                store.savePreset(named: presetName)
                presetName = ""
                syncSelection()
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Vodya").font(.system(size: 15, weight: .semibold))
            Text("Changes apply immediately and are saved to config.json.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Presets

    private var presetSection: some View {
        section("Presets") {
            HStack(spacing: 8) {
                Picker("", selection: $selectedPresetID) {
                    if store.presets.isEmpty {
                        Text("No presets yet").tag("")
                    }
                    ForEach(store.presets) { preset in
                        Text(preset.name).tag(preset.id)
                    }
                }
                .labelsHidden()
                .frame(width: 150)

                Button("Apply") {
                    if let preset = selectedPreset { store.applyPreset(preset) }
                }
                .disabled(selectedPreset == nil)

                Button("Delete") {
                    guard let preset = selectedPreset else { return }
                    store.deletePreset(id: preset.id)
                    selectedPresetID = ""
                    syncSelection()
                }
                .disabled(selectedPreset == nil)

                Spacer(minLength: 0)

                Button("Save current…") {
                    presetName = suggestedPresetName
                    savingPreset = true
                }
            }
            .font(.system(size: 11))
        }
    }

    private var selectedPreset: CardPreset? {
        store.presets.first { $0.id == selectedPresetID }
    }

    private var suggestedPresetName: String {
        Palettes.named(config.appearance.palette).name
    }

    private func syncSelection() {
        if !store.presets.contains(where: { $0.id == selectedPresetID }) {
            selectedPresetID = store.presets.first?.id ?? ""
        }
    }

    // MARK: - Look

    private var sizeSection: some View {
        section("Size") {
            Picker("", selection: binding(\.appearance.size)) {
                Text("Small").tag("small")
                Text("Medium").tag("medium")
                Text("Large").tag("large")
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }

    private var paletteSection: some View {
        section("Palette") {
            HStack(spacing: 12) {
                ForEach(Palettes.all) { entry in
                    swatch(entry)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func swatch(_ entry: PaletteEntry) -> some View {
        let selected = config.appearance.palette == entry.id
        return Button {
            store.update { $0.appearance.palette = entry.id }
        } label: {
            VStack(spacing: 5) {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [entry.palette.accent, entry.palette.base],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 26, height: 26)
                    .overlay(
                        Circle().strokeBorder(
                            selected ? Color.accentColor : Color.secondary.opacity(0.35),
                            lineWidth: selected ? 2 : 1
                        )
                    )
                Text(entry.name)
                    .font(.system(size: 9))
                    .foregroundStyle(selected ? .primary : .secondary)
            }
        }
        .buttonStyle(.plain)
    }

    private var accentSection: some View {
        section("Accent") {
            Picker("", selection: binding(\.appearance.accent)) {
                Text("Auto").tag("auto")
                Text("Pink").tag("pink")
                Text("Lavender").tag("lavender")
                Text("Mist").tag("mist")
                Text("Gold").tag("gold")
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }

    private var materialSection: some View {
        section("Material") {
            Picker("", selection: binding(\.appearance.material)) {
                Text("Blur").tag("blur")
                Text("Solid").tag("solid")
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 150)
        }
    }

    private var cornerSection: some View {
        section("Corner radius") {
            HStack(spacing: 8) {
                Slider(value: binding(\.appearance.cornerRadius), in: 0...28, step: 1)
                Text("\(Int(config.appearance.cornerRadius))")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(width: 22, alignment: .trailing)
            }
        }
    }

    // MARK: - Edge light

    private var glowSection: some View {
        section("Edge light") {
            VStack(alignment: .leading, spacing: 8) {
                Toggle("Light around the border", isOn: binding(\.appearance.glowEnabled))
                    .toggleStyle(.switch)
                    .font(.system(size: 12))

                HStack(spacing: 8) {
                    Slider(value: binding(\.appearance.glowStrength), in: 0...1, step: 0.05)
                        .disabled(!config.appearance.glowEnabled)
                    Text(String(format: "%.0f%%", config.appearance.glowStrength * 100))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: 38, alignment: .trailing)
                    ColorPicker("", selection: glowColorBinding, supportsOpacity: false)
                        .labelsHidden()
                        .disabled(!config.appearance.glowEnabled)
                    Button("Auto") {
                        store.update { $0.appearance.glowColor = "auto" }
                    }
                    .disabled(config.appearance.glowColor == "auto")
                }
                .font(.system(size: 11))
            }
        }
    }

    private var glowColorBinding: Binding<Color> {
        Binding(
            get: { Theme.color(hex: config.appearance.glowColor) ?? Theme.glow },
            set: { newValue in
                let hex = Theme.hex(from: newValue)
                store.update { $0.appearance.glowColor = hex }
            }
        )
    }

    // MARK: - Custom art

    private var artworkSection: some View {
        section("Artwork") {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Button("Background image…") {
                        pickImage([.image]) { name in store.update { $0.appearance.customBackground = name } }
                    }
                    Button("Clear") {
                        store.update { $0.appearance.customBackground = nil }
                    }
                    .disabled(config.appearance.customBackground == nil)
                    Spacer(minLength: 0)
                }
                HStack(spacing: 8) {
                    Button("Character PNG…") {
                        pickImage([.png]) { name in store.update { $0.appearance.customFigure = name } }
                    }
                    Button("Clear") {
                        store.update { $0.appearance.customFigure = nil }
                    }
                    .disabled(config.appearance.customFigure == nil)
                    Spacer(minLength: 0)
                }
                Text("The background can be any image; the character must be a PNG so it keeps its transparency. Files are copied into Application Support/Vodya/Assets.")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .font(.system(size: 11))
        }
        .alert("That image can't be used", isPresented: $showingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func pickImage(_ types: [UTType], _ apply: @escaping (String) -> Void) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = types
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = types == [.png] ? "Choose a PNG image" : "Choose an image"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let name = types == [.png]
                ? try Assets.importPNG(from: url)
                : try Assets.importImage(from: url)
            apply(name)
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }

    // MARK: - Behaviour

    private var toggles: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Show the figure", isOn: binding(\.appearance.showFigure))
            Toggle("Keep on screen (pinned)", isOn: binding(\.behavior.pinned))
            Toggle("Close when clicking outside", isOn: binding(\.behavior.closeOnClickOutside))
        }
        .toggleStyle(.switch)
        .font(.system(size: 12))
    }

    private var pollSection: some View {
        section("Refresh interval") {
            HStack(spacing: 8) {
                Slider(value: binding(\.behavior.pollInterval), in: 0.5...5, step: 0.5)
                Text(String(format: "%.1fs", config.behavior.pollInterval))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(width: 40, alignment: .trailing)
            }
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Button("Edit config.json") { NSWorkspace.shared.open(store.fileURL) }
                Button("Reveal") { NSWorkspace.shared.activateFileViewerSelecting([store.fileURL]) }
                Spacer(minLength: 0)
                Button("Reset") { store.resetToDefaults() }
            }
            .font(.system(size: 11))

            Text("\(HotKeySpec.label(config.behavior.hotkey)) toggles the card · \(HotKeySpec.label(config.behavior.pinHotkey)) pins it · both are editable in config.json")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.7)
                .foregroundStyle(.secondary)
            content()
        }
    }

    private func binding<T>(_ keyPath: WritableKeyPath<CardConfig, T>) -> Binding<T> {
        Binding(
            get: { store.config[keyPath: keyPath] },
            set: { value in store.update { $0[keyPath: keyPath] = value } }
        )
    }
}
