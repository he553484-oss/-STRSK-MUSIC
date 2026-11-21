import Foundation

struct LyricSyllable: Equatable, Sendable {
    let text: String
    let start: TimeInterval
    let end: TimeInterval?
}

struct LyricWord: Equatable, Sendable {
    let text: String
    let start: TimeInterval?
    let end: TimeInterval?
    var syllables: [LyricSyllable] = []

    func progress(at time: TimeInterval) -> Double {
        guard let start, time.isFinite, time >= start else { return 0 }
        guard let end, end > start else { return 1 }
        return min(1, (time - start) / (end - start))
    }
}

struct LyricLine: Identifiable, Equatable, Sendable {
    var id = 0
    var time: TimeInterval?
    var text: String
    var words: [LyricWord] = []
    var end: TimeInterval?
    var vocalists: [String] = []
    var translation: String?
    var instrumental = false
}

struct LyricsTimeline: Equatable, Sendable {
    let lines: [LyricLine]
    let hasWordTiming: Bool
    let vocalistOrder: [String]
    private let timedCount: Int
    private let ends: [TimeInterval]
    private let latestEnd: [TimeInterval]

    init(lines: [LyricLine]) {
        self.lines = lines.sorted { ($0.time ?? .infinity) < ($1.time ?? .infinity) }
            .enumerated().map { index, line in
                var entry = line
                entry.id = index
                return entry
            }
        timedCount = self.lines.prefix(while: { $0.time != nil }).count
        hasWordTiming = self.lines.contains { $0.words.contains { $0.start != nil } }
        var seen: Set<String> = []
        vocalistOrder = self.lines.flatMap(\.vocalists).filter { seen.insert($0).inserted }
        var limits = Array(repeating: TimeInterval.infinity, count: timedCount)
        var next = TimeInterval.infinity
        for index in limits.indices.reversed() {
            let line = self.lines[index]
            if index + 1 < timedCount, let following = self.lines[index + 1].time, following != line.time {
                next = following
            }
            limits[index] = line.end ?? next
        }
        ends = limits
        var maximum = -TimeInterval.infinity
        latestEnd = limits.map { maximum = max(maximum, $0); return maximum }
    }

    var isSynchronized: Bool { timedCount > 0 }

    func frame(at mediaTime: TimeInterval, lookAhead: TimeInterval = 0) -> LyricsFrame {
        guard isSynchronized, mediaTime.isFinite else { return .empty }
        var lower = 0
        var upper = timedCount
        while lower < upper {
            let mid = lower + (upper - lower) / 2
            if (lines[mid].time ?? .infinity) <= mediaTime { lower = mid + 1 } else { upper = mid }
        }
        var index = lower - 1
        var ids: [Int] = []
        var marker: Int?
        while index >= 0, latestEnd[index] > mediaTime {
            if ends[index] > mediaTime {
                if lines[index].instrumental { marker = marker ?? index } else { ids.append(index) }
            }
            index -= 1
        }
        let upcoming = lower < timedCount ? lines[lower] : nil
        let lastStarted = lower > 0 ? lower - 1 : nil
        let instrumental = ids.isEmpty && (marker != nil || (lastStarted != nil && upcoming != nil))
        var anchor = ids.last ?? marker ?? lastStarted
        if let upcoming, let start = upcoming.time, start - mediaTime <= lookAhead, lastStarted != nil {
            anchor = upcoming.id
        }
        return LyricsFrame(activeIDs: ids.reversed(), anchor: anchor, instrumental: instrumental)
    }
}

struct LyricsFrame: Equatable, Sendable {
    let activeIDs: [Int]
    let anchor: Int?
    let instrumental: Bool

    static let empty = LyricsFrame(activeIDs: [], anchor: nil, instrumental: false)
}

protocol LyricsProvider {
    func timeline(for trackID: String) async throws -> LyricsTimeline?
}

struct StoredLyricsProvider: LyricsProvider {
    let texts: [String: String]

    func timeline(for trackID: String) async -> LyricsTimeline? {
        guard let text = texts[trackID], !text.isEmpty else { return nil }
        return LyricsDocument(text).timeline
    }
}

protocol LyricsSynchronizer {
    func activeLine(in timeline: LyricsTimeline, at mediaTime: TimeInterval) -> Int?
    func frame(in timeline: LyricsTimeline, at mediaTime: TimeInterval, lookAhead: TimeInterval) -> LyricsFrame
}

struct PlaybackLyricsSynchronizer: LyricsSynchronizer {
    func activeLine(in timeline: LyricsTimeline, at mediaTime: TimeInterval) -> Int? {
        frame(in: timeline, at: mediaTime, lookAhead: 0).activeIDs.last
    }

    func frame(in timeline: LyricsTimeline, at mediaTime: TimeInterval, lookAhead: TimeInterval = 0) -> LyricsFrame {
        timeline.frame(at: mediaTime, lookAhead: lookAhead)
    }
}
