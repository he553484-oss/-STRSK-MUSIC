import Testing
import Foundation
@testable import Luma

struct LyricsTimelineTests {
    @Test func plainTextKeepsUnicodeAndHasNoClock() {
        let document = LyricsDocument("صوت 🎧\n\n光のなか")
        #expect(document.lines.map(\.text) == ["صوت 🎧", "", "光のなか"])
        #expect(!document.isSynchronized)
        #expect(!document.timeline.hasWordTiming)
        #expect(document.activeLine(at: 90) == nil)
    }

    @Test func lineTimingRetainsOrderOnDuplicateMarkers() {
        let document = LyricsDocument("[00:09]Third\n[00:02]First\n[00:02]Second")
        #expect(document.lines.map(\.text) == ["First", "Second", "Third"])
        #expect(!document.timeline.hasWordTiming)
        #expect(document.timeline.frame(at: 2).activeIDs == [0, 1])
        #expect(document.activeLine(at: 2) == 1)
        #expect(document.activeLine(at: 1) == nil)
    }

    @Test func wordsAdvanceThroughExplicitIntervals() throws {
        let document = LyricsDocument("[00:01]<00:01.00>Glow <00:03.00>again<00:05.00>")
        let line = try #require(document.lines.first)
        #expect(line.text == "Glow again")
        #expect(line.end == 5)
        #expect(line.words.map(\.end) == [3, 5])
        #expect(line.words[0].progress(at: 1) == 0)
        #expect(line.words[0].progress(at: 2) == 0.5)
        #expect(line.words[0].progress(at: 3) == 1)
        #expect(line.words[1].progress(at: 2.9) == 0)
        #expect(line.words[1].progress(at: 4) == 0.5)
    }

    @Test func longRTLAndEmojiFragmentsKeepSourceText() throws {
        let text = String(repeating: "موسيقى", count: 220) + " 🎧👩🏽‍🚀"
        let line = try #require(LyricsDocument("[00:00]<00:00>" + text + "<00:04>").lines.first)
        #expect(line.text == text)
        #expect(line.words.count == 1)
        #expect(line.words[0].progress(at: 1) == 0.25)
    }

    @Test func outOfOrderAndRepeatedWordMarkersDoNotReorderText() throws {
        let document = LyricsDocument("[00:10][00:30]<00:10.50>One <00:10.50>two <00:10.25>three")
        #expect(document.lines.map(\.text) == ["One two three", "One two three"])
        let first = try #require(document.lines.first)
        #expect(first.words.map(\.start) == [10.5, 10.5, 10.25])
        #expect(first.words.map(\.end) == [nil, nil, nil])
        #expect(document.lines.last?.words.map(\.start) == [30.5, 30.5, 30.25])
    }

    @Test(arguments: [500, -500])
    func signedLRCOffsetsApplyToEveryMarker(offset: Int) throws {
        let document = LyricsDocument("[offset:\(offset)]\n[00:02]<00:02>Pulse<00:04>")
        let line = try #require(document.lines.first)
        let delta = Double(offset) / 1000
        #expect(line.time == 2 + delta)
        #expect(line.words.first?.start == 2 + delta)
        #expect(line.words.first?.end == 4 + delta)
    }

    @Test func extremeErhuOffsetCannotOverflow() throws {
        for limit in [String(Int64.min), String(Int64.max), String(repeating: "9", count: 200)] {
            let document = LyricsDocument("[offset:\(limit)]\n[00:01]<00:01>Pulse<00:02>")
            let line = try #require(document.lines.first)
            #expect(line.time == 1)
            #expect(line.words.first?.start == 1)
            #expect(line.words.first?.progress(at: 1.5) == 0.5)
        }
    }

    @Test func timedTTMLAgentsSyllablesAndTranslation() throws {
        let source = """
        <tt xmlns="http://www.w3.org/ns/ttml" xmlns:ttm="http://www.w3.org/ns/ttml#metadata">
          <body><div begin="2s">
            <p begin="1s" dur="4s" ttm:agent="#alto">
              <span begin="500ms" end="3s"><span begin="0s" dur="1s">Ra</span><span begin="1s" dur="1.5s">dio</span></span>
              <span ttm:role="x-translation">راديو</span>
            </p>
            <p begin="2s" end="3s" ttm:agent="#bass">Echo</p>
          </div></body>
        </tt>
        """
        let document = LyricsDocument(source)
        let line = try #require(document.lines.first)
        let word = try #require(line.words.first { $0.start != nil })
        #expect(document.valid)
        #expect(line.time == 3)
        #expect(line.end == 7)
        #expect(line.translation == "راديو")
        #expect(document.timeline.vocalistOrder == ["alto", "bass"])
        #expect(document.timeline.frame(at: 4.3).activeIDs == [0, 1])
        #expect(word.syllables.map(\.text) == ["Ra", "dio"])
        #expect(word.syllables.map(\.start) == [3.5, 4.5])
        #expect(word.syllables.map(\.end) == [4.5, 6])
    }

    @Test func instrumentalIntervalsComeFromMarkersOrDocumentedEnds() {
        let document = LyricsDocument("[00:01]<00:01>Start<00:03>\n[00:08]\n[00:12]Return")
        for time in [3.0, 7.5, 8.0, 11.9] {
            #expect(document.timeline.frame(at: time).instrumental)
        }
        #expect(!document.timeline.frame(at: 0.8).instrumental)
        #expect(!document.timeline.frame(at: 12).instrumental)
        #expect(document.timeline.frame(at: 11.95, lookAhead: 0.11).anchor == 2)
        #expect(document.timeline.frame(at: 11.95, lookAhead: 0.11).activeIDs.isEmpty)
    }

    @Test func localYRCAndDecodedKRCUseTheirOwnTimeBases() throws {
        let yrc = try #require(LyricsDocument("[1500,2000](1500,500,0)Signal (2000,1000,0)after").lines.first)
        #expect(yrc.words.map(\.start) == [1.5, 2])
        #expect(yrc.words.map(\.end) == [2, 3])
        let metadata = Data(#"{"content":[{"type":1,"lyricContent":[["Luz"]]}]}"#.utf8).base64EncodedString()
        let krc = try #require(LyricsDocument("[language:\(metadata)]\n[1500,2000]<100,600,0>Signal").lines.first)
        #expect(krc.words.map(\.start) == [1.6])
        #expect(krc.translation == "Luz")
    }

    @Test func rejectsCorruptXMLAndUnsupportedSequentialTiming() {
        #expect(!LyricsDocument("<tt><body><p begin=\"bad\">Broken</p></body></tt>").valid)
        #expect(!LyricsDocument("<tt><body>").valid)
        #expect(!LyricsDocument("<tt><body timeContainer=\"seq\"><p>A</p></body></tt>").valid)
        #expect(!LyricsDocument("<!DOCTYPE tt SYSTEM 'file:///tmp/private'><tt/>").valid)
        #expect(LyricsDocument("[00:95]bad").lines.first?.time == nil)
        #expect(LyricsDocument("[9999999999999999999999999,2]bad").lines.first?.time == nil)
    }

    @Test func repeatedSeeksOnALongDocument() {
        let document = LyricsTimeline(lines: (0..<12_000).map {
            LyricLine(time: Double($0), text: "Line \($0)")
        })
        for sample in 0..<1400 {
            let index = sample * 97 % 12_000
            #expect(document.frame(at: Double(index) + 0.25).activeIDs == [index])
        }
    }
}
