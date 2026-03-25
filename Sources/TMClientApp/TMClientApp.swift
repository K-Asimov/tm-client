import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    var onOpenFile: ((URL) -> Void)?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.regular)
    }

    // Called by AppKit before SwiftUI can intercept — returning true prevents new window creation
    func application(_ application: NSApplication, openFile filename: String) -> Bool {
        let url = URL(fileURLWithPath: filename)
        guard url.pathExtension.lowercased() == "torrent" else { return false }
        bringWindowToFront()
        onOpenFile?(url)
        return true
    }

    func application(_ application: NSApplication, openFiles filenames: [String]) {
        bringWindowToFront()
        for filename in filenames {
            let url = URL(fileURLWithPath: filename)
            guard url.pathExtension.lowercased() == "torrent" else { continue }
            onOpenFile?(url)
        }
        NSApp.reply(toOpenOrPrint: .success)
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        // Bring the existing window to the front (prevent creating a new window)
        bringWindowToFront()
        for url in urls where url.pathExtension.lowercased() == "torrent" {
            onOpenFile?(url)
        }
    }

    /// Prevent opening a new window via Cmd+N, etc.
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
