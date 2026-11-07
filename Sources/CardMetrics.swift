import AppKit

/// Every dimension the card needs, derived from a single scale factor so the
/// window and its content can never disagree about size.
struct CardMetrics {
    static let baseContentWidth: CGFloat = 340
    static let baseCardHeight: CGFloat = 268
    static let basePadding: CGFloat = 8
    static let baseFigureHeight: CGFloat = 252

    let scale: CGFloat
    let showFigure: Bool
    let figureAspect: CGFloat

    init(
        size: String,
        showFigure: Bool,
        figureAspect: CGFloat = FigureAsset.aspect
    ) {
        switch Self.normalizedSize(size) {
        case "small": scale = 0.85
        case "large": scale = 1.2
        default: scale = 1.0
        }
        self.showFigure = showFigure
        self.figureAspect = min(max(figureAspect, 0.3), 1.5)
    }

    static func normalizedSize(_ raw: String) -> String {
        switch raw.lowercased() {
        case "small", "compact": return "small"
        case "large", "big": return "large"
        default: return "medium"
        }
    }

    var padding: CGFloat { Self.basePadding * scale }
    var contentWidth: CGFloat { Self.baseContentWidth * scale }
    var figureHeight: CGFloat { Self.baseFigureHeight * scale }
    var figureWidth: CGFloat { showFigure ? (figureHeight * figureAspect).rounded() : 0 }
    var cardWidth: CGFloat { (padding * 2 + contentWidth + figureWidth).rounded() }
    var cardHeight: CGFloat { (Self.baseCardHeight * scale).rounded() }
    var size: NSSize { NSSize(width: cardWidth, height: cardHeight) }
}
