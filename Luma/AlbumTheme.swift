import SwiftUI

private struct AlbumTintKey: EnvironmentKey {
    static let defaultValue = ArtworkTint.neutral
}

extension EnvironmentValues {
    var albumTint: ArtworkTint {
        get { self[AlbumTintKey.self] }
        set { self[AlbumTintKey.self] = newValue }
    }
}

struct AlbumTheme: ViewModifier {
    @Environment(MusicPlayer.self) private var player
    @State private var tint = ArtworkTint.neutral

    func body(content: Content) -> some View {
        content.environment(\.albumTint, tint)
            .task(id: player.current) {
                let url = player.artworkSource(for: player.current)
                let asset = if let url { await ArtworkLoader.shared.load(url) } else { nil as ArtworkAsset? }
                guard !Task.isCancelled else { return }
                tint = asset?.tint ?? .neutral
            }
    }
}

struct AppBackground: View {
    @Environment(\.albumTint) private var tint
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var strength: Double = 0.24
    var coverTint: ArtworkTint?

    var body: some View {
        GeometryReader { geometry in
            let tint = coverTint ?? self.tint
            // Dark covers still get a visible, low-opacity wash of their own hue.
            let peak = max(tint.red, tint.green, tint.blue)
            let chroma = peak - min(tint.red, tint.green, tint.blue)
            let lift = chroma > 0.04 ? max(1, 0.8 / peak) : 1
            let color = Color(red: tint.red * lift, green: tint.green * lift, blue: tint.blue * lift)
            ZStack {
                Theme.background
                RadialGradient(colors: [color.opacity(strength), color.opacity(strength * 0.35), .clear],
                               center: UnitPoint(x: 0.26, y: 0.13), startRadius: 0, endRadius: geometry.size.height * 0.83)
                LinearGradient(colors: [.clear, Theme.background.opacity(0.18), Theme.background],
                               startPoint: .top, endPoint: .bottom)
            }
        }
        .ignoresSafeArea()
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.45), value: coverTint ?? tint)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
