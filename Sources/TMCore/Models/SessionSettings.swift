import Foundation

public struct SessionSettings: Hashable {
    // Downloads
    public var downloadDir: String
    public var renamePartialFiles: Bool

    // Speed
    public var speedLimitDownEnabled: Bool
    public var speedLimitDown: Int
    public var speedLimitUpEnabled: Bool
    public var speedLimitUp: Int

    // Network
    public var dhtEnabled: Bool
    public var pexEnabled: Bool
    public var lpdEnabled: Bool
    public var utpEnabled: Bool

    // Queue
    public var downloadQueueEnabled: Bool
    public var downloadQueueSize: Int
    public var seedQueueEnabled: Bool
    public var seedQueueSize: Int
    public var queueStalledEnabled: Bool
    public var queueStalledMinutes: Int

    // Seeding
    public var seedRatioLimited: Bool
    public var seedRatioLimit: Double
    public var idleSeedLimitEnabled: Bool
    public var idleSeedLimit: Int

    public init(
        downloadDir: String,
        renamePartialFiles: Bool,
        speedLimitDownEnabled: Bool,
        speedLimitDown: Int,
        speedLimitUpEnabled: Bool,
        speedLimitUp: Int,
        dhtEnabled: Bool,
        pexEnabled: Bool,
        lpdEnabled: Bool,
        utpEnabled: Bool,
        downloadQueueEnabled: Bool,
        downloadQueueSize: Int,
        seedQueueEnabled: Bool,
        seedQueueSize: Int,
        queueStalledEnabled: Bool,
        queueStalledMinutes: Int,
        seedRatioLimited: Bool,
        seedRatioLimit: Double,
        idleSeedLimitEnabled: Bool,
        idleSeedLimit: Int
    ) {
        self.downloadDir = downloadDir
        self.renamePartialFiles = renamePartialFiles
        self.speedLimitDownEnabled = speedLimitDownEnabled
        self.speedLimitDown = speedLimitDown
        self.speedLimitUpEnabled = speedLimitUpEnabled
        self.speedLimitUp = speedLimitUp
        self.dhtEnabled = dhtEnabled
        self.pexEnabled = pexEnabled
        self.lpdEnabled = lpdEnabled
        self.utpEnabled = utpEnabled
        self.downloadQueueEnabled = downloadQueueEnabled
        self.downloadQueueSize = downloadQueueSize
        self.seedQueueEnabled = seedQueueEnabled
        self.seedQueueSize = seedQueueSize
        self.queueStalledEnabled = queueStalledEnabled
        self.queueStalledMinutes = queueStalledMinutes
        self.seedRatioLimited = seedRatioLimited
        self.seedRatioLimit = seedRatioLimit
        self.idleSeedLimitEnabled = idleSeedLimitEnabled
        self.idleSeedLimit = idleSeedLimit
    }

    public static var `default`: SessionSettings {
        SessionSettings(
            downloadDir: "",
            renamePartialFiles: true,
            speedLimitDownEnabled: false,
            speedLimitDown: 0,
            speedLimitUpEnabled: false,
            speedLimitUp: 0,
            dhtEnabled: true,
            pexEnabled: true,
            lpdEnabled: false,
            utpEnabled: true,
            downloadQueueEnabled: false,
            downloadQueueSize: 5,
            seedQueueEnabled: false,
            seedQueueSize: 5,
            queueStalledEnabled: true,
            queueStalledMinutes: 30,
            seedRatioLimited: false,
            seedRatioLimit: 2.0,
            idleSeedLimitEnabled: false,
            idleSeedLimit: 30
        )
    }

    /// Returns a dictionary of only the fields that differ from `other`, keyed by Transmission RPC names.
    public func changedFields(from other: SessionSettings) -> [String: Any] {
        var args: [String: Any] = [:]
        if downloadDir != other.downloadDir { args["download-dir"] = downloadDir }
        if renamePartialFiles != other.renamePartialFiles { args["rename-partial-files"] = renamePartialFiles }
        if speedLimitDownEnabled != other.speedLimitDownEnabled { args["speed-limit-down-enabled"] = speedLimitDownEnabled }
        if speedLimitDown != other.speedLimitDown { args["speed-limit-down"] = speedLimitDown }
        if speedLimitUpEnabled != other.speedLimitUpEnabled { args["speed-limit-up-enabled"] = speedLimitUpEnabled }
        if speedLimitUp != other.speedLimitUp { args["speed-limit-up"] = speedLimitUp }
        if dhtEnabled != other.dhtEnabled { args["dht-enabled"] = dhtEnabled }
        if pexEnabled != other.pexEnabled { args["pex-enabled"] = pexEnabled }
        if lpdEnabled != other.lpdEnabled { args["lpd-enabled"] = lpdEnabled }
        if utpEnabled != other.utpEnabled { args["utp-enabled"] = utpEnabled }
        if downloadQueueEnabled != other.downloadQueueEnabled { args["download-queue-enabled"] = downloadQueueEnabled }
        if downloadQueueSize != other.downloadQueueSize { args["download-queue-size"] = downloadQueueSize }
        if seedQueueEnabled != other.seedQueueEnabled { args["seed-queue-enabled"] = seedQueueEnabled }
        if seedQueueSize != other.seedQueueSize { args["seed-queue-size"] = seedQueueSize }
        if queueStalledEnabled != other.queueStalledEnabled { args["queue-stalled-enabled"] = queueStalledEnabled }
        if queueStalledMinutes != other.queueStalledMinutes { args["queue-stalled-minutes"] = queueStalledMinutes }
        if seedRatioLimited != other.seedRatioLimited { args["seedRatioLimited"] = seedRatioLimited }
        if seedRatioLimit != other.seedRatioLimit { args["seedRatioLimit"] = seedRatioLimit }
        if idleSeedLimitEnabled != other.idleSeedLimitEnabled { args["idle-seeding-limit-enabled"] = idleSeedLimitEnabled }
        if idleSeedLimit != other.idleSeedLimit { args["idle-seeding-limit"] = idleSeedLimit }
        return args
    }

    // Helpers to read a value trying legacy key first, then snake_case key.
    private static func bool(_ json: [String: Any], _ legacy: String, _ snake: String) -> Bool? {
        json[legacy] as? Bool ?? json[snake] as? Bool
    }
    private static func int(_ json: [String: Any], _ legacy: String, _ snake: String) -> Int? {
        json[legacy] as? Int ?? json[snake] as? Int
    }
    private static func double(_ json: [String: Any], _ legacy: String, _ snake: String) -> Double? {
        json[legacy] as? Double ?? json[snake] as? Double
    }
    private static func string(_ json: [String: Any], _ legacy: String, _ snake: String) -> String? {
        json[legacy] as? String ?? json[snake] as? String
    }

    public static func from(json: [String: Any]) -> SessionSettings? {
        guard
            let downloadDir           = string(json, "download-dir", "download_dir"),
            let renamePartialFiles    = bool(json, "rename-partial-files", "rename_partial_files"),
            let speedLimitDownEnabled = bool(json, "speed-limit-down-enabled", "speed_limit_down_enabled"),
            let speedLimitDown        = int(json, "speed-limit-down", "speed_limit_down"),
            let speedLimitUpEnabled   = bool(json, "speed-limit-up-enabled", "speed_limit_up_enabled"),
            let speedLimitUp          = int(json, "speed-limit-up", "speed_limit_up"),
            let dhtEnabled            = bool(json, "dht-enabled", "dht_enabled"),
            let pexEnabled            = bool(json, "pex-enabled", "pex_enabled"),
            let lpdEnabled            = bool(json, "lpd-enabled", "lpd_enabled"),
            let utpEnabled            = bool(json, "utp-enabled", "utp_enabled"),
            let downloadQueueEnabled  = bool(json, "download-queue-enabled", "download_queue_enabled"),
            let downloadQueueSize     = int(json, "download-queue-size", "download_queue_size"),
            let seedQueueEnabled      = bool(json, "seed-queue-enabled", "seed_queue_enabled"),
            let seedQueueSize         = int(json, "seed-queue-size", "seed_queue_size"),
            let queueStalledEnabled   = bool(json, "queue-stalled-enabled", "queue_stalled_enabled"),
            let queueStalledMinutes   = int(json, "queue-stalled-minutes", "queue_stalled_minutes"),
            let seedRatioLimited      = bool(json, "seedRatioLimited", "seed_ratio_limited"),
            let seedRatioLimit        = double(json, "seedRatioLimit", "seed_ratio_limit"),
            let idleSeedLimitEnabled  = bool(json, "idle-seeding-limit-enabled", "idle_seeding_limit_enabled"),
            let idleSeedLimit         = int(json, "idle-seeding-limit", "idle_seeding_limit")
        else {
            return nil
        }

        return SessionSettings(
            downloadDir: downloadDir,
            renamePartialFiles: renamePartialFiles,
            speedLimitDownEnabled: speedLimitDownEnabled,
            speedLimitDown: speedLimitDown,
            speedLimitUpEnabled: speedLimitUpEnabled,
            speedLimitUp: speedLimitUp,
            dhtEnabled: dhtEnabled,
            pexEnabled: pexEnabled,
            lpdEnabled: lpdEnabled,
            utpEnabled: utpEnabled,
            downloadQueueEnabled: downloadQueueEnabled,
            downloadQueueSize: downloadQueueSize,
            seedQueueEnabled: seedQueueEnabled,
            seedQueueSize: seedQueueSize,
            queueStalledEnabled: queueStalledEnabled,
            queueStalledMinutes: queueStalledMinutes,
            seedRatioLimited: seedRatioLimited,
            seedRatioLimit: seedRatioLimit,
            idleSeedLimitEnabled: idleSeedLimitEnabled,
            idleSeedLimit: idleSeedLimit
        )
    }
}
