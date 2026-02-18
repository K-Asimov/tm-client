import SwiftUI
import TMCore

struct TrackerEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let trackers: [TorrentTracker]
    let onAdd: ([String]) -> Void
    let onRemove: ([Int]) -> Void
    let onReplace: (Int, String) -> Void

    private enum Mode { case list, editor }

    @State private var mode: Mode = .list
    @State private var selection: Set<Int> = []
    @State private var newTracker = ""
    @State private var validationError: String?
    @State private var editorText = ""
    @State private var editorDirty = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()

            switch mode {
            case .list:
                listMode
            case .editor:
                editorMode
            }

            Divider()
            footer
        }
        .frame(width: 580, height: 480)
        .onAppear { editorText = buildEditorText() }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.title2)
                .foregroundStyle(.blue)
            Text("Trackers")
                .font(.title2.weight(.semibold))
            Spacer()
            Text("\(trackers.count) trackers")
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker("", selection: $mode) {
                Image(systemName: "list.bullet").tag(Mode.list)
                Image(systemName: "doc.plaintext").tag(Mode.editor)
            }
            .pickerStyle(.segmented)
            .frame(width: 80)
            .onChange(of: mode) { _, newMode in
                if newMode == .editor {
                    editorText = buildEditorText()
                    editorDirty = false
                }
            }
        }
        .padding()
    }

    // MARK: - List Mode

    private var listMode: some View {
        VStack(alignment: .leading, spacing: 8) {
            List(selection: $selection) {
                ForEach(trackers) { tracker in
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(tracker.announce)
                                .font(.callout.monospaced())
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Text("Tier \(tracker.tier)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .tag(tracker.id)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle")
                        .foregroundStyle(.secondary)
                    TextField("New tracker URL (http://, https://, or udp://)", text: $newTracker)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: newTracker) { validationError = nil }
                        .onSubmit { addTracker() }
                    Button("Add") { addTracker() }
                        .disabled(newTracker.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                if let error = validationError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
    }

    // MARK: - Editor Mode

    private var editorMode: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Edit tracker URLs directly. One URL per line. Empty lines separate tiers.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
                .padding(.top, 8)

            TextEditor(text: $editorText)
                .font(.callout.monospaced())
                .scrollContentBackground(.hidden)
                .padding(4)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.secondary.opacity(0.3)))
                .padding(.horizontal)
                .onChange(of: editorText) { editorDirty = true }

            HStack {
                Button("Apply Changes") { applyEditorChanges() }
                    .buttonStyle(.borderedProminent)
                    .disabled(!editorDirty)
                if editorDirty {
                    Text("Unsaved changes")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                Spacer()
                Button("Reset") {
                    editorText = buildEditorText()
                    editorDirty = false
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            if mode == .list {
                Button(selection.count == trackers.count ? "Deselect All" : "Select All") {
                    selection = selection.count == trackers.count ? [] : Set(trackers.map(\.id))
                }
                Button("Remove Selected") { onRemove(Array(selection)) }
                    .disabled(selection.isEmpty)
                if !selection.isEmpty {
                    Text("\(selection.count) selected")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button("Done") { dismiss() }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
        }
        .padding()
    }

    // MARK: - Logic

    private func addTracker() {
        let trimmed = newTracker.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard isValidTrackerURL(trimmed) else {
            validationError = "Tracker URL must start with http://, https://, or udp://"
            return
        }
        onAdd([trimmed])
        newTracker = ""
        validationError = nil
    }

    private func isValidTrackerURL(_ url: String) -> Bool {
        url.hasPrefix("http://") || url.hasPrefix("https://") || url.hasPrefix("udp://")
    }

    private func buildEditorText() -> String {
        let grouped = Dictionary(grouping: trackers, by: \.tier)
        return grouped.keys.sorted().map { tier in
            grouped[tier]!.map(\.announce).joined(separator: "\n")
        }.joined(separator: "\n\n")
    }

    private func applyEditorChanges() {
        let newURLs = parseEditorURLs()
        let oldURLs = trackers.map(\.announce)

        // URLs to remove: in old but not in new
        let toRemove = trackers.filter { !newURLs.contains($0.announce) }
        if !toRemove.isEmpty {
            onRemove(toRemove.map(\.id))
        }

        // URLs to add: in new but not in old
        let toAdd = newURLs.filter { url in !oldURLs.contains(url) }
        if !toAdd.isEmpty {
            onAdd(toAdd)
        }

        // URLs that exist in both: check if tracker needs URL replacement
        // (match by position for trackers that changed URL)
        for tracker in trackers {
            if let idx = oldURLs.firstIndex(of: tracker.announce),
               idx < newURLs.count,
               newURLs[idx] != tracker.announce {
                onReplace(tracker.id, newURLs[idx])
            }
        }

        editorDirty = false
    }

    private func parseEditorURLs() -> [String] {
        editorText
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && isValidTrackerURL($0) }
    }
}
