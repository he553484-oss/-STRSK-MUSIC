import Foundation

struct LyricsDocument {
    let timeline: LyricsTimeline
    let valid: Bool

    var lines: [LyricLine] { timeline.lines }
    var isSynchronized: Bool { timeline.isSynchronized }

    init(_ text: String) {
        let source = text.trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: "\u{FEFF}")))
        if source.hasPrefix("<"), source.range(of: #"<(?:[\w-]+:)?tt[\s>]|<!DOCTYPE"#,
                                               options: [.regularExpression, .caseInsensitive]) != nil {
            let lines = TTMLLyricsParser.parse(source)
            valid = lines != nil
            timeline = LyricsTimeline(lines: lines ?? [])
        } else if let version = TextWordLyricsParser.parse(source) {
            valid = true
            timeline = LyricsTimeline(lines: version)
        } else {
            valid = true
            timeline = LyricsTimeline(lines: EnhancedLRCParser.parse(source))
        }
    }

    func activeLine(at time: TimeInterval) -> Int? {
        PlaybackLyricsSynchronizer().activeLine(in: timeline, at: time)
    }
}
