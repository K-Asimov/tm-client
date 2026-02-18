import Foundation

public struct TorrentFile: Identifiable, Hashable {
    public let id: Int
    public let name: String
    public let length: Int64
    public let bytesCompleted: Int64
    public let wanted: Bool
    public let priority: Int

    public init(
        id: Int,
        name: String,
        length: Int64,
        bytesCompleted: Int64,
        wanted: Bool,
        priority: Int
    ) {
        self.id = id
        self.name = name
        self.length = length
        self.bytesCompleted = bytesCompleted
        self.wanted = wanted
        self.priority = priority
    }

    public static func from(json: [String: Any], stats: [String: Any]?, index: Int) -> TorrentFile? {
        guard
            let name = json["name"] as? String,
            let length = JSONValue.int64(json["length"]),
            let bytesCompleted = JSONValue.int64(json["bytesCompleted"])
        else {
            return nil
        }

        let wanted = stats?["wanted"] as? Bool ?? true
        let priority = stats?["priority"] as? Int ?? 0

        return TorrentFile(
            id: index,
            name: name,
            length: length,
            bytesCompleted: bytesCompleted,
            wanted: wanted,
            priority: priority
        )
    }
}
