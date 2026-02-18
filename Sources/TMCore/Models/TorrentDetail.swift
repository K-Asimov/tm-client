import Foundation

public struct TorrentDetail: Hashable {
    public let id: Int
    public let name: String
    public let status: Int
    public let percentDone: Double
    public let totalSize: Int64
    public let downloadDir: String
    public let addedDate: Int
    public let uploadedEver: Int64
    public let downloadedEver: Int64
    public let uploadRatio: Double
    public let errorString: String
    public let peersConnected: Int
    public let peersGettingFromUs: Int
    public let peersSendingToUs: Int
    public let files: [TorrentFile]
    public let trackers: [TorrentTracker]

    public init(
        id: Int,
        name: String,
        status: Int,
        percentDone: Double,
        totalSize: Int64,
        downloadDir: String,
        addedDate: Int,
        uploadedEver: Int64,
        downloadedEver: Int64,
        uploadRatio: Double,
        errorString: String,
        peersConnected: Int,
        peersGettingFromUs: Int,
        peersSendingToUs: Int,
        files: [TorrentFile],
        trackers: [TorrentTracker]
    ) {
        self.id = id
        self.name = name
        self.status = status
        self.percentDone = percentDone
        self.totalSize = totalSize
        self.downloadDir = downloadDir
        self.addedDate = addedDate
        self.uploadedEver = uploadedEver
        self.downloadedEver = downloadedEver
        self.uploadRatio = uploadRatio
        self.errorString = errorString
        self.peersConnected = peersConnected
        self.peersGettingFromUs = peersGettingFromUs
        self.peersSendingToUs = peersSendingToUs
        self.files = files
        self.trackers = trackers
    }

    public static func from(json: [String: Any]) -> TorrentDetail? {
        guard
            let id = JSONValue.int(json["id"]),
            let name = json["name"] as? String,
            let status = JSONValue.int(json["status"]),
            let percentDone = json["percentDone"] as? Double,
            let totalSize = JSONValue.int64(json["totalSize"]),
            let downloadDir = json["downloadDir"] as? String,
            let addedDate = JSONValue.int(json["addedDate"]),
            let uploadedEver = JSONValue.int64(json["uploadedEver"]),
            let downloadedEver = JSONValue.int64(json["downloadedEver"]),
            let uploadRatio = json["uploadRatio"] as? Double,
            let errorString = json["errorString"] as? String,
            let peersConnected = JSONValue.int(json["peersConnected"]),
            let peersGettingFromUs = JSONValue.int(json["peersGettingFromUs"]),
            let peersSendingToUs = JSONValue.int(json["peersSendingToUs"])
        else {
            return nil
        }

        let filesJson = json["files"] as? [[String: Any]] ?? []
        let statsJson = json["fileStats"] as? [[String: Any]] ?? []
        let files = filesJson.enumerated().compactMap { index, file in
            let stats = index < statsJson.count ? statsJson[index] : nil
            return TorrentFile.from(json: file, stats: stats, index: index)
        }

        let trackersJson = json["trackers"] as? [[String: Any]] ?? []
        let trackers = trackersJson.compactMap(TorrentTracker.from)

        return TorrentDetail(
            id: id,
            name: name,
            status: status,
            percentDone: percentDone,
            totalSize: totalSize,
            downloadDir: downloadDir,
            addedDate: addedDate,
            uploadedEver: uploadedEver,
            downloadedEver: downloadedEver,
            uploadRatio: uploadRatio,
            errorString: errorString,
            peersConnected: peersConnected,
            peersGettingFromUs: peersGettingFromUs,
            peersSendingToUs: peersSendingToUs,
            files: files,
            trackers: trackers
        )
    }
}
