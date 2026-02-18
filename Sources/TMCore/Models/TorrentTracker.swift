import Foundation

public struct TorrentTracker: Identifiable, Hashable {
    public let id: Int
    public let announce: String
    public let scrape: String
    public let tier: Int

    public init(id: Int, announce: String, scrape: String, tier: Int) {
        self.id = id
        self.announce = announce
        self.scrape = scrape
        self.tier = tier
    }

    public static func from(json: [String: Any]) -> TorrentTracker? {
        guard
            let id = JSONValue.int(json["id"]),
            let announce = json["announce"] as? String,
            let scrape = json["scrape"] as? String,
            let tier = JSONValue.int(json["tier"])
        else {
            return nil
        }

        return TorrentTracker(id: id, announce: announce, scrape: scrape, tier: tier)
    }
}
