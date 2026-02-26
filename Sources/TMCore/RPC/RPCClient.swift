import Foundation

@MainActor
public final class RPCClient {
    public var connection: RPCConnection
    private let urlSession: URLSession
    private var sessionId: String?

    public init(connection: RPCConnection, urlSession: URLSession = .shared) {
        self.connection = connection
        self.urlSession = urlSession
    }

    public func fetchSessionInfo() async throws -> SessionInfo {
        let response = try await call(method: "session-get", arguments: [:])
        guard let info = SessionInfo.from(json: response) else {
            throw RPCError.invalidPayload
        }
        return info
    }

    public func fetchSessionSettings() async throws -> SessionSettings {
        let response = try await call(method: "session-get", arguments: [:])
        guard let settings = SessionSettings.from(json: response) else {
            throw RPCError.invalidPayload
        }
        return settings
    }

    public func updateSessionSettings(_ newSettings: SessionSettings, changedFrom original: SessionSettings) async throws {
        let args = newSettings.changedFields(from: original)
        guard !args.isEmpty else { return }
        _ = try await call(method: "session-set", arguments: args)
    }

    public func fetchTorrents() async throws -> [Torrent] {
        let fields = [
            "id",
            "name",
            "status",
            "percentDone",
            "rateDownload",
            "rateUpload",
            "eta",
            "totalSize",
            "error"
        ]
        let response = try await call(method: "torrent-get", arguments: ["fields": fields])
        guard let torrents = response["torrents"] as? [[String: Any]] else {
            return []
        }
        return torrents.compactMap(Torrent.from)
    }

    public func fetchTorrentDetail(id: Int) async throws -> TorrentDetail {
        let fields = [
            "id",
            "name",
            "status",
            "percentDone",
            "totalSize",
            "downloadDir",
            "addedDate",
            "uploadedEver",
            "downloadedEver",
            "uploadRatio",
            "errorString",
            "peersConnected",
            "peersGettingFromUs",
            "peersSendingToUs",
            "files",
            "fileStats",
            "trackers"
        ]
        let response = try await call(method: "torrent-get", arguments: ["fields": fields, "ids": [id]])
        guard let torrents = response["torrents"] as? [[String: Any]], let first = torrents.first else {
            throw RPCError.invalidPayload
        }
        guard let detail = TorrentDetail.from(json: first) else {
            throw RPCError.invalidPayload
        }
        return detail
    }

    public func startTorrents(ids: [Int]) async throws {
        _ = try await call(method: "torrent-start", arguments: ["ids": ids])
    }

    public func forceStartTorrents(ids: [Int]) async throws {
        _ = try await call(method: "torrent-start-now", arguments: ["ids": ids])
    }

    public func stopTorrents(ids: [Int]) async throws {
        _ = try await call(method: "torrent-stop", arguments: ["ids": ids])
    }

    public func removeTorrents(ids: [Int], deleteLocalData: Bool) async throws {
        _ = try await call(
            method: "torrent-remove",
            arguments: ["ids": ids, "delete-local-data": deleteLocalData]
        )
    }

    public func addTorrent(fromURL url: String, downloadDir: String?, startPaused: Bool) async throws -> Int? {
        var args: [String: Any] = ["filename": url, "paused": startPaused]
        if let downloadDir, !downloadDir.isEmpty {
            args["download-dir"] = downloadDir
        }
        let response = try await call(method: "torrent-add", arguments: args)
        let torrentInfo = response["torrent-added"] as? [String: Any] ?? response["torrent-duplicate"] as? [String: Any]
        return torrentInfo?["id"] as? Int
    }

    public func addTorrent(fromData data: Data, downloadDir: String?, startPaused: Bool) async throws -> Int? {
        var args: [String: Any] = [
            "metainfo": data.base64EncodedString(),
            "paused": startPaused
        ]
        if let downloadDir, !downloadDir.isEmpty {
            args["download-dir"] = downloadDir
        }
        let response = try await call(method: "torrent-add", arguments: args)
        let torrentInfo = response["torrent-added"] as? [String: Any] ?? response["torrent-duplicate"] as? [String: Any]
        return torrentInfo?["id"] as? Int
    }

    public func verifyTorrents(ids: [Int]) async throws {
        _ = try await call(method: "torrent-verify", arguments: ["ids": ids])
    }

    public func reannounceTorrents(ids: [Int]) async throws {
        _ = try await call(method: "torrent-reannounce", arguments: ["ids": ids])
    }

    public func setLocation(ids: [Int], location: String, move: Bool) async throws {
        _ = try await call(
            method: "torrent-set-location",
            arguments: ["ids": ids, "location": location, "move": move]
        )
    }

    public func renamePath(id: Int, path: String, name: String) async throws {
        _ = try await call(
            method: "torrent-rename-path",
            arguments: ["ids": [id], "path": path, "name": name]
        )
    }

    public func updateFiles(torrentId: Int, fileIds: [Int], wanted: Bool) async throws {
        let key = wanted ? "files-wanted" : "files-unwanted"
        _ = try await call(method: "torrent-set", arguments: ["ids": [torrentId], key: fileIds])
    }

    public func updateFilePriority(torrentId: Int, fileIds: [Int], priority: Int) async throws {
        let key: String
        switch priority {
        case 1:
            key = "priority-high"
        case -1:
            key = "priority-low"
        default:
            key = "priority-normal"
        }
        _ = try await call(method: "torrent-set", arguments: ["ids": [torrentId], key: fileIds])
    }

    public func addTrackers(id: Int, urls: [String]) async throws {
        _ = try await call(
            method: "torrent-set",
            arguments: ["ids": [id], "trackerAdd": urls]
        )
    }

    public func removeTrackers(id: Int, trackerIds: [Int]) async throws {
        _ = try await call(
            method: "torrent-set",
            arguments: ["ids": [id], "trackerRemove": trackerIds]
        )
    }

    public func replaceTracker(id: Int, trackerId: Int, newURL: String) async throws {
        _ = try await call(
            method: "torrent-set",
            arguments: ["ids": [id], "trackerReplace": [trackerId, newURL]]
        )
    }

    public func queueMove(ids: [Int], action: String) async throws {
        _ = try await call(method: action, arguments: ["ids": ids])
    }

    private func call(method: String, arguments: [String: Any]) async throws -> [String: Any] {
        guard let url = URL(string: connection.baseURLString) else {
            throw RPCError.invalidURL
        }

        let payload: [String: Any] = [
            "method": method,
            "arguments": arguments
        ]

        let body = try JSONSerialization.data(withJSONObject: payload, options: [])
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let sessionId {
            request.setValue(sessionId, forHTTPHeaderField: "X-Transmission-Session-Id")
        }

        if !connection.username.isEmpty {
            let authString = "\(connection.username):\(connection.password)"
            if let data = authString.data(using: .utf8) {
                let token = data.base64EncodedString()
                request.setValue("Basic \(token)", forHTTPHeaderField: "Authorization")
            }
        }

        let (data, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw RPCError.invalidResponse
        }

        if http.statusCode == 401 {
            throw RPCError.unauthorized
        }

        if http.statusCode == 409, let newSession = http.value(forHTTPHeaderField: "X-Transmission-Session-Id") {
            sessionId = newSession
            return try await call(method: method, arguments: arguments)
        }

        guard http.statusCode == 200 else {
            throw RPCError.invalidResponse
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let result = json?["result"] as? String else {
            throw RPCError.invalidPayload
        }

        if result != "success" {
            throw RPCError.rpcFailure(result)
        }

        return json?["arguments"] as? [String: Any] ?? [:]
    }
}
