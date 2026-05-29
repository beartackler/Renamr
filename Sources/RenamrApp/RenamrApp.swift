import SwiftUI
import AppKit

@main
struct RenamrApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        WindowGroup("Renamr") {
            ContentView()
                .environmentObject(RenameModel.shared)
                .frame(minWidth: 780, minHeight: 500)
        }
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(after: .newItem) {
                Button("Open Folder…") { RenameModel.shared.chooseFolder() }
                    .keyboardShortcut("o")
                Button("Use Frontmost Finder Folder") { RenameModel.shared.openFrontmostFinderFolder() }
                    .keyboardShortcut("f", modifiers: [.command, .shift])
            }
        }
    }
}

/// Bridges the macOS Services system (Finder right-click) into the app.
final class ServiceProvider: NSObject {
    @objc func renameByExample(_ pasteboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString>) {
        let urls = (pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL]) ?? []
        guard !urls.isEmpty else { return }
        Task { @MainActor in
            RenameModel.shared.loadFiles(urls: urls)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let serviceProvider = ServiceProvider()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.servicesProvider = serviceProvider
        NSUpdateDynamicServices()
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
