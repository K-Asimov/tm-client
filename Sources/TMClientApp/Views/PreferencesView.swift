import SwiftUI
import TMCore

struct PreferencesView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: AppViewModel
    @State private var settings: SessionSettings
    @State private var connection: RPCConnection
    @State private var autoRefreshEnabled: Bool
    @State private var refreshInterval: Double
    @State private var startAddedTorrents: Bool
    @State private var deleteTorrentFile: Bool
    @State private var autoAddClipboard: Bool
    @State private var portString: String
    @State private var portError: String?
    @State private var selectedTab: PrefsTab = .general

    private enum PrefsTab: Hashable {
        case general, server
    }

    init(viewModel: AppViewModel) {
        self.viewModel = viewModel
        _settings = State(initialValue: viewModel.sessionSettings ?? .default)
        _connection = State(initialValue: viewModel.connection)
        _autoRefreshEnabled = State(initialValue: viewModel.autoRefreshEnabled)
        _refreshInterval = State(initialValue: viewModel.refreshInterval)
        _startAddedTorrents = State(initialValue: viewModel.startAddedTorrents)
        _deleteTorrentFile = State(initialValue: viewModel.deleteTorrentFile)
        _autoAddClipboard = State(initialValue: viewModel.autoAddClipboard)
        _portString = State(initialValue: String(viewModel.connection.port))
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            generalTab
                .tabItem { Label("General", systemImage: "gearshape") }
                .tag(PrefsTab.general)
            serverTab
                .tabItem { Label("Server", systemImage: "server.rack") }
                .tag(PrefsTab.server)
        }
        .frame(width: 480, height: 520)
        .onAppear { syncFromViewModel() }
        .onChange(of: viewModel.sessionSettings) { _, newValue in
            if let newValue { settings = newValue }
        }
        .onExitCommand(perform: cancelAndClose)
    }

    private func syncFromViewModel() {
        settings = viewModel.sessionSettings ?? .default
        connection = viewModel.connection
        autoRefreshEnabled = viewModel.autoRefreshEnabled
        refreshInterval = viewModel.refreshInterval
        startAddedTorrents = viewModel.startAddedTorrents
        deleteTorrentFile = viewModel.deleteTorrentFile
        autoAddClipboard = viewModel.autoAddClipboard
        portString = String(connection.port)
    }

    private func cancelAndClose() {
        syncFromViewModel()
        dismiss()
    }

    // MARK: - Save helpers

    private func saveConnection() {
        guard let port = Int(portString), port >= 1, port <= 65535 else {
            portError = "Port must be 1–65535"
            return
        }
        connection.port = port
        viewModel.connection = connection
        viewModel.saveConnection()
    }

    private func saveGeneral() {
        saveConnection()
        viewModel.updateAutoRefresh(enabled: autoRefreshEnabled, interval: refreshInterval)
        viewModel.updateClientSettings(
            startAdded: startAddedTorrents,
            deleteTorrent: deleteTorrentFile,
            autoClipboard: autoAddClipboard
        )
    }

    private var isConnected: Bool {
        viewModel.hasConnected && viewModel.serverSettings != nil
    }

    private func saveServerSettings() {
        guard isConnected else { return }
        Task { await viewModel.updateSettings(settings) }
    }

    // MARK: - General Tab

    private var generalTab: some View {
        ScrollView {
            VStack(spacing: 12) {
                GroupBox("Connection") {
                    VStack(spacing: 8) {
                        row("Host")    { TextField("", text: $connection.host) }
                        row("Port") {
                            VStack(alignment: .trailing, spacing: 2) {
                                TextField("", text: $portString)
                                    .frame(width: 80)
                                    .onChange(of: portString) { _, val in
                                        if val.isEmpty {
                                            portError = nil
                                        } else if let port = Int(val), (1...65535).contains(port) {
                                            portError = nil
                                        } else {
                                            portError = "Port must be 1–65535"
                                        }
                                    }
                                if let err = portError {
                                    Text(err).font(.caption).foregroundStyle(.red)
                                }
                            }
                        }
                        row("RPC Path") { Text(connection.rpcPath).foregroundStyle(.secondary) }
                        row("Username") { TextField("", text: $connection.username) }
                        row("Password") { SecureField("", text: $connection.password) }
                    }
                    .padding(.vertical, 4)
                }

                GroupBox("Torrents") {
                    VStack(alignment: .leading, spacing: 6) {
                        Toggle("Start added torrents immediately", isOn: $startAddedTorrents)
                        Toggle("Delete .torrent file after addition", isOn: $deleteTorrentFile)
                        Toggle("Auto-add torrent links from clipboard", isOn: $autoAddClipboard)
                        Toggle("Add .part extension to incomplete files", isOn: $settings.renamePartialFiles)
                    }
                    .padding(.vertical, 4)
                }

                GroupBox("Refresh") {
                    VStack(alignment: .leading, spacing: 6) {
                        Toggle("Auto refresh", isOn: $autoRefreshEnabled)
                        if autoRefreshEnabled {
                            HStack {
                                Text("Interval")
                                    .frame(width: 60, alignment: .leading)
                                Slider(value: $refreshInterval, in: 5...60, step: 5)
                                Text("\(Int(refreshInterval))s")
                                    .monospacedDigit()
                                    .frame(width: 32, alignment: .trailing)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                HStack {
                    Button("Save & Connect") {
                        saveGeneral()
                        Task { await viewModel.connect() }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(portError != nil)

                    Button("Save") { saveGeneral() }
                        .disabled(portError != nil)

                    Spacer()
                    connectionStatus
                }
            }
            .padding()
        }
    }

    @ViewBuilder
    private var connectionStatus: some View {
        if viewModel.hasConnected, let session = viewModel.sessionInfo {
            Label("Transmission \(session.version)", systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else if let error = viewModel.statusMessage {
            Label(error, systemImage: "xmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.red)
                .lineLimit(1)
        }
    }

    // MARK: - Server Tab

    private var serverTab: some View {
        ScrollView {
            VStack(spacing: 12) {
                GroupBox("Speed Limits") {
                    VStack(spacing: 6) {
                        toggleRow("Max download", isOn: $settings.speedLimitDownEnabled,
                                  value: $settings.speedLimitDown, unit: "KB/s")
                        toggleRow("Max upload", isOn: $settings.speedLimitUpEnabled,
                                  value: $settings.speedLimitUp, unit: "KB/s")
                    }
                    .padding(.vertical, 4)
                }

GroupBox("Queue") {
                    VStack(spacing: 6) {
                        toggleRow("Max downloads", isOn: $settings.downloadQueueEnabled,
                                  value: $settings.downloadQueueSize)
                        toggleRow("Max seeds", isOn: $settings.seedQueueEnabled,
                                  value: $settings.seedQueueSize)
                        toggleRow("Stalled after", isOn: $settings.queueStalledEnabled,
                                  value: $settings.queueStalledMinutes, unit: "min")
                    }
                    .padding(.vertical, 4)
                }

                GroupBox("Seeding") {
                    VStack(spacing: 6) {
                        toggleRowDouble("Stop at ratio", isOn: $settings.seedRatioLimited,
                                        value: $settings.seedRatioLimit)
                        toggleRow("Stop if idle for", isOn: $settings.idleSeedLimitEnabled,
                                  value: $settings.idleSeedLimit, unit: "min")
                    }
                    .padding(.vertical, 4)
                }

                GroupBox("Peer Discovery & Protocol") {
                    VStack(alignment: .leading, spacing: 6) {
                        Toggle("Distributed Hash Table (DHT)", isOn: $settings.dhtEnabled)
                        Toggle("Peer Exchange (PEX)", isOn: $settings.pexEnabled)
                        Toggle("Local Peer Discovery (LPD)", isOn: $settings.lpdEnabled)
                        Divider()
                        Toggle("Micro Transport Protocol (uTP)", isOn: $settings.utpEnabled)
                    }
                    .padding(.vertical, 4)
                }

                HStack {
                    Button("Apply") { saveServerSettings() }
                        .buttonStyle(.borderedProminent)
                        .disabled(!isConnected)
                    if !isConnected {
                        Text("Connect to a server first")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
            }
            .padding()
        }
    }

    // MARK: - Row helpers

    private func row<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(label)
                .frame(width: 80, alignment: .trailing)
                .foregroundStyle(.secondary)
            content()
        }
    }

    private func toggleRow(
        _ label: String,
        isOn: Binding<Bool>,
        value: Binding<Int>,
        unit: String? = nil
    ) -> some View {
        HStack {
            Toggle(isOn: isOn) { Text(label) }
                .toggleStyle(.checkbox)
            Spacer()
            TextField("", value: value, format: .number)
                .multilineTextAlignment(.trailing)
                .frame(width: 56)
                .disabled(!isOn.wrappedValue)
            if let unit {
                Text(unit)
                    .foregroundStyle(.secondary)
                    .frame(width: 36, alignment: .leading)
            }
        }
    }

    private func toggleRowDouble(
        _ label: String,
        isOn: Binding<Bool>,
        value: Binding<Double>
    ) -> some View {
        HStack {
            Toggle(isOn: isOn) { Text(label) }
                .toggleStyle(.checkbox)
            Spacer()
            TextField("", value: value, format: .number.precision(.fractionLength(1)))
                .multilineTextAlignment(.trailing)
                .frame(width: 56)
                .disabled(!isOn.wrappedValue)
        }
    }
}
