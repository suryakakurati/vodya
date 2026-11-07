import AppKit
import SwiftUI

struct ContentView: View {
    @ObservedObject var service: NowPlayingService
    @ObservedObject var store: CardStore
    /// Off in the offline preview renderer, where NSVisualEffectView cannot rasterize.
    var blurredBackground: Bool? = nil

    private var config: CardConfig { store.config }

    private var blurEnabled: Bool {
        blurredBackground ?? (config.appearance.material == "blur")
    }

    /// A user PNG wins over the palette's bundled artwork.
    private var artworkImage: NSImage? {
        if let custom = config.appearance.customBackground, let image = Assets.image(custom) {
            return image
        }
        return BackgroundAsset.image(named: Theme.backgroundImage)
    }

    /// True when artwork is drawn behind the card.
    private var onArtwork: Bool {
        artworkImage != nil && config.appearance.material != "solid"
    }

    private var glowStrength: Double {
        config.appearance.glowEnabled ? min(max(config.appearance.glowStrength, 0), 1) : 0
    }

    private var glowColor: Color {
        Theme.color(hex: config.appearance.glowColor) ?? Theme.glow
    }

    /// Drawn behind the clipped card, so only the bloom outside its edge shows.
    /// A filled shape gives the halo body; the thin stroke keeps the rim crisp.
    private var glowLayer: some View {
        ZStack {
            shape
                .fill(glowColor)
                .blur(radius: 10 + 10 * glowStrength)
                .opacity(0.6 * glowStrength)
            shape
                .strokeBorder(glowColor, lineWidth: 1.5 + glowStrength)
                .blur(radius: 2 + 3 * glowStrength)
                .opacity(0.8 * glowStrength)
                .padding(-(2 + 3 * glowStrength))
        }
    }

    private var metrics: CardMetrics { store.metrics }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: config.appearance.cornerRadius, style: .continuous)
    }

    var body: some View {
        let metrics = self.metrics
        card(metrics)
            .padding(metrics.padding)
            .frame(width: metrics.cardWidth, height: metrics.cardHeight, alignment: .topLeading)
    }

    private func card(_ metrics: CardMetrics) -> some View {
        HStack(spacing: 0) {
            content(metrics)
            if metrics.showFigure {
                figure(metrics)
            }
        }
        .frame(
            width: metrics.contentWidth + metrics.figureWidth,
            height: metrics.figureHeight,
            alignment: .leading
        )
        .background(background)
        .clipShape(shape)
        .background(glowLayer)
        .overlay(shape.strokeBorder(Theme.surface1, lineWidth: 2 * max(0.85, metrics.scale)))
        .overlay(
            shape.strokeBorder(
                LinearGradient(
                    colors: [Theme.accent.opacity(0.35), Theme.accentAlt.opacity(0.10), .clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
        )
    }

    private var background: some View {
        ZStack {
            if onArtwork, let image = artworkImage {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .scaleEffect(1.02)
                    .saturation(1.22)
                    .blur(radius: 0.5)

                // Directional veil: darkest under the text column, letting the
                // artwork breathe behind the figure on the right.
                LinearGradient(
                    stops: [
                        .init(color: Theme.mantle.opacity(0.40), location: 0.0),
                        .init(color: Theme.mantle.opacity(0.34), location: 0.40),
                        .init(color: Theme.mantle.opacity(0.20), location: 0.62),
                        .init(color: Theme.mantle.opacity(0.06), location: 0.82),
                        .init(color: Theme.mantle.opacity(0.02), location: 1.0),
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            } else {
                if blurEnabled {
                    BlurView()
                }
                LinearGradient(
                    colors: [Theme.base.opacity(0.97), Theme.mantle.opacity(0.95)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }

            RadialGradient(
                colors: [Theme.glow.opacity(onArtwork ? 0.07 : 0.20), .clear],
                center: UnitPoint(x: 0.22, y: 0.06),
                startRadius: 0,
                endRadius: 430
            )
        }
    }

    // MARK: - Content column

    private func content(_ metrics: CardMetrics) -> some View {
        VStack(alignment: .leading, spacing: 13 * metrics.scale) {
            Text("NOW PLAYING")
                .font(Theme.mono(8.5 * metrics.scale, bold: true))
                .tracking(1.6 * metrics.scale)
                .foregroundStyle(onArtwork ? Color.white.opacity(0.9) : Theme.overlay0)

            header(metrics)
            progressSection(metrics)
            controls(metrics)
        }
        .padding(.leading, 18 * metrics.scale)
        .padding(.trailing, 10 * metrics.scale)
        .padding(.vertical, 15 * metrics.scale)
        .frame(width: metrics.contentWidth, alignment: .leading)
        .shadow(color: onArtwork ? Color.black.opacity(0.85) : .clear, radius: 1.5, x: 0, y: 1)
        .shadow(color: onArtwork ? Color.black.opacity(0.45) : .clear, radius: 7, x: 0, y: 2)
    }

    private func header(_ metrics: CardMetrics) -> some View {
        HStack(alignment: .center, spacing: 12 * metrics.scale) {
            artwork(metrics)

            VStack(alignment: .leading, spacing: 3 * metrics.scale) {
                Text(service.track.hasTrack ? service.track.title : "Nothing playing")
                    .font(Theme.mono(14.5 * metrics.scale, bold: true))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Text(subtitle)
                    .font(Theme.mono(11 * metrics.scale))
                    .foregroundStyle(service.track.hasTrack ? Theme.accent : Theme.overlay1)
                    .lineLimit(1)

                if service.track.hasTrack {
                    Text(service.track.album.isEmpty ? "Unknown album" : service.track.album)
                        .font(Theme.mono(9.5 * metrics.scale))
                        .foregroundStyle(onArtwork ? Color.white : Theme.overlay1)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
            pinButton(metrics)
        }
        .frame(height: 60 * metrics.scale)
    }

    private var subtitle: String {
        guard service.track.hasTrack else {
            return service.isAvailable ? "Open Spotify or Music" : "media-control not found"
        }
        return service.track.artist.isEmpty ? "Unknown artist" : service.track.artist
    }

    private func artwork(_ metrics: CardMetrics) -> some View {
        let side = 60 * metrics.scale
        let radius = 9 * metrics.scale
        return ZStack {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(Theme.surface0)
            if let image = service.track.artwork {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Image(systemName: "music.note")
                    .font(.system(size: 20 * metrics.scale, weight: .medium))
                    .foregroundStyle(onArtwork ? Color.white : Theme.overlay1)
            }
        }
        .frame(width: side, height: side)
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(Theme.surface1, lineWidth: 1.5 * max(0.8, metrics.scale))
        )
    }

    private func pinButton(_ metrics: CardMetrics) -> some View {
        Button {
            store.update { $0.behavior.pinned.toggle() }
        } label: {
            Image(systemName: config.behavior.pinned ? "pin.fill" : "pin")
                .font(.system(size: 10 * metrics.scale, weight: .semibold))
                .foregroundStyle(config.behavior.pinned ? Theme.accent : (onArtwork ? Theme.subtext0 : Theme.overlay1))
                .frame(width: 18 * metrics.scale, height: 18 * metrics.scale)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(config.behavior.pinned ? "Unpin from the screen" : "Keep on screen")
    }

    // MARK: - Progress

    private func progressSection(_ metrics: CardMetrics) -> some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { context in
            let position = service.track.hasTrack ? service.track.position(at: context.date) : 0
            let duration = max(service.track.duration, 0)
            VStack(spacing: 5 * metrics.scale) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Theme.surface1)
                            .frame(height: 4 * metrics.scale)
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Theme.accent, Theme.accentAlt],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(
                                width: duration > 0
                                    ? max(4, geometry.size.width * min(position / duration, 1))
                                    : 0,
                                height: 4 * metrics.scale
                            )
                    }
                }
                .frame(height: 4 * metrics.scale)

                HStack {
                    Text(timeString(position))
                    Spacer(minLength: 0)
                    Text(timeString(duration))
                }
                .font(Theme.mono(9 * metrics.scale))
                .foregroundStyle(onArtwork ? Color.white : Theme.overlay1)
            }
        }
    }

    // MARK: - Controls

    private func controls(_ metrics: CardMetrics) -> some View {
        HStack(spacing: 4 * metrics.scale) {
            IconButton(symbol: "shuffle", size: 12 * metrics.scale, scale: metrics.scale, tint: onArtwork ? Color.white.opacity(0.85) : Theme.overlay1, help: "Shuffle") {
                service.send(.shuffle)
            }
            IconButton(symbol: "backward.fill", size: 13 * metrics.scale, scale: metrics.scale, tint: onArtwork ? Color.white.opacity(0.95) : Theme.subtext0, help: "Previous") {
                service.send(.previous)
            }
            IconButton(symbol: "gobackward.15", size: 13 * metrics.scale, scale: metrics.scale, tint: onArtwork ? Color.white.opacity(0.95) : Theme.subtext0, help: "Back 15s (←)") {
                service.send(.backward15)
            }
            playButton(metrics)
            IconButton(symbol: "goforward.15", size: 13 * metrics.scale, scale: metrics.scale, tint: onArtwork ? Color.white.opacity(0.95) : Theme.subtext0, help: "Forward 15s (→)") {
                service.send(.forward15)
            }
            IconButton(symbol: "forward.fill", size: 13 * metrics.scale, scale: metrics.scale, tint: onArtwork ? Color.white.opacity(0.95) : Theme.subtext0, help: "Next") {
                service.send(.next)
            }
            IconButton(symbol: "repeat", size: 12 * metrics.scale, scale: metrics.scale, tint: onArtwork ? Color.white.opacity(0.85) : Theme.overlay1, help: "Repeat") {
                service.send(.repeatMode)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .disabled(!service.track.hasTrack)
        .opacity(service.track.hasTrack ? 1 : 0.4)
    }

    private func playButton(_ metrics: CardMetrics) -> some View {
        Button {
            service.send(.togglePlayPause)
        } label: {
            ZStack {
                Circle().fill(Theme.surface0)
                Circle().strokeBorder(Theme.surface1, lineWidth: 2 * max(0.8, metrics.scale))
                Image(systemName: service.track.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 13 * metrics.scale, weight: .bold))
                    .foregroundStyle(Theme.accent)
                    .offset(x: service.track.isPlaying ? 0 : 1)
            }
            .frame(width: 34 * metrics.scale, height: 34 * metrics.scale)
        }
        .buttonStyle(.plain)
        .help(service.track.isPlaying ? "Pause (space)" : "Play (space)")
    }

    // MARK: - Figure

    private func figure(_ metrics: CardMetrics) -> some View {
        ZStack(alignment: .bottom) {
            Ellipse()
                .fill(Theme.glow.opacity(0.22))
                .frame(width: 186 * metrics.scale, height: 168 * metrics.scale)
                .blur(radius: 58 * metrics.scale)
                .offset(y: 18 * metrics.scale)

            if let image = store.figureImage {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: metrics.figureHeight)
                    .opacity(service.track.isPlaying ? 1 : 0.62)
                    .animation(.easeInOut(duration: 0.4), value: service.track.isPlaying)
            }
        }
        .frame(width: metrics.figureWidth, height: metrics.figureHeight, alignment: .bottom)
        .allowsHitTesting(false)
    }

    private func timeString(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds > 0 else { return "0:00" }
        let total = Int(seconds.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

private struct IconButton: View {
    let symbol: String
    let size: CGFloat
    let scale: CGFloat
    let tint: Color
    let help: String
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(hovering ? Theme.text : tint)
                .frame(width: size + 14 * scale, height: size + 14 * scale)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(help)
    }
}

struct BlurView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
