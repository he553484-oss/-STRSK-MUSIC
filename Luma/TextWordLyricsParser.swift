// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Praveet Gupta
// Adapted from DriveVerse/Core/Lyrics/WordTimedLyricsParser.swift,
// 55acc772e5d04e02f6719939546cc29bc94804d2. Original format work informed by
// Lyricify Lyrics Helper (WXRIW, Apache-2.0). See ThirdParty.
// STRSK changes, 2026-11-21: bounded timing and source-specific display model.
import Foundation

enum TextWordLyricsParser {
    private static let header = try! NSRegularExpression(pattern: #"^\[(\d{1,10}),(\d{1,10})\](.*)$"#)
    private static let yrc = try! NSRegularExpression(pattern: #"\((\d{1,10}),(\d{1,10}),-?\d+\)([^\(]*)"#)
    private static let krc = try! NSRegularExpression(pattern: #"<(\d{1,10}),(\d{1,10}),-?\d+>([^<]*)"#)

    static func parse(_ raw: String) -> [LyricLine]? {
        let rows = raw.components(separatedBy: .newlines)
        let translations = translations(in: rows)
        var lines: [LyricLine] = []
        for rawLine in rows {
            let line = rawLine.trimmingCharacters(in: .whitespaces) as NSString
            guard let match = header.firstMatch(in: line as String, range: NSRange(location: 0, length: line.length)),
                  let start = seconds(line.substring(with: match.range(at: 1))),
                  let duration = seconds(line.substring(with: match.range(at: 2))) else { continue }
            let body = line.substring(with: match.range(at: 3)) as NSString
            let range = NSRange(location: 0, length: body.length)
            let krcMatches = krc.matches(in: body as String, range: range)
            let matches = krcMatches.isEmpty ? yrc.matches(in: body as String, range: range) : krcMatches
            let words = matches.compactMap { match -> LyricWord? in
                guard let offset = seconds(body.substring(with: match.range(at: 1))),
                      let span = seconds(body.substring(with: match.range(at: 2))) else { return nil }
                let text = body.substring(with: match.range(at: 3))
                guard !text.isEmpty else { return nil }
                let wordStart = krcMatches.isEmpty ? offset : start + offset
                return LyricWord(text: text, start: wordStart, end: span > 0 ? wordStart + span : nil)
            }
            let translation = !krcMatches.isEmpty && translations.indices.contains(lines.count) ? translations[lines.count] : nil
            let text = words.isEmpty ? body as String : words.map(\.text).joined()
            lines.append(LyricLine(time: start, text: text, words: words, end: duration > 0 ? start + duration : nil,
                                   translation: translation, instrumental: text.isEmpty))
        }
        return lines.isEmpty ? nil : lines
    }

    private static func seconds(_ value: String) -> Double? {
        guard let milliseconds = Double(value), (0...86_400_000).contains(milliseconds) else { return nil }
        return milliseconds / 1000
    }

    private struct Languages: Decodable {
        struct Entry: Decodable {
            let type: Int
            let lyricContent: [[String]]
        }
        let content: [Entry]
    }

    private static func translations(in rows: [String]) -> [String] {
        guard let row = rows.first(where: { $0.hasPrefix("[language:") && $0.hasSuffix("]") }),
              let data = Data(base64Encoded: String(row.dropFirst("[language:".count).dropLast())),
              let decoded = try? JSONDecoder().decode(Languages.self, from: data) else { return [] }
        return decoded.content.first(where: { $0.type == 1 })?.lyricContent.map { $0.joined() } ?? []
    }
}
