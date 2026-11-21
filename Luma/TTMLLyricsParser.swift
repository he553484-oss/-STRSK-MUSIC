import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif

/// Timed TTML paragraphs, explicit agents, translated spans and nested timed
/// spans in parallel containers. Relative offsets are resolved against parents.
enum TTMLLyricsParser {
    static func parse(_ source: String) -> [LyricLine]? {
        guard source.utf8.count <= 2_000_000,
              source.range(of: "<!DOCTYPE", options: .caseInsensitive) == nil else { return nil }
        let parser = XMLParser(data: Data(source.utf8))
        let delegate = Delegate()
        parser.delegate = delegate
        parser.externalEntityResolvingPolicy = .never
        guard parser.parse(), delegate.supported, delegate.rootFound, !delegate.lines.isEmpty else { return nil }
        return delegate.lines
    }

    private struct Span: Equatable {
        let id: Int
        let start: TimeInterval
        let end: TimeInterval?
    }

    private struct Scope {
        let name: String
        let start: TimeInterval
        let end: TimeInterval?
        let timed: Bool
        let agent: [String]
        let translation: Bool
        let spans: [Span]
    }

    private struct Fragment {
        var text: String
        let spans: [Span]
    }

    private final class Delegate: NSObject, XMLParserDelegate {
        private var stack: [Scope] = []
        private var fragments: [Fragment] = []
        private var translation = ""
        private var nextSpan = 0
        private var absoluteSpans = false
        private var frameRate = 30.0
        private var tickRate = 1.0
        private(set) var lines: [LyricLine] = []
        private(set) var supported = true
        private(set) var rootFound = false

        func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                    qualifiedName: String?, attributes: [String: String]) {
            let name = elementName.split(separator: ":").last.map(String.init) ?? elementName
            guard stack.count < 96, attributes["timeContainer"] != "seq" else {
                supported = false
                parser.abortParsing()
                return
            }
            if stack.isEmpty {
                rootFound = name == "tt"
                absoluteSpans = attributes["itunes:timing"] != nil
                frameRate = positive(attributes["ttp:frameRate"]) ?? 30
                if let parts = attributes["ttp:frameRateMultiplier"]?.split(separator: " "), parts.count == 2,
                   let numerator = positive(String(parts[0])), let denominator = positive(String(parts[1])) {
                    frameRate *= numerator / denominator
                }
                tickRate = positive(attributes["ttp:tickRate"]) ?? 1
            }
            let parent = stack.last
            let begin = time(attributes["begin"])
            let suppliedEnd = time(attributes["end"])
            let duration = time(attributes["dur"])
            guard (attributes["begin"] == nil || begin != nil),
                  (attributes["end"] == nil || suppliedEnd != nil),
                  (attributes["dur"] == nil || duration != nil) else {
                supported = false
                parser.abortParsing()
                return
            }

            let parentStart = parent?.start ?? 0
            let start = begin.map { resolved($0, against: parentStart) } ?? parentStart
            let explicitEnd = suppliedEnd.map { resolved($0, against: parentStart) }
            let timedEnd = [explicitEnd, duration.map { start + $0.seconds }, parent?.end].compactMap { $0 }.min()
            let role = (attributes["ttm:role"] ?? attributes["role"] ?? "").lowercased()
            let isTranslation = parent?.translation == true || role.split(separator: " ").contains {
                $0 == "translation" || $0 == "x-translation"
            }
            let agents = (attributes["ttm:agent"] ?? attributes["agent"])?
                .split(whereSeparator: \.isWhitespace).map { String($0.trimmingCharacters(in: CharacterSet(charactersIn: "#"))) }
                ?? parent?.agent ?? []
            var spans = parent?.spans ?? []
            if name == "span", !isTranslation, begin != nil {
                spans.append(Span(id: nextSpan, start: start, end: timedEnd.flatMap { $0 > start ? $0 : nil }))
                nextSpan += 1
            }
            let timed = begin != nil || parent?.timed == true
            stack.append(Scope(name: name, start: start, end: timedEnd, timed: timed,
                               agent: agents, translation: isTranslation, spans: spans))
            if name == "p" { fragments.removeAll(keepingCapacity: true); translation = "" }
            if name == "br" { append("\n") }
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) { append(string) }

        func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName: String?) {
            guard let scope = stack.popLast(), scope.name == "p" else { return }
            let phrase = fragments.map(\.text).joined()
            let text = phrase.trimmingCharacters(in: .whitespacesAndNewlines)
            let translated = translation.trimmingCharacters(in: .whitespacesAndNewlines)
            let end = scope.end.flatMap { $0 > scope.start ? $0 : nil }
            let instrument = text.isEmpty && scope.timed
            guard !text.isEmpty || instrument else { return }
            lines.append(LyricLine(time: scope.timed ? scope.start : nil, text: text,
                                   words: makeWords(), end: end, vocalists: scope.agent,
                                   translation: translated.isEmpty ? nil : translated,
                                   instrumental: instrument))
        }

        private func append(_ string: String) {
            guard let top = stack.last, stack.contains(where: { $0.name == "p" }) else { return }
            if top.translation {
                translation += string
            } else if let previous = fragments.indices.last, fragments[previous].spans == top.spans {
                fragments[previous].text += string
            } else {
                fragments.append(Fragment(text: string, spans: top.spans))
            }
        }

        private func makeWords() -> [LyricWord] {
            guard fragments.contains(where: { !$0.spans.isEmpty }) else { return [] }
            var words: [LyricWord] = []
            var index = 0
            while index < fragments.count {
                let first = fragments[index]
                guard let outer = first.spans.first else {
                    words.append(LyricWord(text: first.text, start: nil, end: nil))
                    index += 1
                    continue
                }
                var text = ""
                var syllables: [LyricSyllable] = []
                while index < fragments.count, fragments[index].spans.first?.id == outer.id {
                    let fragment = fragments[index]
                    text += fragment.text
                    if let inner = fragment.spans.last, inner != outer {
                        syllables.append(LyricSyllable(text: fragment.text, start: inner.start, end: inner.end))
                    }
                    index += 1
                }
                // Only render syllables separately if they cover the entire word.
                if syllables.map(\.text).joined() != text { syllables = [] }
                words.append(LyricWord(text: text, start: outer.start, end: outer.end, syllables: syllables))
            }
            return words
        }

        private func resolved(_ expression: (seconds: Double, clock: Bool), against base: Double) -> Double {
            absoluteSpans && expression.clock ? expression.seconds : base + expression.seconds
        }

        private func positive(_ value: String?) -> Double? {
            guard let value, let number = Double(value), number.isFinite, number > 0 else { return nil }
            return number
        }

        private func time(_ value: String?) -> (seconds: Double, clock: Bool)? {
            guard let value else { return nil }
            let source = value.trimmingCharacters(in: .whitespaces)
            let parts = source.split(separator: ":", omittingEmptySubsequences: false)
            let result: Double
            if parts.count >= 2 {
                let values = parts.compactMap { Double($0) }
                guard values.count == parts.count, (2...4).contains(values.count),
                      values.allSatisfy({ $0.isFinite && $0 >= 0 }) else { return nil }
                if values.count == 2 {
                    result = values[0] * 60 + values[1]
                } else {
                    result = values[0] * 3600 + values[1] * 60 + values[2]
                        + (values.count == 4 ? values[3] / frameRate : 0)
                }
            } else if source.hasSuffix("ms"), let number = Double(source.dropLast(2)) {
                result = number / 1000
            } else {
                guard let unit = source.last, let number = Double(source.dropLast()) else { return nil }
                switch unit {
                case "h": result = number * 3600
                case "m": result = number * 60
                case "s": result = number
                case "f": result = number / frameRate
                case "t": result = number / tickRate
                default: return nil
                }
            }
            return (0...86_400).contains(result) ? (result, parts.count >= 2) : nil
        }
    }
}
