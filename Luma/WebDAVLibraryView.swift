import SwiftUI

struct WebDAVLibraryView: View {
    @Environment(MusicPlayer.self) private var player
    @AppStorage("strsk.webdav.address") private var savedAddress = ""
    @Binding var showPlayer: Bool
    @State private var address = ""
    @State private var username = ""
    @State private var password = ""
    @State private var library: WebDAVLibrary?
    @State private var tracks: [WebDAVTrack] = []
    @State private var query = ""
    @State private var scope: Scope?
    @State private var work: Task<Void, Never>?
    @State private var activity: String?
    @State private var message: String?

    private enum Scope: Equatable {
        case artist(String)
        case album(Album)
    }

    private struct Album: Hashable {
        let name: String
        let artist: String?
    }

    var body: some View {
        Group {
            if let library {
                List {
                    if let scope {
                        Button("Show entire catalog", systemImage: "arrow.turn.up.left") { self.scope = nil }
                        Section(scopeTitle(scope)) { trackRows(visibleTracks, library: library) }
                    } else {
                        if !artists.isEmpty {
                            Section("Artists") {
                                ForEach(artists, id: \.self) { artist in
                                    Button(artist) { scope = .artist(artist) }
                                        .accessibilityIdentifier("webdav.artist.\(artist)")
                                }
                            }
                        }
                        if !albums.isEmpty {
                            Section("Albums") {
                                ForEach(albums, id: \.self) { album in
                                    Button {
                                        scope = .album(album)
                                    } label: {
                                        VStack(alignment: .leading) {
                                            Text(album.name)
                                            if let artist = album.artist { Text(artist).font(.caption).foregroundStyle(.secondary) }
                                        }
                                    }
                                    .accessibilityIdentifier("webdav.album.\(album.name)")
                                }
                            }
                        }
                        Section("Songs") { trackRows(visibleTracks, library: library) }
                    }
                }
                .searchable(text: $query, prompt: "Songs, artists, albums")
                .toolbar {
                    Menu("Connection", systemImage: "ellipsis.circle") {
                        Button("Refresh", systemImage: "arrow.clockwise") { load(library) }
                            .disabled(work != nil)
                        Button("Disconnect", systemImage: "rectangle.portrait.and.arrow.right") { disconnect() }
                    }
                }
            } else {
                Form {
                    Section {
                        TextField("HTTPS folder URL", text: $address)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .accessibilityIdentifier("webdav.address")
                        TextField("Username (optional)", text: $username)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .accessibilityIdentifier("webdav.username")
                        SecureField("Password (optional)", text: $password)
                            .accessibilityIdentifier("webdav.password")
                        Button("Connect", action: connect)
                            .disabled(address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || work != nil)
                            .accessibilityIdentifier("webdav.connect")
                    } header: {
                        Text("WebDAV connection")
                    } footer: {
                        Text("Use a WebDAV share you have permission to access. STRSK downloads selected tracks into your library for playback, playlists, and karaoke.")
                    }
                }
            }
        }
        .navigationTitle("Remote Library")
        .safeAreaInset(edge: .bottom) {
            if let activity {
                HStack { ProgressView(); Text(activity); Spacer(); Button("Cancel") { work?.cancel() } }
                    .padding()
                    .background(.regularMaterial)
                    .accessibilityElement(children: .contain)
            }
        }
        .alert("Remote Library", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK") { message = nil }
        } message: {
            Text(message ?? "")
        }
        .onAppear(perform: prepareConnectionForm)
        .onDisappear { work?.cancel() }
    }

    private var matches: [WebDAVTrack] { tracks.filter { $0.matches(query) } }
    private var artists: [String] {
        Set(matches.compactMap(\.artist)).sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }
    private var albums: [Album] {
        Set(matches.compactMap { track in track.album.map { Album(name: $0, artist: track.artist) } })
            .sorted {
                let order = $0.name.localizedStandardCompare($1.name)
                return order == .orderedSame ? ($0.artist ?? "") < ($1.artist ?? "") : order == .orderedAscending
            }
    }
    private var visibleTracks: [WebDAVTrack] {
        switch scope {
        case .artist(let artist): matches.filter { $0.artist == artist }
        case .album(let album): matches.filter { $0.album == album.name && $0.artist == album.artist }
        case nil: matches
        }
    }

    private func scopeTitle(_ scope: Scope) -> String {
        switch scope {
        case .artist(let name): name
        case .album(let album): album.name
        }
    }

    @ViewBuilder
    private func trackRows(_ tracks: [WebDAVTrack], library: WebDAVLibrary) -> some View {
        if tracks.isEmpty {
            Text(query.isEmpty ? "No audio files found" : "No matching tracks").foregroundStyle(.secondary)
        }
        ForEach(tracks) { track in
            Button {
                download(track, from: library)
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(track.title).font(.body.weight(.medium))
                        if let detail = subtitle(for: track) {
                            Text(detail).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Image(systemName: "arrow.down.circle").accessibilityHidden(true)
                }
            }
            .accessibilityLabel("Download and play \(track.title)")
            .disabled(work != nil || player.importing)
        }
    }

    private func subtitle(for track: WebDAVTrack) -> String? {
        let parts = [track.artist, track.album].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private func connect() {
        do {
            #if DEBUG
            let allowLoopback = ProcessInfo.processInfo.arguments.contains("--ui-testing")
            #else
            let allowLoopback = false
            #endif
            let provider = try WebDAVLibrary(address: address, username: username, password: password,
                                             allowLoopbackHTTP: allowLoopback)
            load(provider)
        } catch { message = error.localizedDescription }
    }

    private func prepareConnectionForm() {
        guard address.isEmpty else { return }
        address = savedAddress
        #if DEBUG
        let process = ProcessInfo.processInfo
        if process.arguments.contains("--ui-testing"), let testAddress = process.environment["STRSK_TEST_WEBDAV_ADDRESS"] {
            address = testAddress
            username = process.environment["STRSK_TEST_WEBDAV_USERNAME"] ?? ""
            password = process.environment["STRSK_TEST_WEBDAV_PASSWORD"] ?? ""
        }
        #endif
    }

    private func load(_ provider: WebDAVLibrary) {
        run("Reading catalog…") {
            let catalog = try await provider.catalog()
            try Task.checkCancellation()
            tracks = catalog
            library = provider
            savedAddress = address
            password = ""
        }
    }

    private func download(_ track: WebDAVTrack, from provider: WebDAVLibrary) {
        run("Downloading \(track.title)…") {
            let audio = try await provider.download(track.url)
            defer { try? FileManager.default.removeItem(at: audio.deletingLastPathComponent()) }
            try Task.checkCancellation()
            guard let imported = await player.importFiles([audio]).first else { return }
            try Task.checkCancellation()
            if player.lyrics[imported.id] == nil, let lyricsURL = track.lyricsURL {
                do {
                    let lyrics = try await provider.download(lyricsURL, isLyrics: true)
                    defer { try? FileManager.default.removeItem(at: lyrics.deletingLastPathComponent()) }
                    try Task.checkCancellation()
                    _ = await player.importLyrics(lyrics, for: imported)
                } catch is CancellationError {
                    throw CancellationError()
                } catch {
                    player.error = "The audio was imported. The lyric file couldn’t be downloaded."
                }
            }
            try Task.checkCancellation()
            player.select(imported)
            showPlayer = true
        }
    }

    private func disconnect() {
        work?.cancel()
        library = nil
        tracks = []
        scope = nil
        query = ""
        username = ""
        password = ""
    }

    private func run(_ label: String, operation: @escaping @MainActor () async throws -> Void) {
        guard work == nil else { return }
        activity = label
        work = Task { @MainActor in
            defer { activity = nil; work = nil }
            do { try await operation() }
            catch {
                if !Task.isCancelled { message = error.localizedDescription }
            }
        }
    }
}
