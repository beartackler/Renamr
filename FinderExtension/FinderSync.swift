import Cocoa
import FinderSync

/// Renamr's Finder Sync extension: adds a "Rename by Example with Renamr" item to
/// Finder's right-click and toolbar menus, and hands the selection off to the
/// main app (which opens pre-scoped to those files).
///
/// NOTE: this is built by the Xcode project (see project.yml), NOT by SwiftPM —
/// SwiftPM cannot produce app-extension (.appex) bundles. It also realistically
/// needs Developer ID signing + notarization to load for end users; the macOS
/// Service in the main app gives the same "rename from Finder" workflow for $0.
class RenamrFinderSync: FIFinderSync {
    private let hostBundleID = "app.renamr.Renamr"

    override init() {
        super.init()
        // Scope to the user's home so the contextual menu is broadly available
        // without the heavy cost of monitoring the whole filesystem.
        FIFinderSyncController.default().directoryURLs = [FileManager.default.homeDirectoryForCurrentUser]
    }

    // MARK: - Menu

    override var toolbarItemName: String { "Renamr" }
    override var toolbarItemToolTip: String { "Rename selected files by example" }
    override var toolbarItemImage: NSImage {
        NSImage(systemSymbolName: "wand.and.stars", accessibilityDescription: "Renamr")
            ?? NSImage(named: NSImage.applicationIconName)!
    }

    override func menu(for menuKind: FIMenuKind) -> NSMenu {
        let menu = NSMenu(title: "")
        let item = NSMenuItem(
            title: "Rename by Example with Renamr",
            action: #selector(renameByExample(_:)),
            keyEquivalent: ""
        )
        item.image = NSImage(systemSymbolName: "wand.and.stars", accessibilityDescription: nil)
        item.target = self
        menu.addItem(item)
        return menu
    }

    // MARK: - Action

    @objc func renameByExample(_ sender: AnyObject?) {
        let controller = FIFinderSyncController.default()
        let selected = controller.selectedItemURLs() ?? []
        let targets = selected.isEmpty ? [controller.targetedURL()].compactMap { $0 } : selected
        guard !targets.isEmpty else { return }
        openInRenamr(targets)
    }

    private func openInRenamr(_ urls: [URL]) {
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: hostBundleID) else { return }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.open(urls, withApplicationAt: appURL, configuration: configuration, completionHandler: nil)
    }
}
