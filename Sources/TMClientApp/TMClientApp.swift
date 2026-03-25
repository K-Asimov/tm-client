import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    var onOpenFile: ((URL) -> Void)? {
        didSet {
            // Process any files that arrived before ContentView appeared
            guard let callback = onOpenFile, !pendingOpenURLs.isEmpty else { return }
            let pending = pendingOpenURLs
            pendingOpenURLs.removeAll()
            bringWindowToFront()
            pending.forEach { callback($0) }
        }
    }
    private var pendingOpenURLs: [URL] = []

    func applicationWillFinishLaunching(_ notification: Notification) {
        // Register BEFORE SwiftUI's WindowGroup registers its own handler.
        // SwiftUI registers in applicationDidFinishLaunching, so grabbing the
        // open-document Apple Event here prevents WindowGroup from ever seeing
        // it — and therefore never creating a second window.
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleOpenDocuments(_:replyEvent:)),
            forEventClass: AEEventClass(0x61657674), // kCoreEventClass 'aevt'
            andEventID: AEEventID(0x6F646F63)        // kAEOpenDocuments 'odoc'
        )
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.regular)
    }

    // Handles kAEOpenDocuments — called instead of application(_:open:) now that
    // we own the Apple Event.
    @objc private func handleOpenDocuments(
        _ event: NSAppleEventDescriptor,
        replyEvent: NSAppleEventDescriptor
    ) {
        guard let fileList = event.paramDescriptor(forKeyword: AEKeyword(0x2D2D2D2D)) // keyDirectObject '----'
        else { return }

        let count = fileList.numberOfItems
        let descriptors: [NSAppleEventDescriptor?] = count > 0
            ? (1...count).map { fileList.atIndex($0) }
            : [fileList]

        let urls: [URL] = descriptors.compactMap { desc -> URL? in
            // Coerce to typeFileURL ('furl') to handle aliases or other descriptor types
            let d = desc?.coerce(toDescriptorType: DescType(0x6675726C)) ?? desc
            guard let data = d?.data,
                  let string = String(data: data, encoding: .utf8),
                  let url = URL(string: string),
                  url.pathExtension.lowercased() == "torrent"
            else { return nil }
            return url
        }

        guard !urls.isEmpty else { return }

        if let callback = onOpenFile {
            bringWindowToFront()
            urls.forEach { callback($0) }
        } else {
            // App is still launching; process once ContentView sets onOpenFile
            pendingOpenURLs.append(contentsOf: urls)
        }
    }

    /// Prevent opening a new window via Cmd+N, dock click, etc.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if flag {
            bringWindowToFront()
            return false
        }
        // No visible windows — let SwiftUI re-show the window
        return true
    }

    private func bringWindowToFront() {
        NSApp.windows.first(where: { $0.canBecomeKey })?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

@main
struct TMClientApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var viewModel = AppViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModel)
                .onAppear {
                    appDelegate.onOpenFile = { [weak viewModel] url in
                        guard let viewModel else { return }
                        let accessing = url.startAccessingSecurityScopedResource()
                        guard let data = try? Data(contentsOf: url) else {
                            if accessing { url.stopAccessingSecurityScopedResource() }
                            return
                        }
                        if accessing { url.stopAccessingSecurityScopedResource() }
                        Task { @MainActor in
                            await viewModel.addTorrent(fileData: data, url: url, downloadDir: nil, startPaused: false)
                        }
                    }
                }
        }
        .defaultSize(width: 1200, height: 720)
        .windowToolbarStyle(.unified)
        .commandsRemoved()  // Remove menus related to new windows, such as Cmd+N

        Settings {
            PreferencesView(viewModel: viewModel)
        }
    }
}
