import Foundation
import os.log
import TMCore

private let logger = Logger(subsystem: "com.tmclient.macos", category: "App")

struct AlertInfo: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

struct ToastInfo: Identifiable, Equatable {
    let id = UUID()
    let message: String
    let isError: Bool

    static func == (lhs: ToastInfo, rhs: ToastInfo) -> Bool {
        lhs.id == rhs.id
    }
}

@MainActor
final class AppViewModel: ObservableObject {
    @Published var connection: RPCConnection
    @Published var torrents: [Torrent] = []
    @Published var sessionInfo: SessionInfo?
    @Published var sessionSettings: SessionSettings?
    @Published var selectedTorrentDetail: TorrentDetail?
    @Published var statusMessage: String?
    @Published var isLoading = false
    @Published var autoRefreshEnabled: Bool
    @Published var refreshInterval: TimeInterval
    @Published var startAddedTorrents: Bool
    @Published var deleteTorrentFile: Bool
    @Published var autoAddClipboard: Bool

    // Error alert for prominent display
    @Published var alertInfo: AlertInfo?
    // Toast for success/error feedback
    @Published var toast: ToastInfo?
    // Whether the app has successfully connected at least once this session
    @Published var hasConnected = false
    // Whether auto-refresh is temporarily paused (e.g. during sheet editing)
    @Published var isAutoRefreshPaused = false

    /// Snapshot of the last settings fetched from the server, used for diff comparison.
    private(set) var serverSettings: SessionSettings?

    private let settings: SettingsStore
    private var client: RPCClient
    private var refreshTask: Task<Void, Never>?

    init(settings: SettingsStore = .shared) {
        self.settings = settings
        let loaded = settings.loadConnection()
        self.connection = loaded
        self.client = RPCClient(connection: loaded)
        self.autoRefreshEnabled = settings.loadAutoRefreshEnabled()
        self.refreshInterval = settings.loadRefreshInterval()
        self.startAddedTorrents = settings.loadStartAddedTorrents()
        self.deleteTorrentFile = settings.loadDeleteTorrentFile()
        self.autoAddClipboard = settings.loadAutoAddClipboard()
    }

    var isFirstLaunch: Bool {
        !settings.hasEverConnected
    }

    /// 이전에 성공적으로 접속한 적 있는 주소와 현재 설정이 일치할 때만 자동 접속
    var shouldAutoConnect: Bool {
        guard settings.hasEverConnected else { return false }
        guard let lastHost = settings.lastConnectedHost,
              let lastPort = settings.lastConnectedPort else {
            // 이전 버전에서 업그레이드한 경우: lastConnected 정보가 없으면 자동 접속 허용
            return true
        }
        return connection.host == lastHost && connection.port == lastPort
    }

    func connect(retries: Int = 3) async {
        logger.info("Connecting to \(self.connection.host):\(self.connection.port)")
        isLoading = true
        statusMessage = nil
        client.connection = connection
        settings.saveConnection(connection)

        var lastError: Error?
        for attempt in 0..<retries {
            if attempt > 0 {
                statusMessage = "Retrying connection… (\(attempt + 1)/\(retries))"
                try? await Task.sleep(nanoseconds: UInt64(attempt) * 2_000_000_000)
            }
            do {
                sessionInfo = try await client.fetchSessionInfo()
                hasConnected = true
                settings.markConnected(host: connection.host, port: connection.port)
                logger.info("Connected successfully")
                lastError = nil
                break
            } catch {
                logger.warning("Connection attempt \(attempt + 1) failed: \(error.localizedDescription)")
                lastError = error
            }
        }

        if let error = lastError {
            statusMessage = error.localizedDescription
            alertInfo = AlertInfo(
                title: "Connection Failed",
                message: "Could not connect to \(connection.host):\(connection.port).\n\n\(error.localizedDescription)\n\nCheck your connection settings in Preferences."
            )
            isLoading = false
            return
        }

        // These may fail independently without breaking the connection itself.
        do {
            let fetched = try await client.fetchSessionSettings()
            sessionSettings = fetched
            serverSettings = fetched
        } catch {
            statusMessage = "Connected, but failed to load server settings: \(error.localizedDescription)"
        }

        do {
            torrents = try await client.fetchTorrents()
        } catch {
            statusMessage = "Connected, but failed to load torrents: \(error.localizedDescription)"
        }

        startAutoRefreshIfNeeded()
        isLoading = false
    }

    func refresh() async {
        guard !isAutoRefreshPaused else { return }
        isLoading = true
        statusMessage = nil
        do {
            torrents = try await client.fetchTorrents()
        } catch {
            statusMessage = error.localizedDescription
        }
        isLoading = false
    }

    func loadDetails(for id: Int) async {
        statusMessage = nil
        do {
            selectedTorrentDetail = try await client.fetchTorrentDetail(id: id)
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func addTorrent(url: String, downloadDir: String?, startPaused: Bool) async {
        await handleAction(successMessage: "Torrent added successfully") {
            try await client.addTorrent(fromURL: url, downloadDir: downloadDir, startPaused: startPaused)
        }
    }

    func addTorrent(fileData: Data, downloadDir: String?, startPaused: Bool) async {
        await handleAction(successMessage: "Torrent file added successfully") {
            try await client.addTorrent(fromData: fileData, downloadDir: downloadDir, startPaused: startPaused)
        }
    }

    func updateSettings(_ newSettings: SessionSettings) async {
        guard let original = serverSettings else { return }
        let changes = newSettings.changedFields(from: original)
        guard !changes.isEmpty else {
            toast = ToastInfo(message: "No changes to save", isError: false)
            return
        }
        await handleAction(successMessage: "Settings saved") {
            try await client.updateSessionSettings(newSettings, changedFrom: original)
            // Update succeeded — accept newSettings as the baseline even if re-fetch fails.
            serverSettings = newSettings
            sessionSettings = newSettings
            if let fetched = try? await client.fetchSessionSettings() {
                sessionSettings = fetched
                serverSettings = fetched
            }
        }
    }

    func addTrackers(torrentId: Int, urls: [String]) async {
        await handleAction(successMessage: "Tracker added") { try await client.addTrackers(id: torrentId, urls: urls) }
    }

    func removeTrackers(torrentId: Int, trackerIds: [Int]) async {
        await handleAction { try await client.removeTrackers(id: torrentId, trackerIds: trackerIds) }
    }

    func replaceTracker(torrentId: Int, trackerId: Int, newURL: String) async {
        await handleAction { try await client.replaceTracker(id: torrentId, trackerId: trackerId, newURL: newURL) }
    }

    func updateAutoRefresh(enabled: Bool, interval: TimeInterval) {
        autoRefreshEnabled = enabled
        refreshInterval = interval
        settings.saveAutoRefreshEnabled(enabled)
        settings.saveRefreshInterval(interval)
        startAutoRefreshIfNeeded()
    }

    func updateClientSettings(startAdded: Bool, deleteTorrent: Bool, autoClipboard: Bool) {
        startAddedTorrents = startAdded
        deleteTorrentFile = deleteTorrent
        autoAddClipboard = autoClipboard
        settings.saveStartAddedTorrents(startAdded)
        settings.saveDeleteTorrentFile(deleteTorrent)
        settings.saveAutoAddClipboard(autoClipboard)
    }

    func saveConnection() {
        client.connection = connection
        settings.saveConnection(connection)
    }

    func start(ids: [Int]) async {
        await handleAction(successMessage: "\(ids.count) torrent(s) started") { try await client.startTorrents(ids: ids) }
    }

    func forceStart(ids: [Int]) async {
        await handleAction(successMessage: "\(ids.count) torrent(s) force started") { try await client.forceStartTorrents(ids: ids) }
    }

    func stop(ids: [Int]) async {
        await handleAction(successMessage: "\(ids.count) torrent(s) stopped") { try await client.stopTorrents(ids: ids) }
    }

    func remove(ids: [Int], deleteLocalData: Bool) async {
        let msg = deleteLocalData ? "\(ids.count) torrent(s) removed with data" : "\(ids.count) torrent(s) removed"
        // Clear detail if the selected torrent is being removed
        if let detailId = selectedTorrentDetail?.id, ids.contains(detailId) {
            selectedTorrentDetail = nil
        }
        await handleAction(successMessage: msg) { try await client.removeTorrents(ids: ids, deleteLocalData: deleteLocalData) }
    }

    func verify(ids: [Int]) async {
        await handleAction(successMessage: "Verification started") { try await client.verifyTorrents(ids: ids) }
    }

    func reannounce(ids: [Int]) async {
        await handleAction { try await client.reannounceTorrents(ids: ids) }
    }

    func queueMove(ids: [Int], action: String) async {
        await handleAction { try await client.queueMove(ids: ids, action: action) }
    }


    func pauseAutoRefresh() {
        isAutoRefreshPaused = true
    }

    func resumeAutoRefresh() {
        isAutoRefreshPaused = false
    }

    private func handleAction(successMessage: String? = nil, _ action: () async throws -> Void) async {
        isLoading = true
        statusMessage = nil
        do {
            try await action()
            torrents = try await client.fetchTorrents()
            logger.debug("Fetched \(self.torrents.count) torrents")
            if let detailId = selectedTorrentDetail?.id {
                do {
                    selectedTorrentDetail = try await client.fetchTorrentDetail(id: detailId)
                } catch {
                    logger.warning("Detail fetch failed (torrent \(detailId) may have been removed): \(error.localizedDescription)")
                    selectedTorrentDetail = nil
                }
            }
            if let msg = successMessage {
                logger.info("\(msg)")
                toast = ToastInfo(message: msg, isError: false)
            }
        } catch {
            logger.error("Action failed: \(error.localizedDescription)")
            statusMessage = error.localizedDescription
            toast = ToastInfo(message: error.localizedDescription, isError: true)
        }
        isLoading = false
    }

    private func startAutoRefreshIfNeeded() {
        refreshTask?.cancel()
        guard autoRefreshEnabled, refreshInterval > 0 else {
            return
        }
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64((self?.refreshInterval ?? 10) * 1_000_000_000))
                await self?.refresh()
            }
        }
    }
}
