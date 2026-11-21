// SPDX-License-Identifier: MIT
// Copyright (c) 2026 WillSuo
// Adapted from KaraokeText/Sources/KaraokeText/KaraokeRenderer.swift,
// 08697a112d314aa360f9b2ebed3622181ab58ad8. See ThirdParty/KaraokeText-MIT.txt.
// STRSK changes, 2026-11-21: fragments with supplied times, bidirectional
// layout, stable row geometry, and a restrained active-word envelope.
import SwiftUI

struct KaraokeFragmentAttribute: TextAttribute {
    let index: Int
}

struct KaraokeTextRenderer: TextRenderer {
    let fragments: [LyricWord]
    let time: TimeInterval
    let reduceMotion: Bool

    private struct Glyph {
        let slice: Text.Layout.RunSlice
        let bounds: CGRect
        let index: Int
        let offset: CGFloat
        let reversed: Bool
    }

    func draw(layout: Text.Layout, in context: inout GraphicsContext) {
        var widths = Array(repeating: CGFloat.zero, count: fragments.count)
        var items: [Glyph] = []
        for line in layout {
            for run in line {
                guard let index = run[KaraokeFragmentAttribute.self]?.index,
                      fragments.indices.contains(index) else {
                    context.draw(run)
                    continue
                }
                let reversed = run.layoutDirection == .rightToLeft
                let slices = run.sorted {
                    let lhs = $0.typographicBounds.rect.minX
                    let rhs = $1.typographicBounds.rect.minX
                    return reversed ? lhs > rhs : lhs < rhs
                }
                for slice in slices {
                    let bounds = slice.typographicBounds.rect
                    items.append(Glyph(slice: slice, bounds: bounds, index: index,
                                       offset: widths[index], reversed: reversed))
                    widths[index] += bounds.width
                }
            }
        }

        let progress = fragments.map { $0.progress(at: time) }
        for glyph in items {
            let fraction = progress[glyph.index]
            let total = widths[glyph.index]
            var base = context
            let active = fraction > 0 && fraction < 1
            let lift = active && !reduceMotion ? sin(.pi * fraction) : 0
            if lift > 0 { base.translateBy(x: 0, y: -1.6 * lift) }
            let rect = glyph.bounds.insetBy(dx: -1, dy: -2)

            // Unlit fill remains visible while a word approaches its onset.
            let unlit: Color = fragments[glyph.index].start == nil ? .white : .white.opacity(0.38)
            base.drawLayer { layer in
                layer.draw(glyph.slice)
                layer.blendMode = .sourceIn
                layer.fill(Path(rect), with: .color(unlit))
            }

            guard fraction > 0, total > 0, rect.width > 0 else { continue }
            let feather = min(9, max(3, total * 0.18))
            let edge = CGFloat(fraction) * (total + feather) - feather - glyph.offset
            guard fraction == 1 || edge + feather > 0 else { continue }
            if lift > 0.02 {
                base.addFilter(.shadow(color: Theme.accent.opacity(0.28 * lift), radius: 3))
            }
            base.drawLayer { layer in
                layer.draw(glyph.slice)
                layer.blendMode = .sourceIn
                layer.fill(Path(rect), with: .color(Theme.accent))
                guard fraction < 1 else { return }
                let solid = min(max((edge + 1) / rect.width, 0), 1)
                let fade = min(max((edge + 1 + feather) / rect.width, solid), 1)
                let leading = CGPoint(x: glyph.reversed ? rect.maxX : rect.minX, y: rect.midY)
                let trailing = CGPoint(x: glyph.reversed ? rect.minX : rect.maxX, y: rect.midY)
                layer.blendMode = .destinationIn
                layer.fill(Path(rect), with: .linearGradient(
                    Gradient(stops: [
                        .init(color: .white, location: 0),
                        .init(color: .white, location: solid),
                        .init(color: .clear, location: fade),
                        .init(color: .clear, location: 1)
                    ]), startPoint: leading, endPoint: trailing
                ))
            }
        }
    }
}

struct PlayingKaraokeText: View {
    @Environment(MusicPlayer.self) private var player
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    let line: LyricLine
    let delay: TimeInterval

    var body: some View {
        let fragments = line.words.flatMap { word in
            word.syllables.isEmpty ? [word] : word.syllables.map {
                LyricWord(text: $0.text, start: $0.start, end: $0.end)
            }
        }
        let shapedText = fragments.enumerated().reduce(Text(verbatim: "")) { text, entry in
            text + Text(verbatim: entry.element.text).customAttribute(KaraokeFragmentAttribute(index: entry.offset))
        }
        TimelineView(.animation(minimumInterval: 1.0 / 30.0,
                                paused: !player.isPlaying || scenePhase != .active || reduceMotion)) { _ in
            shapedText.textRenderer(KaraokeTextRenderer(fragments: fragments,
                                                        time: player.lyricsPlaybackTime - delay,
                                                        reduceMotion: reduceMotion))
        }
    }
}

struct KaraokeArtworkBackground: View {
    @Environment(MusicPlayer.self) private var player
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var tint = ArtworkTint.neutral
    @State private var drift = false
    let track: Track

    private var moving: Bool { scenePhase == .active && player.isPlaying && player.current.id == track.id && !reduceMotion }

    var body: some View {
        let artwork = player.artworkSource(for: track)
        GeometryReader { geometry in
            let radius = max(geometry.size.width, geometry.size.height)
            let hue = Color(red: tint.red, green: tint.green, blue: tint.blue)
            ZStack {
                Theme.background
                RadialGradient(colors: [hue.opacity(0.88), hue.opacity(0.21), .clear],
                               center: .top, startRadius: 0, endRadius: radius * 0.84)
                    .scaleEffect(1.25)
                    .offset(x: geometry.size.width * (drift ? 0.24 : -0.24), y: -radius * 0.14)
                RadialGradient(colors: [hue.opacity(0.48), .clear],
                               center: .bottom, startRadius: 0, endRadius: radius * 0.58)
                    .scaleEffect(1.18)
                    .blur(radius: 20)
                    .offset(x: geometry.size.width * (drift ? -0.28 : 0.28), y: radius * 0.12)
                LinearGradient(colors: [.black.opacity(0.08), Theme.background.opacity(0.79)],
                               startPoint: .top, endPoint: .bottom)
            }
        }
        .task(id: artwork) {
            let asset = if let artwork { await ArtworkLoader.shared.load(artwork) } else { nil as ArtworkAsset? }
            guard !Task.isCancelled else { return }
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.45)) { tint = asset?.tint ?? .neutral }
        }
        .onChange(of: moving, initial: true) { _, enabled in
            if enabled {
                withAnimation(.easeInOut(duration: 11).repeatForever(autoreverses: true)) { drift = true }
            } else {
                withTransaction(Transaction(animation: nil)) { drift = false }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
