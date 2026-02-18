import AppKit
import SwiftUI
import TMCore
import UniformTypeIdentifiers

struct ContentView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var selected: Set<Int> = []
    @State private var selectedFilter: TorrentFilter = .all
    @State private var showAddTorrent = false
    @State private var showTrackerEditor = false
    @State private var searchText = ""

    @State private var showRemoveConfirm = false
    @State private var removeWithData = false
    @State private var pendingRemoveIds: [Int] = []

    @State private var sortOrder = TorrentSortOrder.name
    @State private var sortAscending = true

    @AppStorage("ui.selectedFilter") private var persistedFilter: String = "all"
    @AppStorage("ui.showDetail") private var showDetail = false

    var body: some View {
        HSplitView {
            VStack(spacing: 0) {
                filterAndSortBar

                Group {
                    if viewModel.torrents.isEmpty && !viewModel.isLoading {
                        emptyState
                    } else if sortedFilteredTorrents.isEmpty && !searchText.isEmpty {
                        searchEmptyState
                    } else {
                        torrentTable
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                statusBar
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if showDetail {
                TorrentDetailView(detail: viewModel.selectedTorrentDetail)
                    .frame(minWidth: 250, idealWidth: 300, maxWidth: 360)
                    .frame(maxHeight: .infinity)
            }
        }
        .frame(minWidth: 900, minHeight: 620)
        .task {
            if let filter = TorrentFilter(rawValue: persistedFilter) {
                selectedFilter = filter
            }
            guard viewModel.shouldAutoConnect else { return }
            await viewModel.connect()
        }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            handleDrop(providers)
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Menu {
                    SettingsLink {
                        Text("Connection Settings…")
                    }
                    Button("Connect") { Task { await viewModel.connect() } }
                } label: {
                    Label(viewModel.connection.host, systemImage: "server.rack")
                }
                .help("Server connection")
            }
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    showAddTorrent = true
                } label: {
                    Label("Add", systemImage: "plus")
                }
                .keyboardShortcut("n")
                .help("Add torrent (⌘N)")

                Button {
                    pasteFromClipboard()
                } label: {
                    Label("Paste URL", systemImage: "doc.on.clipboard")
                }
                .keyboardShortcut("v", modifiers: [.command, .shift])
                .help("Add torrent from clipboard (⇧⌘V)")

                Button {
                    Task { await viewModel.start(ids: Array(selected)) }
                } label: {
                    Label("Start", systemImage: "play.fill")
                }
                .disabled(selected.isEmpty)
                .help("Resume selected torrents")

                Button {
                    Task { await viewModel.stop(ids: Array(selected)) }
                } label: {
                    Label("Stop", systemImage: "pause.fill")
                }
                .disabled(selected.isEmpty)
                .help("Pause selected torrents")

                Button {
                    requestRemove(ids: Array(selected), withData: false)
                } label: {
                    Label("Remove", systemImage: "trash")
                }
                .disabled(selected.isEmpty)
                .keyboardShortcut(.delete, modifiers: [])
                .help("Remove selected torrents")

                Button {
                    Task { await viewModel.refresh() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .keyboardShortcut("r")
                .help("Refresh torrent list (⌘R)")

                SettingsLink {
                    Label("Preferences", systemImage: "gearshape")
                }
                .keyboardShortcut(",")
                .help("Preferences (⌘,)")
            }
        }
        .sheet(isPresented: $showAddTorrent) {
            AddTorrentView(
                onAddURL: { url, dir, paused in
                    Task { await viewModel.addTorrent(url: url, downloadDir: dir, startPaused: paused) }
                },
                onAddFile: { data, dir, paused in
                    Task { await viewModel.addTorrent(fileData: data, downloadDir: dir, startPaused: paused) }
                }
            )
            .onAppear { viewModel.pauseAutoRefresh() }
            .onDisappear { viewModel.resumeAutoRefresh() }
        }
        .sheet(isPresented: $showTrackerEditor) {
            if let detail = viewModel.selectedTorrentDetail {
                TrackerEditorView(
                    trackers: detail.trackers,
                    onAdd: { urls in
                        Task { await viewModel.addTrackers(torrentId: detail.id, urls: urls) }
                    },
                    onRemove: { ids in
                        Task { await viewModel.removeTrackers(torrentId: detail.id, trackerIds: ids) }
                    },
                    onReplace: { trackerId, newURL in
                        Task { await viewModel.replaceTracker(torrentId: detail.id, trackerId: trackerId, newURL: newURL) }
                    }
                )
                .onAppear { viewModel.pauseAutoRefresh() }
                .onDisappear { viewModel.resumeAutoRefresh() }
            }
        }
        .alert("Remove Torrent\(pendingRemoveIds.count > 1 ? "s" : "")?", isPresented: $showRemoveConfirm) {
            Button("Cancel", role: .cancel) {
                pendingRemoveIds = []
            }
            Button(removeWithData ? "Remove with Data" : "Remove", role: .destructive) {
                let ids = pendingRemoveIds
                let withData = removeWithData
                pendingRemoveIds = []
                Task { await viewModel.remove(ids: ids, deleteLocalData: withData) }
            }
        } message: {
            if removeWithData {
                Text("This will remove \(pendingRemoveIds.count) torrent(s) and permanently delete their downloaded data. This cannot be undone.")
            } else {
                Text("This will remove \(pendingRemoveIds.count) torrent(s) from the list. Downloaded files will be kept.")
            }
        }
        .alert(viewModel.alertInfo?.title ?? "", isPresented: Binding(
            get: { viewModel.alertInfo != nil },
            set: { if !$0 { viewModel.alertInfo = nil } }
        )) {
            SettingsLink {
                Text("Open Preferences")
            }
            Button("OK", role: .cancel) { }
        } message: {
            if let info = viewModel.alertInfo {
                Text(info.message)
            }
        }
        .overlay(alignment: .bottom) {
            if let toast = viewModel.toast {
                ToastView(info: toast)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            withAnimation {
                                if viewModel.toast?.id == toast.id {
                                    viewModel.toast = nil
                                }
                            }
                        }
                    }
                    .padding(.bottom, 40)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.toast)
        .onChange(of: selectedFilter) { _, newValue in
            persistedFilter = newValue.rawValue
        }
        .background {
            // Hidden buttons for filter keyboard shortcuts
            Group {
                Button("") { selectedFilter = .all }
                    .keyboardShortcut("1", modifiers: .command)
                Button("") { selectedFilter = .downloading }
                    .keyboardShortcut("2", modifiers: .command)
                Button("") { selectedFilter = .complete }
                    .keyboardShortcut("3", modifiers: .command)
                Button("") { selectedFilter = .etc }
                    .keyboardShortcut("4", modifiers: .command)
                Button("") { showDetail.toggle() }
                    .keyboardShortcut("d", modifiers: [.command, .shift])
            }
            .frame(width: 0, height: 0)
            .opacity(0)
        }
    }

    // MARK: - Remove Confirmation

    private func requestRemove(ids: [Int], withData: Bool) {
        pendingRemoveIds = ids
        removeWithData = withData
        showRemoveConfirm = true
    }

    // MARK: - Drag & Drop

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        var handled = false
        for provider in providers {
            provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, _ in
                guard let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil),
                      url.pathExtension.lowercased() == "torrent" else { return }
                if let fileData = try? Data(contentsOf: url) {
                    Task { @MainActor in
                        await viewModel.addTorrent(fileData: fileData, downloadDir: nil, startPaused: false)
                    }
                }
            }
            handled = true
        }
        return handled
    }

    // MARK: - Clipboard Paste

    private func pasteFromClipboard() {
        guard let string = NSPasteboard.general.string(forType: .string) else { return }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("magnet:") || trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
            Task { await viewModel.addTorrent(url: trimmed, downloadDir: nil, startPaused: false) }
        } else {
            viewModel.toast = ToastInfo(message: "Clipboard does not contain a valid magnet or HTTP URL", isError: true)
        }
    }

    // MARK: - Filter and Sort Bar

    private var filterAndSortBar: some View {
        HStack(spacing: 8) {
            // Left: Sort + Filter
            Picker("Sort", selection: $sortOrder) {
                ForEach(TorrentSortOrder.allCases) { order in
                    Text(order.label).tag(order)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .controlSize(.small)
            .frame(width: 100)

            Button {
                sortAscending.toggle()
            } label: {
                Image(systemName: sortAscending ? "chevron.up" : "chevron.down")
                    .font(.caption2.weight(.bold))
            }
            .buttonStyle(.plain)
            .help(sortAscending ? "Ascending" : "Descending")

            Divider()
                .frame(height: 16)

            Picker("Filter", selection: $selectedFilter) {
                ForEach(TorrentFilter.allCases) { filter in
                    Text(filter.title).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: 300)

            Spacer()

            // Right: Search + Detail toggle
            searchField
                .frame(width: 160)

            Button {
                showDetail.toggle()
            } label: {
                Image(systemName: showDetail ? "sidebar.right" : "sidebar.right")
                    .symbolVariant(showDetail ? .fill : .none)
            }
            .buttonStyle(.plain)
            .help(showDetail ? "Hide Detail Panel (⇧⌘D)" : "Show Detail Panel (⇧⌘D)")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(.bar)
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.caption)
            TextField("Search torrents", text: $searchText)
                .textFieldStyle(.plain)
                .font(.caption)
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
    }

    // MARK: - Torrent Table

    private var torrentTable: some View {
        Table(sortedFilteredTorrents, selection: $selected) {
            TableColumn("Name") { torrent in
                VStack(alignment: .leading, spacing: 2) {
                    Text(torrent.name)
                        .lineLimit(1)
                        .foregroundStyle(torrent.error != 0 ? .red : .primary)
                    Text(statusLabel(torrent.status))
                        .font(.caption2)
                        .foregroundStyle(torrent.error != 0 ? .red : statusColor(torrent.status))
                }
            }
            .width(min: 200)
            TableColumn("Progress") { torrent in
                HStack(spacing: 8) {
                    ProgressView(value: torrent.percentDone)
                        .tint(statusColor(torrent.status))
                        .frame(width: 80)
                    Text("\(Int(torrent.percentDone * 100))%")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            .width(min: 130, ideal: 140)
            TableColumn("Size") { torrent in
                Text(formatBytes(torrent.totalSize))
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .width(min: 70, ideal: 80)
            TableColumn("Status") { torrent in
                HStack(spacing: 6) {
                    Circle()
                        .fill(statusColor(torrent.status))
                        .frame(width: 8, height: 8)
                    Text(statusLabel(torrent.status))
                        .font(.callout)
                }
            }
            .width(min: 100, ideal: 110)
            TableColumn("Down") { torrent in
                Text(torrent.rateDownload > 0 ? formatSpeed(torrent.rateDownload) : "—")
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(torrent.rateDownload > 0 ? .primary : .tertiary)
            }
            .width(min: 80, ideal: 90)
            TableColumn("Up") { torrent in
                Text(torrent.rateUpload > 0 ? formatSpeed(torrent.rateUpload) : "—")
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(torrent.rateUpload > 0 ? .primary : .tertiary)
            }
            .width(min: 80, ideal: 90)
            TableColumn("ETA") { torrent in
                Text(formatEta(torrent.eta))
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .width(min: 60, ideal: 70)
        }
        .alternatingRowBackgrounds()
        .contextMenu(forSelectionType: Int.self) { ids in
            if !ids.isEmpty {
                Button("Start") { Task { await viewModel.start(ids: Array(ids)) } }
                Button("Force Start") { Task { await viewModel.forceStart(ids: Array(ids)) } }
                Button("Stop") { Task { await viewModel.stop(ids: Array(ids)) } }
                Divider()
                Button("Remove…") { requestRemove(ids: Array(ids), withData: false) }
                Divider()
                Button("Verify") { Task { await viewModel.verify(ids: Array(ids)) } }
                Button("Reannounce") { Task { await viewModel.reannounce(ids: Array(ids)) } }
                Divider()
                Menu("Queue") {
                    Button("Move to Top") { Task { await viewModel.queueMove(ids: Array(ids), action: "queue-move-top") } }
                    Button("Move Up") { Task { await viewModel.queueMove(ids: Array(ids), action: "queue-move-up") } }
                    Button("Move Down") { Task { await viewModel.queueMove(ids: Array(ids), action: "queue-move-down") } }
                    Button("Move to Bottom") { Task { await viewModel.queueMove(ids: Array(ids), action: "queue-move-bottom") } }
                }
                Divider()
                if ids.count == 1, viewModel.selectedTorrentDetail != nil {
                    Button("Edit Trackers…") { showTrackerEditor = true }
                }
                if let id = ids.first, let torrent = viewModel.torrents.first(where: { $0.id == id }) {
                    Button("Copy Name") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(torrent.name, forType: .string)
                    }
                }
                Divider()
                Button("Select All") {
                    selected = Set(sortedFilteredTorrents.map(\.id))
                }
                Divider()
                Button("Remove with Data…") { requestRemove(ids: Array(ids), withData: true) }
            }
        } primaryAction: { ids in
            if let id = ids.first {
                Task { await viewModel.loadDetails(for: id) }
            }
        }
        .onChange(of: selected) { _, newValue in
            if let id = newValue.first {
                Task { await viewModel.loadDetails(for: id) }
            } else {
                viewModel.selectedTorrentDetail = nil
            }
        }
    }

    // MARK: - Empty States

    private var emptyState: some View {
        VStack(spacing: 12) {
            if viewModel.isFirstLaunch {
                Image(systemName: "externaldrive.connected.to.line.below")
                    .font(.system(size: 36))
                    .foregroundStyle(.blue)
                Text("Welcome to TMClient")
                    .font(.headline)
                Text("Connect to your Transmission server to get started.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                SettingsLink {
                    Text("Open Preferences…")
                }
                .buttonStyle(.borderedProminent)
            } else if viewModel.hasConnected {
                Image(systemName: "tray")
                    .font(.system(size: 36))
                    .foregroundStyle(.quaternary)
                Text("No torrents")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Text("Add a torrent with ⌘N or drag a .torrent file here.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else if viewModel.statusMessage != nil {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 36))
                    .foregroundStyle(.orange)
                Text("Connection Failed")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    Button("Retry") {
                        Task { await viewModel.connect() }
                    }
                    SettingsLink {
                        Text("Open Preferences")
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                Image(systemName: "wifi.slash")
                    .font(.system(size: 36))
                    .foregroundStyle(.secondary)
                Text("Not connected")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    Button("Connect") {
                        Task { await viewModel.connect() }
                    }
                    .buttonStyle(.borderedProminent)
                    SettingsLink {
                        Text("Open Preferences")
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var searchEmptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 28))
                .foregroundStyle(.quaternary)
            Text("No results for \"\(searchText)\"")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Try a different search term.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Status Bar

    private var statusBar: some View {
        HStack(spacing: 16) {
            HStack(spacing: 6) {
                Circle()
                    .fill(viewModel.statusMessage != nil ? Color.red : (viewModel.sessionInfo != nil ? Color.green : Color.gray))
                    .frame(width: 7, height: 7)

                if let status = viewModel.statusMessage {
                    Text(status)
                        .foregroundStyle(.red)
                        .lineLimit(1)
                } else if viewModel.isLoading {
                    ProgressView()
                        .controlSize(.small)
                    Text("Loading…")
                        .foregroundStyle(.secondary)
                } else if let session = viewModel.sessionInfo {
                    Text("Transmission \(session.version)")
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            HStack(spacing: 12) {
                if !selected.isEmpty {
                    Text("\(selected.count) selected")
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(.quaternary, in: Capsule())
                }

                HStack(spacing: 4) {
                    Image(systemName: "arrow.down")
                        .foregroundStyle(.blue)
                        .font(.caption2.weight(.bold))
                    Text(formatSpeed(totalDownloadRate))
                        .monospacedDigit()
                }

                HStack(spacing: 4) {
                    Image(systemName: "arrow.up")
                        .foregroundStyle(.green)
                        .font(.caption2.weight(.bold))
                    Text(formatSpeed(totalUploadRate))
                        .monospacedDigit()
                }

                Text("\(sortedFilteredTorrents.count)/\(viewModel.torrents.count) torrents")
                    .foregroundStyle(.secondary)
            }
        }
        .font(.caption)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.bar)
    }

    // MARK: - Computed Properties

    private var totalDownloadRate: Int {
        viewModel.torrents.reduce(0) { $0 + $1.rateDownload }
    }

    private var totalUploadRate: Int {
        viewModel.torrents.reduce(0) { $0 + $1.rateUpload }
    }

    private var filteredTorrents: [Torrent] {
        var result = viewModel.torrents.filter { matchesFilter($0, filter: selectedFilter) }
        if !searchText.isEmpty {
            result = result.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        return result
    }

    private var sortedFilteredTorrents: [Torrent] {
        let list = filteredTorrents
        let ascending = sortAscending
        return list.sorted { a, b in
            let result: Bool
            switch sortOrder {
            case .name:
                result = a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
            case .progress:
                result = a.percentDone < b.percentDone
            case .size:
                result = a.totalSize < b.totalSize
            case .status:
                result = a.status < b.status
            case .downloadSpeed:
                result = a.rateDownload < b.rateDownload
            case .uploadSpeed:
                result = a.rateUpload < b.rateUpload
            case .eta:
                result = a.eta < b.eta
            }
            return ascending ? result : !result
        }
    }

    // MARK: - Helpers

    private func matchesFilter(_ torrent: Torrent, filter: TorrentFilter) -> Bool {
        switch filter {
        case .all:
            return true
        case .downloading:
            return torrent.status == 3 || torrent.status == 4
        case .complete:
            return torrent.percentDone >= 1.0
        case .etc:
            // Everything not downloading and not complete
            let isDownloading = torrent.status == 3 || torrent.status == 4
            let isComplete = torrent.percentDone >= 1.0
            return !isDownloading && !isComplete
        }
    }

    private func statusLabel(_ status: Int) -> String {
        switch status {
        case 0: return "Stopped"
        case 1: return "Queued Verify"
        case 2: return "Verifying"
        case 3: return "Queued"
        case 4: return "Downloading"
        case 5: return "Queued Seed"
        case 6: return "Seeding"
        default: return "Unknown"
        }
    }

    private func formatSpeed(_ value: Int) -> String {
        let units = ["B/s", "KB/s", "MB/s", "GB/s"]
        var speed = Double(value)
        var unitIndex = 0
        while speed > 1024, unitIndex < units.count - 1 {
            speed /= 1024
            unitIndex += 1
        }
        return String(format: "%.1f %@", speed, units[unitIndex])
    }

    private func formatEta(_ value: Int) -> String {
        if value < 0 { return "—" }
        let hours = value / 3600
        let minutes = (value % 3600) / 60
        return "\(hours)h \(minutes)m"
    }

    private func formatBytes(_ value: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: value)
    }

}

#Preview {
    ContentView(viewModel: AppViewModel())
}

// MARK: - Toast View

private struct ToastView: View {
    let info: ToastInfo

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: info.isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .foregroundStyle(info.isError ? .red : .green)
            Text(info.message)
                .font(.callout)
                .lineLimit(2)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
        .shadow(radius: 4)
    }
}

// MARK: - Status Color Helper

func statusColor(_ status: Int) -> Color {
    switch status {
    case 0: return .gray
    case 1, 3, 5: return .orange
    case 2: return .orange
    case 4: return .blue
    case 6: return .green
    default: return .secondary
    }
}

// MARK: - Sort Order

private enum TorrentSortOrder: String, CaseIterable, Identifiable {
    case name, progress, size, status, downloadSpeed, uploadSpeed, eta

    var id: String { rawValue }

    var label: String {
        switch self {
        case .name: return "Name"
        case .progress: return "Progress"
        case .size: return "Size"
        case .status: return "Status"
        case .downloadSpeed: return "Down Speed"
        case .uploadSpeed: return "Up Speed"
        case .eta: return "ETA"
        }
    }
}

// MARK: - Torrent Filter

private enum TorrentFilter: String, CaseIterable, Identifiable {
    case all, downloading, complete, etc

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "All"
        case .downloading: return "Downloading"
        case .complete: return "Complete"
        case .etc: return "Etc"
        }
    }
}
