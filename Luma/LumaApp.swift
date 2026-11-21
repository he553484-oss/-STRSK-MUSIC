import SwiftUI
#if DEBUG
import AVFoundation
import UIKit
#endif

@main
struct STRSKMusicApp: App {
    @State private var player = Self.makePlayer()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modifier(AlbumTheme())
                .environment(player)
                .environment(\.lyricsClient, Self.lyricsClient)
                .preferredColorScheme(.dark)
                .tint(Theme.accent)
                #if DEBUG
                .task {
                    let arguments = ProcessInfo.processInfo.arguments
                    if arguments.contains("--ui-testing"), arguments.contains("--import-strsk-karaoke"),
                       player.tracks.isEmpty, !player.importing {
                        await Self.importKaraokeFiles(into: player)
                    }
                }
                #endif
                .onChange(of: scenePhase) { _, phase in
                    if phase != .active { player.saveForBackground() }
                }
        }
    }

    private static func makePlayer() -> MusicPlayer {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-testing") {
            let suite = "studio.luma.ui-tests"
            let defaults = UserDefaults(suiteName: suite)!
            if ProcessInfo.processInfo.arguments.contains("--reset-ui-state") {
                defaults.removePersistentDomain(forName: suite)
                // View preferences use @AppStorage in the standard store.
                UserDefaults.standard.removeObject(forKey: "player.visualizer")
            }
            let documents = MusicPlayer.documents.appendingPathComponent("UITesting", isDirectory: true)
            if ProcessInfo.processInfo.arguments.contains("--reset-ui-state") { try? FileManager.default.removeItem(at: documents) }
            if ProcessInfo.processInfo.arguments.contains("--seed-test-library"), defaults.data(forKey: "luma.library.v2") == nil { seedTestLibrary(defaults: defaults, documents: documents) }
            if ProcessInfo.processInfo.arguments.contains("--color-artwork-fixture") { seedArtworkFixture(defaults: defaults, documents: documents) }
            if ProcessInfo.processInfo.arguments.contains("--readme-screenshots") { seedScreenshotLibrary(defaults: defaults, documents: documents) }
            return MusicPlayer(defaults: defaults, documentsURL: documents)
        }
        #endif
        return MusicPlayer()
    }

    private static let lyricsClient: any LyricsSearching = {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--ui-testing") && arguments.contains("--mock-lyrics-api") { return FixtureLyricsClient() }
        #endif
        return LRCLIBClient()
    }()

    #if DEBUG
    private static func writeTestAudio(to url: URL) throws {
        let format = AVAudioFormat(standardFormatWithSampleRate: 22_050, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 22_050 * 48)!
        buffer.frameLength = buffer.frameCapacity
        buffer.floatChannelData![0].initialize(repeating: 0, count: Int(buffer.frameLength))
        try AVAudioFile(forWriting: url, settings: format.settings).write(from: buffer)
    }

    /// Writes an original audible motif and matching lyric file. The normal
    /// import APIs index, copy, associate and persist both files.
    @MainActor
    private static func importKaraokeFiles(into player: MusicPlayer) async {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let audio = directory.appendingPathComponent("Signal Archive.wav")
            let rate = 16_000.0
            let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1)!
            let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(rate * 54))!
            buffer.frameLength = buffer.frameCapacity
            let samples = buffer.floatChannelData![0]
            let notes = [220.0, 261.63, 293.66, 196.0, 329.63, 261.63]
            for frame in 0..<Int(buffer.frameLength) {
                let time = Double(frame) / rate
                let beat = time.truncatingRemainder(dividingBy: 0.65)
                let frequency = notes[Int(time / 0.65) % notes.count]
                let envelope = min(1, beat * 40) * exp(-beat * 3.8)
                samples[frame] = Float(0.15 * envelope * (sin(2 * .pi * frequency * beat) + 0.31 * sin(4 * .pi * frequency * beat)))
            }
            try AVAudioFile(forWriting: audio, settings: format.settings).write(from: buffer)
            let tagged = directory.appendingPathComponent("Signal Archive.m4a")
            let cover = UIGraphicsImageRenderer(size: CGSize(width: 320, height: 320)).image { context in
                UIColor(red: 0.02, green: 0.12, blue: 0.16, alpha: 1).setFill()
                context.fill(CGRect(x: 0, y: 0, width: 320, height: 320))
                for line in 0..<11 {
                    let y = CGFloat(28 + line * 23)
                    UIColor(red: 0.06, green: 0.72 - CGFloat(line) * 0.043, blue: 0.68, alpha: 1).setFill()
                    context.fill(CGRect(x: 23 + CGFloat(line * 7), y: y, width: 262 - CGFloat(line * 12), height: 13))
                }
            }
            let artwork = AVMutableMetadataItem()
            artwork.identifier = .commonIdentifierArtwork
            artwork.dataType = "com.apple.metadata.datatype.JPEG"
            artwork.value = cover.jpegData(compressionQuality: 0.84) as NSData?
            var importedAudio = audio
            if let exporter = AVAssetExportSession(asset: AVURLAsset(url: audio), presetName: AVAssetExportPresetAppleM4A) {
                exporter.metadata = [artwork]
                do {
                    try await exporter.export(to: tagged, as: .m4a)
                    importedAudio = tagged
                } catch {
                    // WAV is still a real file and exercises the same import path.
                }
            }
            let lyrics = directory.appendingPathComponent("Signal Archive.lrc")
            let text = """
            [ti:Signal Archive]
            [00:00.00]<00:00.00>Signals <00:15.00>through <00:19.00>the wire<00:23.00>
            [00:24.00]<00:24.00>After the <00:31.00>quiet<00:37.00>
            [00:38.00]
            [00:48.00]<00:48.00>نور <00:51.00>🎧<00:53.00>
            """
            try text.write(to: lyrics, atomically: true, encoding: .utf8)
            await player.importFiles([importedAudio])
            guard let track = player.tracks.first else { return }
            await player.importLyrics(lyrics, for: track)
        } catch {
            player.error = "Could not prepare karaoke fixtures: \(error.localizedDescription)"
        }
    }

    /// Silent audio fixtures exist only after an explicit UI-test launch flag.
    private static func seedTestLibrary(defaults: UserDefaults, documents: URL) {
        do {
            try FileManager.default.createDirectory(at: documents, withIntermediateDirectories: true)
            let names = ["Golden Hour", "Weightless", "Afterglow"]
            let ids = ["golden", "blue", "rose"]
            let albums = ["Somewhere, nowhere", "A softer world", "The quiet between"]
            var tracks: [Track] = []
            for index in 0..<3 {
                let filename = "test-" + ids[index] + ".wav"
                try writeTestAudio(to: documents.appendingPathComponent(filename))
                tracks.append(Track(id: ids[index], title: names[index], artist: "Luma Sessions", album: albums[index], style: index,
                                    filename: filename, isImported: true, length: 48, genre: index == 1 ? "Jazz" : "Rock", year: index == 1 ? "2023" : "2024", trackNumber: index + 1, discNumber: 1, sampleRate: 22_050, bitDepth: 32, channels: 1))
            }
            defaults.set(try JSONEncoder().encode(LibraryState(importedTracks: tracks, currentID: tracks[0].id,
                         contextIDs: tracks.map(\.id), queue: tracks.dropFirst().map { QueueEntry(trackID: $0.id) })), forKey: "luma.library.v2")
        } catch { assertionFailure("Could not prepare test library: \(error)") }
    }

    /// Two locally generated color covers, only in the isolated UI-test library.
    private static func seedArtworkFixture(defaults: UserDefaults, documents: URL) {
        do {
            try FileManager.default.createDirectory(at: documents, withIntermediateDirectories: true)
            var tracks: [Track] = []
            for (index, name) in ["Amber", "Cobalt"].enumerated() {
                let audioName = "artwork-test-\(index).wav"
                let artworkName = "artwork-test-\(index).png"
                let audioURL = documents.appendingPathComponent(audioName)
                if !FileManager.default.fileExists(atPath: audioURL.path) { try writeTestAudio(to: audioURL) }
                let color = index == 0 ? Color(red: 1, green: 0.45, blue: 0.16) : Color(red: 0.18, green: 0.55, blue: 1)
                let renderer = ImageRenderer(content: AlbumArtwork(style: index, showType: false).colorMultiply(color).frame(width: 600, height: 600))
                try renderer.uiImage?.pngData()?.write(to: documents.appendingPathComponent(artworkName))
                tracks.append(Track(id: "artwork-test-\(index)", title: name, artist: "Artwork test", album: "Color study", style: index,
                                    filename: audioName, isImported: true, length: 48, artworkFilename: artworkName))
            }
            let state = LibraryState(importedTracks: tracks, currentID: tracks[0].id, contextIDs: tracks.map(\.id), queue: [QueueEntry(trackID: tracks[1].id)])
            defaults.set(try JSONEncoder().encode(state), forKey: "luma.library.v2")
        } catch { assertionFailure("Could not prepare artwork test fixture: \(error)") }
    }

    /// Fictional content for documentation captures. Never compiled into Release builds.
    private static func seedScreenshotLibrary(defaults: UserDefaults, documents: URL) {
        do {
            try FileManager.default.createDirectory(at: documents, withIntermediateDirectories: true)
            let titles = ["Silver Coast", "Blue Hour", "Late Signal", "Passing Lights", "Soft Focus", "Paper Sky", "Still Water", "First Light"]
            let artists = ["Mira Vale", "Mira Vale", "Northline", "Northline", "Iris Lane", "Iris Lane", "Mira Vale", "Northline"]
            let albums = ["Tidal Light", "Tidal Light", "Nocturne", "Nocturne", "Soft Focus", "Soft Focus", "Tidal Light", "Nocturne"]
            let colors: [Color] = [.init(red: 0.94, green: 0.51, blue: 0.25), .init(red: 0.25, green: 0.65, blue: 0.9), .init(red: 0.67, green: 0.42, blue: 0.85)]
            var tracks: [Track] = []
            for index in titles.indices {
                let id = "readme-\(index)"
                let filename = id + ".wav", cover = id + ".png"
                try writeTestAudio(to: documents.appendingPathComponent(filename))
                let group = artists[index] == "Mira Vale" ? 0 : (artists[index] == "Northline" ? 1 : 2)
                let renderer = ImageRenderer(content: AlbumArtwork(style: group, showType: false).colorMultiply(colors[group]).frame(width: 600, height: 600))
                guard let image = renderer.uiImage?.pngData() else { throw CocoaError(.fileWriteUnknown) }
                try image.write(to: documents.appendingPathComponent(cover))
                tracks.append(Track(id: id, title: titles[index], artist: artists[index], album: albums[index], style: group,
                                    filename: filename, isImported: true, length: 48, artworkFilename: cover, albumArtist: artists[index],
                                    genre: group == 0 ? "Ambient" : "Electronic", year: "2026", trackNumber: index + 1, discNumber: 1,
                                    sampleRate: 22_050, bitDepth: 32, channels: 1))
            }
            var history = ListeningAnalytics()
            for offset in 0..<7 {
                let day = Calendar.current.date(byAdding: .day, value: -offset, to: Date())!
                for index in 0..<(8 - offset % 4) {
                    let track = tracks[(index + offset) % tracks.count]
                    for _ in 0..<(1 + index % 3) {
                        history.begin(track)
                        history.record(seconds: 48, mediaSeconds: 48, duration: 48, at: day)
                        history.finish(at: day)
                    }
                }
            }
            history.begin(tracks[0])
            let state = LibraryState(analytics: history, importedTracks: tracks, favorites: [tracks[0].id, tracks[2].id, tracks[4].id],
                                     playlists: [Playlist(name: "Night Drive", description: "Ambient and electronic", trackIDs: [tracks[0].id, tracks[2].id, tracks[3].id, tracks[4].id]),
                                                 Playlist(name: "Slow Mornings", trackIDs: [tracks[1].id, tracks[5].id, tracks[6].id])],
                                     recentIDs: Array(tracks.prefix(5).map(\.id)), currentID: tracks[0].id, elapsed: 14,
                                     contextIDs: tracks.map(\.id), queue: tracks.dropFirst().map { QueueEntry(trackID: $0.id) })
            defaults.set(try JSONEncoder().encode(state), forKey: "luma.library.v2")
        } catch { assertionFailure("Could not prepare documentation screenshots: \(error)") }
    }
    #endif
}

#if DEBUG
/// Original sample text used only by explicitly opted-in UI tests; never sent online.
private struct FixtureLyricsClient: LyricsSearching {
    func search(_ query: LyricsQuery) async throws -> [LyricsMatch] {
        try await Task.sleep(for: .milliseconds(100))
        return [LyricsMatch(id: 42, trackName: query.title, artistName: query.artist, albumName: "Test version", duration: 48, instrumental: false,
                            plainLyrics: "Silver light upon the water\nQuiet streets beneath the moon",
                            syncedLyrics: "[00:00.00]Silver light upon the water\n[00:10.00]Quiet streets beneath the moon")]
    }
}
#endif

enum Theme {
    static let background = Color(red: 0.035, green: 0.039, blue: 0.051)
    static let surface = Color(red: 0.084, green: 0.093, blue: 0.112)
    static let secondary = Color.white.opacity(0.68)
    static let accent = Color(red: 0.85, green: 1, blue: 0.38)
}
