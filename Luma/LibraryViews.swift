import SwiftUI

private enum LibrarySection: String, CaseIterable { case songs = "Songs", albums = "Albums", artists = "Artists", favorites = "Favorites" }

enum CollectionSource {
    case all, favorites, recent, album(String, String), artist(String)
    @MainActor func tracks(in player: MusicPlayer) -> [Track] {
        switch self {
        case .all: player.tracks
        case .favorites: player.favoriteTracks
        case .recent: player.recentTracks
        case .album(let name, let artist): player.tracks.filter { $0.album == name && $0.albumGroupingArtist == artist }.sorted(by: Track.albumOrder)
        case .artist(let name): player.tracks.filter { $0.artist == name }
        }
    }
}

struct LibraryView: View {
    @Environment(MusicPlayer.self) private var player
    @Binding var showImport: Bool
    @Binding var showPlayer: Bool
    @State private var section: LibrarySection = .songs
    @State private var sort: TrackSort = .title
    @State private var genre = ""
    @State private var year = ""
    private var filteredLibrary: [Track] { player.tracks.filter { (genre.isEmpty || $0.genres.contains(genre)) && (year.isEmpty || $0.year == year) } }
    @State private var selecting = false
    @State private var selectedIDs: Set<String> = []
    @State private var pendingDeletion: Set<String> = []
    @State private var confirmDeletion = false
    @State private var showPlaylistPicker = false
    @State private var playlistTracks: [Track] = []
    private var importedIDs: Set<String> { Set(player.tracks.filter(\.isImported).map(\.id)) }
    private var deletionSummary: String { "\(pendingDeletion.count) \(pendingDeletion.count == 1 ? "song" : "songs")" }
    private var visibleTracks: [Track] { sort.apply(to: filteredLibrary.filter { section != .favorites || player.favorites.contains($0.id) }) }
    private var albums: [Track] {
        var seen: Set<String> = []
        return sort.apply(to: filteredLibrary).filter { seen.insert($0.albumKey).inserted }
    }
    private var artists: [String] { Set(filteredLibrary.map(\.artist)).sorted() }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24) {
                    Picker("Library section", selection: $section) {
                        ForEach(LibrarySection.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .disabled(selecting)
                    .accessibilityIdentifier("library.section")
                    if !selecting, !player.tracks.isEmpty {
                        HStack {
                            Menu {
                                Picker("Genre", selection: $genre) {
                                    Text("All genres").tag("")
                                    ForEach(Array(Set(player.tracks.flatMap(\.genres))).sorted(), id: \.self) { Text($0).tag($0) }
                                }
                            } label: { Label(genre.isEmpty ? "Genre" : genre, systemImage: "line.3.horizontal.decrease") }.accessibilityIdentifier("library.genreFilter")
                            Menu {
                                Picker("Year", selection: $year) {
                                    Text("All years").tag("")
                                    ForEach(Array(Set(player.tracks.compactMap(\.year))).sorted(by: >), id: \.self) { Text($0).tag($0) }
                                }
                            } label: { Text(year.isEmpty ? "Year" : year) }.accessibilityIdentifier("library.yearFilter")
                            Spacer()
                            if !genre.isEmpty || !year.isEmpty { Button("Clear filters") { genre = ""; year = "" } }
                        }
                        .font(.footnote.weight(.medium))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 11)
                        .background(Theme.surface.opacity(0.88), in: .rect(cornerRadius: 14))
                    }
                    if selecting {
                        VStack(spacing: 14) {
                            HStack {
                                Button(selectedIDs == importedIDs ? "Deselect all" : "Select all") {
                                    selectedIDs = selectedIDs == importedIDs ? [] : importedIDs
                                }.accessibilityIdentifier("library.selectAll")
                                Spacer()
                                Button("Delete (\(selectedIDs.count))", systemImage: "trash") {
                                    pendingDeletion = selectedIDs; confirmDeletion = true
                                }.disabled(selectedIDs.isEmpty).accessibilityIdentifier("library.deleteSelected")
                            }.font(.subheadline)
                            Button {
                                playlistTracks = visibleTracks.filter { selectedIDs.contains($0.id) }
                                showPlaylistPicker = true
                            } label: {
                                Label("Add to playlist (\(selectedIDs.count))", systemImage: "text.badge.plus")
                                    .frame(maxWidth: .infinity).padding(.vertical, 6)
                            }.buttonStyle(.glass).disabled(selectedIDs.isEmpty)
                                .accessibilityIdentifier("library.addSelectedToPlaylist")
                        }
                    }
                    if section == .songs || section == .favorites {
                        HStack {
                            Menu { Picker("Sort tracks", selection: $sort) { ForEach(TrackSort.allCases, id: \.self) { Text($0.rawValue).tag($0) } } } label: {
                                Label(sort.rawValue, systemImage: "arrow.up.arrow.down").font(.footnote)
                            }.accessibilityLabel("Sort tracks")
                            Spacer()
                            if !selecting {
                                Button { player.playCollection(visibleTracks, named: section.rawValue, shuffled: true) } label: { Label("Shuffle", systemImage: "shuffle").font(.footnote.weight(.medium)) }.disabled(visibleTracks.isEmpty)
                            }
                        }
                        if visibleTracks.isEmpty {
                            if !genre.isEmpty || !year.isEmpty {
                                ContentUnavailableView("No matching songs", systemImage: "line.3.horizontal.decrease", description: Text("Clear the filters to see more music."))
                            } else {
                                ContentUnavailableView(section == .favorites ? "No favorites" : "No music", systemImage: section == .favorites ? "heart" : "music.note", description: Text(section == .favorites ? "Tap the heart on a song to add it here." : "Import audio files to get started."))
                            }
                        }
                        ForEach(visibleTracks) { track in
                            if selecting {
                                Button {
                                    if selectedIDs.contains(track.id) { selectedIDs.remove(track.id) }
                                    else { selectedIDs.insert(track.id) }
                                } label: {
                                    HStack(spacing: 13) {
                                        Image(systemName: selectedIDs.contains(track.id) ? "checkmark.circle.fill" : "circle").font(.title3).foregroundStyle(Theme.accent)
                                        TrackArtwork(track: track).frame(width: 52, height: 52).clipShape(.rect(cornerRadius: 9))
                                        VStack(alignment: .leading, spacing: 5) {
                                            Text(track.title).font(.subheadline).foregroundStyle(.white)
                                            Text(track.artist).font(.caption).foregroundStyle(Theme.secondary)
                                        }.lineLimit(1)
                                        Spacer(minLength: 0)
                                    }.contentShape(Rectangle())
                                }.buttonStyle(.plain).disabled(!track.isImported)
                                    .accessibilityLabel("Select \(track.title) by \(track.artist)")
                                    .accessibilityValue(selectedIDs.contains(track.id) ? "Selected" : "Not selected")
                                    .accessibilityIdentifier("library.select.\(track.id)")
                            } else {
                                TrackRow(track: track) { player.select(track, within: visibleTracks, named: section.rawValue); showPlayer = true }
                            }
                        }
                    } else if section == .albums {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 18)], spacing: 24) {
                            ForEach(albums) { album in
                                NavigationLink {
                                    TrackCollectionView(title: album.album, subtitle: album.albumGroupingArtist, source: .album(album.album, album.albumGroupingArtist), showPlayer: $showPlayer)
                                } label: {
                                    AlbumTile(album: album)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Open album \(album.album)")
                            }
                        }
                    } else {
                        ForEach(artists, id: \.self) { artist in
                            NavigationLink {
                                TrackCollectionView(title: artist, subtitle: "Artist", source: .artist(artist), showPlayer: $showPlayer)
                            } label: {
                                HStack(spacing: 14) {
                                    Image(systemName: "person.crop.circle").font(.system(size: 38, weight: .ultraLight)).frame(width: 54, height: 54).background(.white.opacity(0.05), in: Circle())
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(artist).font(.subheadline.weight(.medium))
                                        Text("\(player.tracks.filter { $0.artist == artist }.count) tracks").font(.caption).foregroundStyle(Theme.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(Theme.secondary)
                                }
                            }.buttonStyle(.plain)
                        }
                    }
                    if !selecting {
                        NavigationLink {
                            TrackCollectionView(title: "Recently played", subtitle: "", source: .recent, showPlayer: $showPlayer)
                        } label: { Label("Recently played", systemImage: "clock.arrow.circlepath").font(.subheadline).frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 10) }.buttonStyle(.plain)
                        Button { showImport = true } label: { Label("Import your music", systemImage: "plus").frame(maxWidth: .infinity).padding(.vertical, 9) }
                            .buttonStyle(.glass)
                    }
                }.padding(24).frame(maxWidth: 650).frame(maxWidth: .infinity)
            }.background { AppBackground() }.navigationTitle("Library").navigationBarTitleDisplayMode(.large)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        if selecting {
                            Button("Done") { selecting = false; selectedIDs = [] }
                        } else {
                            Menu {
                                Button("Select songs", systemImage: "checkmark.circle") {
                                    section = .songs; genre = ""; year = ""; selectedIDs = []; selecting = true
                                }.disabled(importedIDs.isEmpty || player.importing)
                                Button(player.refreshingMetadata ? "Refreshing metadata…" : "Refresh FLAC metadata", systemImage: "arrow.clockwise") {
                                    Task { await player.refreshFLACMetadata(force: true) }
                                }.disabled(player.refreshingMetadata || player.importing)
                                Button("Delete all songs", systemImage: "trash", role: .destructive) {
                                    pendingDeletion = importedIDs; confirmDeletion = true
                                }.disabled(importedIDs.isEmpty || player.importing)
                            } label: { Image(systemName: "ellipsis.circle") }
                                .accessibilityLabel("Library options").accessibilityIdentifier("library.options")
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        if !selecting { Button("Import music", systemImage: "plus") { showImport = true } }
                    }
                }
                .onChange(of: importedIDs) { _, ids in
                    selectedIDs.formIntersection(ids)
                    if ids.isEmpty { selecting = false }
                }
                .sheet(isPresented: $showPlaylistPicker, onDismiss: { playlistTracks = [] }) {
                    AddToPlaylistView(tracks: playlistTracks, onSave: {
                        selectedIDs = []; selecting = false
                    })
                }
                .alert("Delete \(deletionSummary) from library?", isPresented: $confirmDeletion) {
                    Button("Delete \(deletionSummary)", role: .destructive) {
                        let removed = player.removeImportedTracks(withIDs: pendingDeletion)
                        selectedIDs.subtract(removed); pendingDeletion = []
                        if selectedIDs.isEmpty { selecting = false }
                    }
                    Button("Cancel", role: .cancel) { pendingDeletion = [] }
                } message: {
                    Text("This deletes STRSK MUSIC’s copies, saved lyrics, and playlist entries. Original files in Files or VLC stay unchanged. This cannot be undone.")
                }
        }
    }
}

private struct AlbumTile: View {
    let album: Track

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            CoverFrame(track: album, cornerRadius: 13)
            Text(album.album).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
            Text(album.albumGroupingArtist).font(.caption).foregroundStyle(Theme.secondary)
        }
        .lineLimit(2)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct TrackCollectionView: View {
    @Environment(MusicPlayer.self) private var player
    @State private var coverTint = ArtworkTint.neutral
    let title: String
    let subtitle: String
    let source: CollectionSource
    @Binding var showPlayer: Bool
    private var tracks: [Track] { source.tracks(in: player) }

    var body: some View {
        let tracks = self.tracks
        let coverSource = tracks.first.flatMap { player.artworkSource(for: $0) }
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 22) {
                CollectionHeader(title: title, subtitle: subtitle, tracks: tracks)
                CollectionControls(tracks: tracks, title: title)
                if tracks.isEmpty { ContentUnavailableView("No songs", systemImage: "music.note", description: Text("No songs in this collection.")) }
                ForEach(tracks) { track in TrackRow(track: track) { player.select(track, within: tracks, named: title); showPlayer = true } }
            }.padding(24).frame(maxWidth: 600).frame(maxWidth: .infinity)
        }
        .background { AppBackground(strength: 0.45, coverTint: coverTint) }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: coverSource) {
            guard let coverSource else { coverTint = .neutral; return }
            let asset = await ArtworkLoader.shared.load(coverSource)
            guard !Task.isCancelled else { return }
            coverTint = asset?.tint ?? .neutral
        }
    }
}

private struct CollectionHeader: View {
    let title: String
    let subtitle: String
    let tracks: [Track]

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            if let track = tracks.first {
                CoverFrame(track: track, cornerRadius: 22)
                    .frame(maxWidth: 244)
                    .frame(maxWidth: .infinity)
                    .shadow(color: .black.opacity(0.4), radius: 18, y: 12)
                    .padding(.vertical, 12)
            }
            Text(title).font(.largeTitle.weight(.bold)).accessibilityAddTraits(.isHeader)
            if !subtitle.isEmpty { Text(subtitle).font(.headline).foregroundStyle(Theme.accent) }
            Text("\(tracks.count) tracks · \(formattedTime(tracks.compactMap(\.length).reduce(0, +)))")
                .font(.footnote.monospacedDigit())
                .foregroundStyle(Theme.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct CollectionControls: View {
    @Environment(MusicPlayer.self) private var player
    let tracks: [Track]
    let title: String
    var body: some View {
        HStack(spacing: 12) {
            Button { player.playCollection(tracks, named: title) } label: { Label("Play", systemImage: "play.fill").frame(maxWidth: .infinity).padding(.vertical, 6) }.buttonStyle(.glassProminent).tint(Theme.accent).foregroundStyle(.black)
            Button { player.playCollection(tracks, named: title, shuffled: true) } label: { Label("Shuffle", systemImage: "shuffle").frame(maxWidth: .infinity).padding(.vertical, 6) }.buttonStyle(.glass)
        }.disabled(tracks.isEmpty)
    }
}

struct SearchView: View {
    @Environment(MusicPlayer.self) private var player
    @Binding var showPlayer: Bool
    @State private var query = ""
    private var term: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var results: [Track] { player.tracks.filter { $0.matches(term) } }
    private var playlists: [Playlist] { player.playlists.filter { !term.isEmpty && "\($0.name) \($0.description)".localizedCaseInsensitiveContains(term) } }
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 22) {
                    Text(term.isEmpty ? "Songs" : "Search results").font(.system(size: 34, design: .serif)).tracking(-0.8)
                    Text(term.isEmpty ? "Find a song, artist, album, or playlist." : "\(results.count) tracks · \(playlists.count) playlists").font(.subheadline).foregroundStyle(Theme.secondary)
                    ForEach(playlists) { playlist in
                        NavigationLink { PlaylistDetailView(playlistID: playlist.id, showPlayer: $showPlayer) } label: { PlaylistRow(playlist: playlist) }.buttonStyle(.plain)
                    }
                    ForEach(results) { track in TrackRow(track: track) { player.select(track, within: results, named: "Search results"); showPlayer = true } }
                    if results.isEmpty && playlists.isEmpty { ContentUnavailableView.search(text: query) }
                }.padding(24).frame(maxWidth: 600).frame(maxWidth: .infinity)
            }.background { AppBackground() }.navigationTitle("Search").navigationBarTitleDisplayMode(.inline)
                .searchable(text: $query, prompt: "Songs, artists, albums, playlists")
        }
    }
}
