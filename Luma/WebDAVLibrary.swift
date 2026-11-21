import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
#if canImport(FoundationXML)
import FoundationXML
#endif

struct WebDAVTrack: Identifiable, Hashable, Sendable {
    let url: URL
    let title: String
    let artist: String?
    let album: String?
    var lyricsURL: URL?
    var id: URL { url }

    func matches(_ query: String) -> Bool {
        query.split(whereSeparator: \.isWhitespace).allSatisfy { term in
            [title, artist, album].compactMap { $0 }.contains { $0.localizedStandardContains(term) }
        }
    }
}

enum WebDAVError: LocalizedError {
    case address, credentials, invalidListing, catalogLimit, fileLimit, refused(Int)

    var errorDescription: String? {
        switch self {
        case .address: "Enter an HTTPS WebDAV folder URL without a username, query, or fragment."
        case .credentials: "Use a username without a colon and provide it with the password."
        case .invalidListing: "The server didn’t return a readable WebDAV folder."
        case .catalogLimit: "Choose a smaller folder. This catalog exceeds the scan limit."
        case .fileLimit: "This file exceeds the download size limit."
        case .refused(401), .refused(403): "The server refused access. Check the folder and credentials."
        case .refused(let status): "The server returned HTTP \(status). Check the folder URL."
        }
    }
}

/// Read-only WebDAV over the user's chosen origin. The share never supplies the
/// destination for a credential, even through a redirect or a crafted href.
struct WebDAVLibrary: Sendable {
    private let root: URL
    private let rootPath: [String]
    private let authorization: String?
    private static let audioTypes: Set<String> = ["aac", "aif", "aiff", "alac", "caf", "flac", "m4a", "mp3", "wav"]
    private static let lyricTypes = ["ttml", "lrc", "yrc", "krc"]
    private static let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.urlCredentialStorage = nil
        config.httpShouldSetCookies = false
        config.urlCache = nil
        config.timeoutIntervalForRequest = 20
        config.timeoutIntervalForResource = 180
        return URLSession(configuration: config, delegate: NoRedirect(), delegateQueue: nil)
    }()

    init(address: String, username: String, password: String, allowLoopbackHTTP: Bool = false) throws {
        let value = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var parts = URLComponents(string: value), let host = parts.host, !host.isEmpty,
              parts.scheme?.lowercased() == "https" ||
                (allowLoopbackHTTP && parts.scheme?.lowercased() == "http" && host == "localhost"),
              parts.user == nil, parts.password == nil, parts.query == nil, parts.fragment == nil else {
            throw WebDAVError.address
        }
        guard !username.contains(":"), !username.isEmpty || password.isEmpty else {
            throw WebDAVError.credentials
        }
        if !parts.percentEncodedPath.hasSuffix("/") { parts.percentEncodedPath += "/" }
        guard let root = parts.url, let path = Self.path(root) else { throw WebDAVError.address }
        self.root = root
        rootPath = path
        authorization = username.isEmpty ? nil : "Basic " + Data("\(username):\(password)".utf8).base64EncodedString()
    }

    func catalog() async throws -> [WebDAVTrack] {
        var folders = [root]
        var seen: Set<[String]> = [rootPath]
        var tracks: [WebDAVTrack] = []
        var index = 0
        while index < folders.count {
            try Task.checkCancellation()
            let directory = folders[index]
            index += 1
            guard let directoryPath = Self.path(directory) else { continue }
            let listing = try await entries(in: directory)
            var folderTracks: [WebDAVTrack] = []
            var sidecars: [String: [String: URL]] = [:]
            for entry in listing {
                guard let url = URL(string: entry.href, relativeTo: directory)?.absoluteURL,
                      let path = allowedPath(url), path.count == directoryPath.count + 1,
                      path.starts(with: directoryPath), seen.insert(path).inserted,
                      let filename = path.last else { continue }
                if entry.isCollection {
                    guard folders.count < 256 else { throw WebDAVError.catalogLimit }
                    var folder = url
                    if !folder.hasDirectoryPath { folder.appendPathComponent("", isDirectory: true) }
                    folders.append(folder)
                    continue
                }
                let ext = url.pathExtension.lowercased()
                let stem = String(filename.dropLast(ext.isEmpty ? 0 : ext.count + 1))
                if Self.lyricTypes.contains(ext) { sidecars[stem, default: [:]][ext] = url }
                guard Self.audioTypes.contains(ext) else { continue }
                let relative = path.dropFirst(rootPath.count)
                var title = stem
                var artist = relative.count >= 3 ? relative.dropLast(2).last : nil
                let album = relative.count >= 2 ? relative.dropLast().last : nil
                if artist == nil, let separator = stem.range(of: " - ") {
                    let name = stem[..<separator.lowerBound].trimmingCharacters(in: .whitespaces)
                    let ending = stem[separator.upperBound...].trimmingCharacters(in: .whitespaces)
                    if !name.isEmpty, !ending.isEmpty { artist = name; title = ending }
                }
                folderTracks.append(WebDAVTrack(url: url, title: title, artist: artist, album: album))
                guard tracks.count + folderTracks.count <= 10_000 else { throw WebDAVError.catalogLimit }
            }
            for var track in folderTracks {
                let stem = track.url.deletingPathExtension().lastPathComponent
                track.lyricsURL = Self.lyricTypes.compactMap { sidecars[stem]?[$0] }.first
                tracks.append(track)
            }
        }
        return tracks.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    /// The caller owns the returned temporary directory and removes it after import.
    func download(_ url: URL, isLyrics: Bool = false) async throws -> URL {
        guard let filename = allowedPath(url)?.last else { throw WebDAVError.address }
        let limit = isLyrics ? 1_048_576 : 250_000_000
        let temporary = try await fetch(url, expectedStatus: 200, limit: limit)
        defer { try? FileManager.default.removeItem(at: temporary) }
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
        let output = folder.appendingPathComponent(filename)
        do {
            try FileManager.default.moveItem(at: temporary, to: output)
            return output
        } catch {
            try? FileManager.default.removeItem(at: folder)
            throw error
        }
    }

    private func entries(in directory: URL) async throws -> [WebDAVListing.Entry] {
        let temporary = try await fetch(directory, expectedStatus: 207, limit: 4_194_304, list: true)
        defer { try? FileManager.default.removeItem(at: temporary) }
        let xml = try Data(contentsOf: temporary)
        return try WebDAVListing.parse(xml)
    }

    private func fetch(_ url: URL, expectedStatus: Int, limit: Int, list: Bool = false) async throws -> URL {
        guard allowedPath(url) != nil else { throw WebDAVError.address }
        var request = URLRequest(url: url)
        request.setValue(authorization, forHTTPHeaderField: "Authorization")
        if list {
            request.httpMethod = "PROPFIND"
            request.setValue("1", forHTTPHeaderField: "Depth")
            request.setValue("application/xml; charset=utf-8", forHTTPHeaderField: "Content-Type")
            request.httpBody = Data(#"<propfind xmlns="DAV:"><prop><resourcetype/></prop></propfind>"#.utf8)
        }
        let (temporary, response) = try await Self.session.download(for: request)
        do {
            guard let response = response as? HTTPURLResponse else { throw WebDAVError.invalidListing }
            guard response.statusCode == expectedStatus else { throw WebDAVError.refused(response.statusCode) }
            let size = try temporary.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            guard size <= limit else { throw WebDAVError.fileLimit }
            try Task.checkCancellation()
            return temporary
        } catch {
            try? FileManager.default.removeItem(at: temporary)
            throw error
        }
    }

    private func allowedPath(_ url: URL) -> [String]? {
        guard let parts = URLComponents(url: url, resolvingAgainstBaseURL: true),
              parts.scheme?.lowercased() == root.scheme?.lowercased(),
              parts.host?.lowercased() == root.host?.lowercased(),
              (parts.port ?? (parts.scheme?.lowercased() == "https" ? 443 : 80)) ==
                (root.port ?? (root.scheme?.lowercased() == "https" ? 443 : 80)),
              parts.user == nil, parts.password == nil, parts.query == nil, parts.fragment == nil,
              let path = Self.path(url), path.starts(with: rootPath) else { return nil }
        return path
    }

    private static func path(_ url: URL) -> [String]? {
        guard let parts = URLComponents(url: url, resolvingAgainstBaseURL: true) else { return nil }
        var result: [String] = []
        for segment in parts.percentEncodedPath.split(separator: "/") {
            guard let value = segment.removingPercentEncoding, value != ".", value != "..",
                  !value.contains("/"), !value.contains("\\"), !value.contains("\0") else { return nil }
            result.append(value)
        }
        return result
    }

    private final class NoRedirect: NSObject, URLSessionTaskDelegate {
        func urlSession(_ session: URLSession, task: URLSessionTask,
                        willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest,
                        completionHandler: @escaping @Sendable (URLRequest?) -> Void) {
            completionHandler(nil)
        }
    }
}

private final class WebDAVListing: NSObject, XMLParserDelegate {
    struct Entry {
        var href = ""
        var isCollection = false
    }

    private var stack: [String] = []
    private var entries: [Entry] = []
    private var entry = Entry()
    private var text = ""
    private var propStatus = false
    private var collection = false
    private var successfulProperties = false
    private var validRoot = false

    static func parse(_ xml: Data) throws -> [Entry] {
        let delegate = WebDAVListing()
        let parser = XMLParser(data: xml)
        parser.shouldProcessNamespaces = true
        parser.shouldResolveExternalEntities = false
        parser.delegate = delegate
        guard parser.parse(), delegate.validRoot else { throw WebDAVError.invalidListing }
        return delegate.entries
    }

    func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?,
                qualifiedName: String?, attributes: [String: String]) {
        stack.append(namespaceURI == "DAV:" ? name : "")
        if stack.count > 16 { parser.abortParsing(); return }
        switch stack {
        case ["multistatus"]: validRoot = true
        case ["multistatus", "response"]: entry = Entry(); successfulProperties = false
        case ["multistatus", "response", "propstat"]: propStatus = false; collection = false
        case ["multistatus", "response", "href"], ["multistatus", "response", "propstat", "status"]: text = ""
        case ["multistatus", "response", "propstat", "prop", "resourcetype", "collection"]: collection = true
        default: break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if stack.last == "href" || stack.last == "status" { text += string }
    }

    func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?, qualifiedName: String?) {
        switch stack {
        case ["multistatus", "response", "href"]: entry.href = text.trimmingCharacters(in: .whitespacesAndNewlines)
        case ["multistatus", "response", "propstat", "status"]: propStatus = text.split(whereSeparator: \.isWhitespace).dropFirst().first == "200"
        case ["multistatus", "response", "propstat"]:
            if propStatus {
                successfulProperties = true
                if collection { entry.isCollection = true }
            }
        case ["multistatus", "response"]:
            if successfulProperties && !entry.href.isEmpty { entries.append(entry) }
        default: break
        }
        if !stack.isEmpty { stack.removeLast() }
    }
}
