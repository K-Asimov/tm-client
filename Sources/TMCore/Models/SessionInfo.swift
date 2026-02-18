import Foundation

public struct SessionInfo: Hashable {
    public let version: String
    public let rpcVersion: Int
    public let downloadDir: String

    public init(version: String, rpcVersion: Int, downloadDir: String) {
        self.version = version
        self.rpcVersion = rpcVersion
        self.downloadDir = downloadDir
    }

    public static func from(json: [String: Any]) -> SessionInfo? {
        guard
            let version = json["version"] as? String,
            let rpcVersion = json["rpc-version"] as? Int,
            let downloadDir = json["download-dir"] as? String
        else {
            return nil
        }

        return SessionInfo(version: version, rpcVersion: rpcVersion, downloadDir: downloadDir)
    }
}
