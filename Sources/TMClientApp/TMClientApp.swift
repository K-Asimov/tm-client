import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    var onOpenFile: ((URL) -> Void)?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.regular)
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls where url.pathExtension.lowercased() == "torrent" {
            onOpenFile?(url)
        }
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
                        guard let viewModel, let data = try? Data(contentsOf: url) else { return }
                        Task { @MainActor in
                            await viewModel.addTorrent(fileData: data, downloadDir: nil, startPaused: false)
                        }
                    }
                }
        }
        .defaultSize(width: 1200, height: 720)
        .windowToolbarStyle(.unified)

        Settings {
            PreferencesView(viewModel: viewModel)
        }
    }
}
