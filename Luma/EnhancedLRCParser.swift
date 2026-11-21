// SPDX-License-Identifier: GPL-3.0-only
// Adapted from Erhu contributors, 31a0f3c542e62bdc00f8083fc702e9aa1364c0ab
// Erhu/Core/Lyrics/LyricsParser.swift and Erhu/Core/Common/Regex16.swift.
// STRSK changes, 2026-11-21: bounded offsets, explicit fragment ends, text
// order and repeated-line handling. See ThirdParty/Erhu-GPL-3.0.txt and
// ThirdParty/Erhu-Android-GPL-3.0.txt.
import Foundation

enum EnhancedLRCParser {
    private static let lineTime = try! NSRegularExpression(pattern: #"^\[(\d{1,3}):(\d{1,2})(?:[.:](\d{1,3}))?]"#)
    private static let wordTime = try! NSRegularExpression(pattern: #"<(\d{1,3}):(\d{1,2})(?:[.:](\d{1,3}))?>"#)
    private static let offsetTag = try! NSRegularExpression(pattern: #"^\[offset:\s*([+-]?\d+)\s*]"#, options: .caseInsensitive)
    private static let metadata = try! NSRegularExpression(pattern: #"^\[[a-zA-Z#]+:.*]$"#)

    static func parse(_ text: String) -> [LyricLine] {
        guard !text.isEmpty else { return [] }
        let rawLines = text.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n").components(separatedBy: "\n")
        let offset = rawLines.lazy.compactMap { raw -> Int64? in
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard let match = first(offsetTag, in: line),
                  let value = Int64(group(1, match, line)), (-86_400_000...86_400_000).contains(value) else { return nil }
            return value
        }.first ?? 0

        // Existing STRSK documents use a positive offset to delay the text.
        var lines: [LyricLine] = []
        for raw in rawLines {
            var rest = raw.trimmingCharacters(in: .whitespaces)
            var stamps: [Int64] = []
            while let match = first(lineTime, in: rest) {
                if let time = milliseconds(match, rest) { stamps.append(time) }
                rest = (rest as NSString).substring(from: NSMaxRange(match.range))
            }
            guard let firstStamp = stamps.first else { continue }
            let parsed = parseWords(rest)
            let content = parsed.words.isEmpty ? rest.trimmingCharacters(in: .whitespaces) : parsed.words.map(\.text).joined()
            for stamp in stamps {
                let shift = offset + stamp - firstStamp
                let words = parsed.words.map { word in
                    LyricWord(text: word.text,
                              start: word.start.map { max(0, $0 + Double(shift) / 1000) },
                              end: word.end.map { max(0, $0 + Double(shift) / 1000) })
                }
                let lineEnd = parsed.end.map { Double(max(0, $0 + shift)) / 1000 }
                lines.append(LyricLine(time: Double(max(stamp + offset, 0)) / 1000, text: content,
                                       words: words, end: lineEnd, instrumental: content.isEmpty))
            }
        }
        if !lines.isEmpty { return lines }
        return rawLines.filter { first(metadata, in: $0.trimmingCharacters(in: .whitespaces)) == nil }
            .map { LyricLine(time: nil, text: $0) }
    }

    private static func parseWords(_ content: String) -> (words: [LyricWord], end: Int64?) {
        let ns = content as NSString
        let stamps = wordTime.matches(in: content, range: NSRange(location: 0, length: ns.length))
        guard let initial = stamps.first else { return ([], nil) }
        let prefix = ns.substring(to: initial.range.location)
        var words = prefix.isEmpty ? [] : [LyricWord(text: prefix, start: nil, end: nil)]
        var terminal: Int64?
        for (index, match) in stamps.enumerated() {
            let next = index + 1 < stamps.count ? stamps[index + 1] : nil
            let start = NSMaxRange(match.range)
            let end = next?.range.location ?? ns.length
            let fragment = ns.substring(with: NSRange(location: start, length: end - start))
            let time = milliseconds(match, content)
            if fragment.trimmingCharacters(in: .whitespaces).isEmpty, next == nil {
                terminal = time
            } else if !fragment.isEmpty {
                let following = next.flatMap { milliseconds($0, content) }
                let validEnd = following.flatMap { following in time.flatMap { following > $0 ? following : nil } }
                words.append(LyricWord(text: fragment, start: time.map { Double($0) / 1000 },
                                       end: validEnd.map { Double($0) / 1000 }))
            }
        }
        return (words, terminal)
    }

    private static func milliseconds(_ match: NSTextCheckingResult, _ text: String) -> Int64? {
        guard let minutes = Int64(group(1, match, text)), let seconds = Int64(group(2, match, text)), seconds < 60 else {
            return nil
        }
        let fraction = group(3, match, text)
        let multiplier: Int64 = fraction.count == 1 ? 100 : fraction.count == 2 ? 10 : 1
        return (minutes * 60 + seconds) * 1000 + (Int64(fraction) ?? 0) * multiplier
    }

    private static func first(_ regex: NSRegularExpression, in text: String) -> NSTextCheckingResult? {
        regex.firstMatch(in: text, range: NSRange(location: 0, length: (text as NSString).length))
    }

    private static func group(_ index: Int, _ match: NSTextCheckingResult, _ text: String) -> String {
        let range = match.range(at: index)
        return range.location == NSNotFound ? "" : (text as NSString).substring(with: range)
    }
}
