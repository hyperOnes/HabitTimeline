import SwiftUI

@main
struct UniverseApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarWidgetController?
    private var globalKeyMonitor: Any?
    private var localKeyMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        menuBarController = MenuBarWidgetController(
            state: MenuBarWidgetState.shared,
            layoutManager: WindowLayoutManager.shared
        )
        installShortcutMonitor()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false // Keep running in menubar
    }

    deinit {
        if let monitor = globalKeyMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = localKeyMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    private func installShortcutMonitor() {
        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            _ = self?.handleShortcut(event)
        }

        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if self?.handleShortcut(event) == true {
                return nil
            }
            return event
        }
    }

    @discardableResult
    private func handleShortcut(_ event: NSEvent) -> Bool {
        if event.isARepeat {
            return false
        }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let isAKey = event.charactersIgnoringModifiers?.lowercased() == "a" || event.keyCode == 0
        guard flags.contains(.control),
              !flags.contains(.command),
              !flags.contains(.option),
              !flags.contains(.shift),
              isAKey else {
            return false
        }
        DispatchQueue.main.async {
            MenuBarWidgetState.shared.togglePopover(panel: .left)
        }
        return true
    }
}
