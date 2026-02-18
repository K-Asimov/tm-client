import SwiftUI
import TMCore

struct TorrentRowView: View {
    let torrent: Torrent

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(torrent.name)
                    .font(.headline)
                Spacer()
                Text(statusLabel)
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: torrent.percentDone)
            HStack(spacing: 12) {
                Text("\(Int(torrent.percentDone * 100))%")
                Text(formatBytes(torrent.totalSize))
                Text("↓ \(formatSpeed(torrent.rateDownload))")
                Text("↑ \(formatSpeed(torrent.rateUpload))")
                Text("ETA \(formatEta(torrent.eta))")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private var statusLabel: String {
        switch torrent.status {
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
