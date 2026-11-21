import Foundation

@main
struct WebDAVTransportCheck {
    static func main() async throws {
        let address = "http://localhost:8181/Music/"
        do {
            _ = try WebDAVLibrary(address: address, username: "", password: "")
            fatalError("Release URL validation accepted HTTP.")
        } catch WebDAVError.address {}

        let refused = try WebDAVLibrary(address: address, username: "listener", password: "invalid", allowLoopbackHTTP: true)
        do {
            _ = try await refused.catalog()
            fatalError("Server accepted the wrong password.")
        } catch WebDAVError.refused(401) {}

        let library = try WebDAVLibrary(address: address, username: "listener", password: "correct-horse", allowLoopbackHTTP: true)
        let catalog = try await library.catalog()
        precondition(catalog.count == 2, "Only same-origin playable files belong in the catalog.")
        let matches = catalog.filter { $0.matches("choir archive") }
        precondition(matches.count == 1)
        let track = matches[0]
        precondition(track.artist == "Signal Choir" && track.album == "Night Transmission")

        let audio = try await library.download(track.url)
        defer { try? FileManager.default.removeItem(at: audio.deletingLastPathComponent()) }
        let data = try Data(contentsOf: audio)
        precondition(data.starts(with: Data("RIFF".utf8)) && data.count > 100_000)

        guard let lyricsURL = track.lyricsURL else { fatalError("Missing sidecar.") }
        let lyrics = try await library.download(lyricsURL, isLyrics: true)
        defer { try? FileManager.default.removeItem(at: lyrics.deletingLastPathComponent()) }
        let text = try String(contentsOf: lyrics, encoding: .utf8)
        precondition(text.contains("[00:18]<00:18>Follow"))

        var foreign = URLComponents(url: track.url, resolvingAgainstBaseURL: true)!
        foreign.host = "127.0.0.1"
        do {
            _ = try await library.download(foreign.url!)
            fatalError("The client allowed a different origin.")
        } catch WebDAVError.address {}
        print("PASS WebDAV HTTP 401, catalog, artist/album, search, origin isolation, WAV and Enhanced LRC")
    }
}
