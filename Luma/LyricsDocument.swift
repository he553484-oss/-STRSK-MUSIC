import Foundation

struct LyricsDocument {
    let timeline: LyricsTimeline
    enum Format { case lrc, ttml, wordTimedText }

    let valid: Bool
    let format: Format

    var lines: [LyricLine] { timeline.lines }
    var isSynchronized: Bool { timeline.isSynchronized }

    init(_ text: String) {
        let source = text.trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: "\u{FEFF}")))
        if source.hasPrefix("<"), source.range(of: #"<(?:[\w-]+:)?tt[\s>]|<!DOCTYPE"#,
                                               options: [.regularExpression, .caseInsensitive]) != nil {
            format = .ttml
            let lines = TTMLLyricsParser.parse(source)
            valid = lines != nil
            timeline = LyricsTimeline(lines: lines ?? [])
        } else if let version = TextWordLyricsParser.parse(source) {
            format = .wordTimedText
            valid = true
            timeline = LyricsTimeline(lines: version)
        } else {
            format = .lrc
            valid = true
            timeline = LyricsTimeline(lines: EnhancedLRCParser.parse(source))
        }
    }

    func activeLine(at time: TimeInterval) -> Int? {
        PlaybackLyricsSynchronizer().activeLine(in: timeline, at: time)
    }
}
