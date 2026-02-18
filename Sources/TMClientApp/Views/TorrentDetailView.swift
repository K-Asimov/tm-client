import SwiftUI
import TMCore

struct TorrentDetailView: View {
    let detail: TorrentDetail?

    var body: some View {
        if let detail {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(detail.name)
                        .font(.headline)
                        .lineLimit(1)
                    statusBadge(detail.status)
                    Spacer()
                }

                TabView {
                    summaryTab(detail)
                        .tabItem { Label("General", systemImage: "info.circle") }
                    transferTab(detail)
                        .tabItem { Label("Transfer", systemImage: "arrow.up.arrow.down") }
                    filesTab(detail)
                        .tabItem { Label("Files", systemImage: "doc.on.doc") }
                    trackersTab(detail)
                        .tabItem { Label("Trackers", systemImage: "antenna.radiowaves.left.and.right") }
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        } else {
            VStack(spacing: 8) {
                Image(systemName: "arrow.left")
                    .font(.largeTitle)
                    .foregroundStyle(.quaternary)
                Text("Select a torrent to see details")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 200, alignment: .center)
        }
    }

    private func statusBadge(_ status: Int) -> some View {
        Text(statusLabel(status))
            .font(.caption.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(statusColor(status).opacity(0.15), in: Capsule())
            .foregroundStyle(statusColor(status))
    }

    private func summaryTab(_ detail: TorrentDetail) -> some View {
        ScrollView {
            GroupBox {
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                    infoRow(label: "Status", value: statusLabel(detail.status))
                    infoRow(label: "Progress", value: "\(Int(detail.percentDone * 100))%")
                    infoRow(label: "Size", value: formatBytes(detail.totalSize))
                    infoRow(label: "Download Dir", value: detail.downloadDir)
                    infoRow(label: "Added", value: formatDate(detail.addedDate))
                    if !detail.errorString.isEmpty {
                        GridRow {
                            Text("Error")
                                .foregroundStyle(.secondary)
                            Text(detail.errorString)
                                .foregroundStyle(.red)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.top, 6)
        }
    }

    private func transferTab(_ detail: TorrentDetail) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                GroupBox {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Progress")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(Int(detail.percentDone * 100))%")
                                .font(.caption.monospacedDigit().weight(.semibold))
                                .foregroundStyle(statusColor(detail.status))
                        }
                        ProgressView(value: detail.percentDone)
                            .tint(statusColor(detail.status))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                GroupBox {
                    Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                        infoRow(label: "Downloaded", value: formatBytes(detail.downloadedEver))
                        infoRow(label: "Uploaded", value: formatBytes(detail.uploadedEver))
                        infoRow(label: "Ratio", value: String(format: "%.2f", detail.uploadRatio))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                GroupBox {
                    Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                        infoRow(label: "Peers", value: "\(detail.peersConnected) connected")
                        infoRow(label: "Peers Sending", value: "\(detail.peersSendingToUs)")
                        infoRow(label: "Peers Getting", value: "\(detail.peersGettingFromUs)")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.top, 6)
        }
    }

    private func filesTab(_ detail: TorrentDetail) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(detail.files) { file in
                    GroupBox {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(file.name)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            HStack(spacing: 8) {
                                ProgressView(value: fileProgress(file))
                                    .tint(file.wanted ? .blue : .gray)
                                Text("\(Int(fileProgress(file) * 100))%")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                            HStack(spacing: 12) {
                                Text("\(formatBytes(file.bytesCompleted)) / \(formatBytes(file.length))")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(file.wanted ? "Wanted" : "Skipped")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(file.wanted ? .blue : .secondary)
                                Text(priorityLabel(file.priority))
                                    .font(.caption.weight(.medium))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 1)
                                    .background(priorityColor(file.priority).opacity(0.12), in: Capsule())
                                    .foregroundStyle(priorityColor(file.priority))
                            }
                        }
                    }
                }
            }
            .padding(.top, 6)
        }
    }

    private func trackersTab(_ detail: TorrentDetail) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(detail.trackers) { tracker in
                    GroupBox {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(tracker.announce)
                                    .font(.callout.monospaced())
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Text("Tier \(tracker.tier)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                    }
                }
            }
            .padding(.top, 6)
        }
    }

    // MARK: - Helpers

    private func infoRow(label: String, value: String) -> some View {
        GridRow {
            Text(label)
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(width: 100, alignment: .trailing)
            Text(value)
                .font(.callout)
                .textSelection(.enabled)
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

    private func formatBytes(_ value: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: value)
    }

    private func formatDate(_ value: Int) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(value))
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func fileProgress(_ file: TorrentFile) -> Double {
        guard file.length > 0 else { return 0 }
        return Double(file.bytesCompleted) / Double(file.length)
    }

    private func priorityLabel(_ value: Int) -> String {
        switch value {
        case 1: return "High"
        case -1: return "Low"
        default: return "Normal"
        }
    }

    private func priorityColor(_ value: Int) -> Color {
        switch value {
        case 1: return .red
        case -1: return .blue
        default: return .gray
        }
    }
}
