import Foundation
import TMCore

@MainActor
final class SettingsStore {
    static let shared = SettingsStore()
    private let defaults = UserDefaults.standard

    private enum Key {
        // Connection
        static let host = "rpc.host"
        static let port = "rpc.port"
        static let path = "rpc.path"
        static let username = "rpc.username"
        static let password = "rpc.password"
        // Interface
        static let autoRefresh = "ui.autoRefresh"
        static let refreshInterval = "ui.refreshInterval"
        // Client behavior
        static let startAddedTorrents = "client.startAddedTorrents"
        static let deleteTorrentFile = "client.deleteTorrentFile"
        static let autoAddClipboard = "client.autoAddClipboard"
        // App state
        static let hasEverConnected = "app.hasEverConnected"
        static let lastConnectedHost = "app.lastConnectedHost"
        static let lastConnectedPort = "app.lastConnectedPort"
    }

    // MARK: - Connection

    func loadConnection() -> RPCConnection {
        let host = defaults.string(forKey: Key.host) ?? "localhost"
        let port = defaults.integer(forKey: Key.port)
        let rpcPath = defaults.string(forKey: Key.path) ?? "/transmission/rpc"
        let username = defaults.string(forKey: Key.username) ?? ""
        let password = KeychainStore.password(for: Key.password) ?? ""

        return RPCConnection(
            host: host,
            port: port == 0 ? 9091 : port,
            rpcPath: rpcPath,
            username: username,
            password: password
        )
    }

    func saveConnection(_ connection: RPCConnection) {
        defaults.set(connection.host, forKey: Key.host)
        defaults.set(connection.port, forKey: Key.port)
        defaults.set(connection.rpcPath, forKey: Key.path)
        defaults.set(connection.username, forKey: Key.username)
        if connection.password.isEmpty {
            KeychainStore.deletePassword(for: Key.password)
        } else {
            KeychainStore.savePassword(connection.password, for: Key.password)
        }
    }

    // MARK: - Interface

    func loadAutoRefreshEnabled() -> Bool {
        defaults.object(forKey: Key.autoRefresh) as? Bool ?? true
    }

    func saveAutoRefreshEnabled(_ value: Bool) {
        defaults.set(value, forKey: Key.autoRefresh)
    }

    func loadRefreshInterval() -> TimeInterval {
        let value = defaults.double(forKey: Key.refreshInterval)
        return value == 0 ? 10 : value
    }

    func saveRefreshInterval(_ value: TimeInterval) {
        defaults.set(value, forKey: Key.refreshInterval)
    }

    // MARK: - Client behavior

    func loadStartAddedTorrents() -> Bool {
        defaults.object(forKey: Key.startAddedTorrents) as? Bool ?? true
    }

    func saveStartAddedTorrents(_ value: Bool) {
        defaults.set(value, forKey: Key.startAddedTorrents)
    }

    func loadDeleteTorrentFile() -> Bool {
        defaults.object(forKey: Key.deleteTorrentFile) as? Bool ?? false
    }

    func saveDeleteTorrentFile(_ value: Bool) {
        defaults.set(value, forKey: Key.deleteTorrentFile)
    }

    func loadAutoAddClipboard() -> Bool {
        defaults.object(forKey: Key.autoAddClipboard) as? Bool ?? false
    }

    func saveAutoAddClipboard(_ value: Bool) {
        defaults.set(value, forKey: Key.autoAddClipboard)
    }

    // MARK: - App state

    var hasEverConnected: Bool {
        defaults.bool(forKey: Key.hasEverConnected)
    }

    var lastConnectedHost: String? {
        defaults.string(forKey: Key.lastConnectedHost)
    }

    var lastConnectedPort: Int? {
        guard defaults.object(forKey: Key.lastConnectedPort) != nil else { return nil }
        return defaults.integer(forKey: Key.lastConnectedPort)
    }

    func markConnected(host: String, port: Int) {
        defaults.set(true, forKey: Key.hasEverConnected)
        defaults.set(host, forKey: Key.lastConnectedHost)
        defaults.set(port, forKey: Key.lastConnectedPort)
    }
}
