import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct AddTorrentView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var urlText = ""
    @State private var downloadDir = ""
    @State private var startPaused = false
    @State private var selectedFileData: Data?
    @State private var selectedFileName: String?
    @State private var showImporter = false
    @State private var isAdding = false
    @State private var validationError: String?

    let onAddURL: (String, String?, Bool) -> Void
    let onAddFile: (Data, String?, Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 10) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.blue)
                Text("Add Torrent")
                    .font(.title2.weight(.semibold))
            }

            Form {
                Section("Source") {
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Magnet link or HTTP URL", text: $urlText)
                            .onChange(of: urlText) { validationError = nil }
                        if let error = validationError {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                    HStack {
                        Button {
                            showImporter = true
                        } label: {
                            Label("Choose .torrent file…", systemImage: "doc")
                        }
                        if let selectedFileName {
                            Text(selectedFileName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }

                Section("Options") {
                    TextField("Download directory (optional)", text: $downloadDir)
                    Toggle("Start paused", isOn: $startPaused)
                }
            }
            .formStyle(.grouped)

            HStack {
                if isAdding {
                    ProgressView()
                        .controlSize(.small)
                    Text("Adding…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                    .disabled(isAdding)
                Button("Add URL") {
                    addByURL()
                }
                .disabled(!isValidURL || isAdding)
                Button("Add File") {
                    addByFile()
                }
                .disabled(selectedFileData == nil || isAdding)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 540, height: 340)
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [UTType(filenameExtension: "torrent") ?? .data],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                if url.startAccessingSecurityScopedResource() {
                    selectedFileName = url.lastPathComponent
                    selectedFileData = try? Data(contentsOf: url)
                    url.stopAccessingSecurityScopedResource()
                }
            case .failure:
                selectedFileData = nil
            }
        }
        .onAppear {
            autoFillFromClipboard()
        }
    }

    // #8 URL Validation
    private var isValidURL: Bool {
        let trimmed = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        return trimmed.hasPrefix("magnet:") ||
               trimmed.hasPrefix("http://") ||
               trimmed.hasPrefix("https://")
    }

    private func addByURL() {
        let trimmed = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if !trimmed.hasPrefix("magnet:") && !trimmed.hasPrefix("http://") && !trimmed.hasPrefix("https://") {
            validationError = "URL must start with magnet:, http://, or https://"
            return
        }

        isAdding = true
        onAddURL(trimmed, downloadDir.isEmpty ? nil : downloadDir, startPaused)
        dismiss()
    }

    private func addByFile() {
        guard let data = selectedFileData else { return }
        isAdding = true
        onAddFile(data, downloadDir.isEmpty ? nil : downloadDir, startPaused)
        dismiss()
    }

    // #12 Auto-fill from clipboard
    private func autoFillFromClipboard() {
        guard urlText.isEmpty else { return }
        guard let string = NSPasteboard.general.string(forType: .string) else { return }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("magnet:") || trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
            urlText = trimmed
        }
    }
}
