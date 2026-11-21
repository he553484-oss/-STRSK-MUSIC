import SwiftUI
import UniformTypeIdentifiers

struct LyricsView: View {
    @Environment(MusicPlayer.self) private var player
    @Environment(\.dismiss) private var dismiss
    @AppStorage("strsk.lyrics.delayMS") private var delayMS = 0
    @AppStorage("strsk.lyrics.returnDelay") private var returnDelay = 4

    private let initialTrack: Track
    private let followsCurrentTrack: Bool
    private var track: Track { followsCurrentTrack ? player.current : initialTrack }
    @State private var document: (key: LyricsLoadKey, timeline: LyricsTimeline)?
    @State private var modal: Panel?
    @State private var showImport = false
    @State private var importTrack: Track?

    init(track: Track, followsCurrentTrack: Bool = false) {
        initialTrack = track
        self.followsCurrentTrack = followsCurrentTrack
    }

    private struct LyricsLoadKey: Equatable {
        let trackID: String
        let text: String
    }

    private enum Panel: Identifiable {
        case editor(Track), lookup(Track), timing
        var id: String {
            switch self {
            case .editor: "editor"
            case .lookup: "lookup"
            case .timing: "timing"
            }
        }
    }

    var body: some View {
        let track = self.track
        let key = LyricsLoadKey(trackID: track.id, text: player.lyrics[track.id] ?? "")
        NavigationStack {
            VStack(spacing: 0) {
                header(track)
                if key.text.isEmpty {
                    emptyState(track)
                } else if let document, document.key == key {
                    KaraokeLyricsScroll(timeline: document.timeline, track: track,
                                        delayMS: delayMS, returnDelay: returnDelay)
                        .id(track.id + "\n" + key.text)
                } else {
                    Spacer()
                    ProgressView().accessibilityLabel("Loading lyrics")
                    Spacer()
                }
            }
            .task(id: key) {
                let provider = StoredLyricsProvider(texts: [key.trackID: key.text])
                let result = await provider.timeline(for: key.trackID)
                guard !Task.isCancelled else { return }
                document = result.map { (key, $0) }
            }
            .background { KaraokeArtworkBackground(track: track) }
            .navigationTitle("Lyrics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Find lyrics online", systemImage: "arrow.down.circle") { modal = .lookup(track) }
                            .accessibilityIdentifier("lyrics.findOnline")
                        Button("Edit lyrics", systemImage: "pencil") { modal = .editor(track) }
                        Button("Import lyrics file", systemImage: "doc.badge.plus") { beginImport(track) }
                        Button("Timing & scroll", systemImage: "slider.horizontal.3") { modal = .timing }
                        if !key.text.isEmpty {
                            ShareLink(item: key.text) { Label("Share lyrics", systemImage: "square.and.arrow.up") }
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                    .accessibilityLabel("Lyrics options")
                }
            }
            .sheet(item: $modal) { panel in
                switch panel {
                case .editor(let track): LyricsEditor(track: track)
                case .lookup(let track): LyricsLookupView(track: track)
                case .timing: timingSettings
                }
            }
            .fileImporter(isPresented: $showImport, allowedContentTypes: Self.lyricTypes) { result in
                guard let pendingTrack = importTrack else { return }
                importTrack = nil
                switch result {
                case .success(let url):
                    Task { await player.importLyrics(url, for: pendingTrack) }
                case .failure(let error):
                    player.error = error.localizedDescription
                }
            }
            .modifier(PlayerFeedback())
        }
    }

    private static var lyricTypes: [UTType] {
        [.plainText, .text, .xml] + ["lrc", "ttml", "yrc", "krc"].compactMap {
            UTType(filenameExtension: $0, conformingTo: .text)
        }
    }

    private func beginImport(_ track: Track) {
        importTrack = track
        showImport = true
    }

    private func header(_ track: Track) -> some View {
        let playing = player.current.id == track.id && player.isPlaying
        return HStack(spacing: 12) {
            CoverFrame(track: track, cornerRadius: 10).frame(width: 46, height: 46)
            VStack(alignment: .leading, spacing: 4) {
                Text(track.title).font(.headline).lineLimit(1)
                Text(track.artist).font(.caption).foregroundStyle(Theme.secondary).lineLimit(1)
            }
            Spacer()
            Button {
                if player.current.id == track.id { player.toggle() } else { player.select(track) }
            } label: {
                Image(systemName: playing ? "pause.fill" : "play.fill").frame(width: 44, height: 44)
            }
            .buttonStyle(.glass)
            .disabled(track.id.isEmpty)
            .accessibilityLabel(playing ? "Pause lyrics track" : "Play lyrics track")
            .accessibilityIdentifier("lyrics.playPause")
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
    }

    private func emptyState(_ track: Track) -> some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "music.note").font(.largeTitle).foregroundStyle(Theme.accent)
                .accessibilityHidden(true)
            Text("No lyrics").font(.largeTitle.weight(.semibold))
            Text("Import timed lyrics, paste text, or look for a match online.")
                .font(.subheadline)
                .foregroundStyle(Theme.secondary)
                .multilineTextAlignment(.center)
            Button("Add lyrics") { modal = .editor(track) }.buttonStyle(.glass)
                .accessibilityIdentifier("lyrics.add")
            Button("Find lyrics online", systemImage: "arrow.down.circle") { modal = .lookup(track) }
                .buttonStyle(.glass).accessibilityIdentifier("lyrics.findOnline")
            Button("Import lyrics file") { beginImport(track) }.font(.subheadline)
            Spacer()
        }
        .disabled(track.id.isEmpty)
        .padding(32)
    }

    private var timingSettings: some View {
        NavigationStack {
            Form {
                Stepper("Lyrics delay: \(delayMS) ms", value: $delayMS, in: -5000...5000, step: 50)
                Button("Reset delay") { delayMS = 0 }
                Picker("Return to lyrics after scrolling", selection: $returnDelay) {
                    Text("2 seconds").tag(2)
                    Text("4 seconds").tag(4)
                    Text("8 seconds").tag(8)
                }
            }
            .navigationTitle("Timing & scroll")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { modal = nil } }
            }
        }
        .presentationDetents([.medium])
    }
}

private struct KaraokeLyricsScroll: View {
    @Environment(MusicPlayer.self) private var player
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var frame = LyricsFrame.empty
    @State private var following = true
    @State private var userScrolling = false
    @State private var resume: UUID?
    @ScaledMetric(relativeTo: .title2) private var lineSize = 30.0

    let timeline: LyricsTimeline
    let track: Track
    let delayMS: Int
    let returnDelay: Int
    private var delay: TimeInterval { Double(delayMS) / 1000 }
    private var isCurrent: Bool { player.current.id == track.id }

    var body: some View {
        ScrollViewReader { proxy in
            VStack(spacing: 0) {
                if timeline.isSynchronized {
                    HStack {
                        if frame.instrumental {
                            Label("Instrumental", systemImage: "ellipsis")
                                .accessibilityIdentifier("lyrics.instrumental")
                        } else {
                            Text(timeline.hasWordTiming ? "Word-synced lyrics" : "Time-synced lyrics")
                                .accessibilityIdentifier("lyrics.timingMode")
                        }
                        Spacer()
                        Button(following && !userScrolling ? "Following" : "Follow along") {
                            if following && !userScrolling {
                                following = false
                            } else {
                                following = true
                                userScrolling = false
                                resume = nil
                                center(frame.anchor, using: proxy)
                            }
                        }
                        .accessibilityIdentifier("lyrics.follow")
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.secondary)
                    .padding(.horizontal, 24)
                    .frame(minHeight: 35)
                }

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 24) {
                        ForEach(timeline.lines) { line in
                            if let time = line.time {
                                Button {
                                    if !isCurrent { player.select(track) }
                                    player.seek(to: max(0, time + delay))
                                    resume = nil
                                    userScrolling = false
                                    if following { center(line.id, using: proxy) }
                                } label: {
                                    lyricRow(line)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("\(line.instrumental ? "Instrumental" : line.text), seek to \(formattedTime(time))")
                                .accessibilityValue(frame.activeIDs.contains(line.id) ? "Singing" : "")
                                .accessibilityHint(line.translation ?? "")
                                .id(line.id)
                            } else {
                                lyricRow(line).id(line.id)
                            }
                        }
                    }
                    .padding(.horizontal, 26)
                    .padding(.top, 25)
                    .padding(.bottom, 150)
                }
                .onScrollPhaseChange { _, phase in
                    if phase == .interacting {
                        userScrolling = true
                        resume = nil
                    } else if phase == .idle, userScrolling, following {
                        resume = UUID()
                    }
                }
                .task(id: resume) {
                    guard resume != nil else { return }
                    do { try await Task.sleep(for: .seconds(returnDelay)) } catch { return }
                    userScrolling = false
                    center(frame.anchor, using: proxy)
                }
            }
            .background(alignment: .topLeading) {
                if timeline.isSynchronized {
                    TimelineView(.animation(minimumInterval: 1.0 / 30.0,
                                            paused: !isCurrent || !player.isPlaying || scenePhase != .active || reduceMotion)) { _ in
                        let mediaTime = player.lyricsPlaybackTime - delay
                        let preview = player.isPlaying && !reduceMotion ? 0.11 : 0
                        let next = isCurrent ? timeline.frame(at: mediaTime, lookAhead: preview) : .empty
                        Color.clear.frame(width: 1, height: 1)
                            .onChange(of: next, initial: true) { _, value in
                                frame = value
                                if following && !userScrolling { center(value.anchor, using: proxy) }
                            }
                    }
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                }
            }
        }
    }

    @ViewBuilder
    private func lyricRow(_ line: LyricLine) -> some View {
        let active = frame.activeIDs.contains(line.id)
        let secondary = timeline.vocalistOrder.count > 1 && line.vocalists.first == timeline.vocalistOrder.dropFirst().first
        VStack(alignment: secondary ? .trailing : .leading, spacing: 6) {
            if line.instrumental {
                Image(systemName: "ellipsis").font(.title2)
                    .foregroundStyle(frame.anchor == line.id ? Theme.accent : Theme.secondary)
            } else {
                Group {
                    if active && line.words.contains(where: { $0.start != nil }) {
                        PlayingKaraokeText(line: line, delay: delay)
                    } else {
                        Text(verbatim: line.text)
                            .foregroundStyle(!timeline.isSynchronized || active ? .white : .white.opacity(0.4))
                    }
                }
                .font(.system(size: lineSize, weight: .semibold))
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(secondary ? .trailing : .leading)
                if let translation = line.translation {
                    Text(verbatim: translation)
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondary)
                }
            }
        }
        .padding(.vertical, 3)
        .frame(maxWidth: .infinity, alignment: secondary ? .trailing : .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private func center(_ id: Int?, using proxy: ScrollViewProxy) {
        guard let id else { return }
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.34)) {
            proxy.scrollTo(id, anchor: UnitPoint(x: 0.5, y: 0.44))
        }
    }
}

struct LyricsEditor: View {
    @Environment(MusicPlayer.self) private var player
    @Environment(\.dismiss) private var dismiss
    let track: Track
    @State private var text = ""
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text(track.title).font(.title3.weight(.semibold))
                Text("Paste plain lyrics, LRC, or TTML. For LRC timestamps, use [00:12.50] to follow the music. Saving an empty field removes your lyrics.").font(.footnote).foregroundStyle(Theme.secondary)
                TextEditor(text: $text).font(.body).scrollContentBackground(.hidden).padding(12).background(.white.opacity(0.04), in: .rect(cornerRadius: 16)).accessibilityIdentifier("lyrics.editor")
            }.padding(24).background { AppBackground() }
                .navigationTitle("Edit lyrics").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button("Save") { player.setLyrics(text, for: track); dismiss() }.accessibilityIdentifier("lyrics.save") }
                }
                .onAppear { text = player.lyrics[track.id] ?? "" }
        }
    }
}
