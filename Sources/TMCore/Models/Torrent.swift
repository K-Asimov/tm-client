import Foundation

public struct Torrent: Identifiable, Hashable {
    public let id: Int
    public let name: String
    public let status: Int
    public let percentDone: Double
    public let rateDownload: Int
    public let rateUpload: Int
    public let eta: Int
    public let totalSize: Int64
    public let error: Int

    public init(
        id: Int,
        name: String,
        status: Int,
        percentDone: Double,
        rateDownload: Int,
        rateUpload: Int,
        eta: Int,
        totalSize: Int64,
        error: Int = 0
    ) {
        self.id = id
        self.name = name
        self.status = status
        self.percentDone = percentDone
        self.rateDownload = rateDownload
        self.rateUpload = rateUpload
        self.eta = eta
        self.totalSize = totalSize
        self.error = error
    }

    public static func from(json: [String: Any]) -> Torrent? {
        guard
            let id = JSONValue.int(json["id"]),
            let name = json["name"] as? String,
            let status = JSONValue.int(json["status"]),
            let percentDone = json["percentDone"] as? Double,
            let rateDownload = JSONValue.int(json["rateDownload"]),
            let rateUpload = JSONValue.int(json["rateUpload"]),
            let eta = JSONValue.int(json["eta"]),
            let totalSize = JSONValue.int64(json["totalSize"])
        else {
            return nil
        }

        let error = JSONValue.int(json["error"]) ?? 0

        return Torrent(
            id: id,
            name: name,
            status: status,
            percentDone: percentDone,
            rateDownload: rateDownload,
            rateUpload: rateUpload,
            eta: eta,
            totalSize: totalSize,
            error: error
        )
    }
}
