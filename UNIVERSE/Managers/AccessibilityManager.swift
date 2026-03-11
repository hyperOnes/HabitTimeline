import Cocoa
import ApplicationServices

/// Manages accessibility permissions and Craft window discovery/control
class AccessibilityManager: ObservableObject {
    static let shared = AccessibilityManager()

    @Published var hasPermission = false
    @Published var craftWindows: [CraftWindow] = []
    @Published var iTermWindows: [CraftWindow] = []
    @Published var atlasWindows: [CraftWindow] = []
    @Published var spotifyWindows: [CraftWindow] = []
    @Published var weatherWindows: [CraftWindow] = []
    @Published var statusMessage: String = ""

    // Try multiple possible bundle identifiers for Craft
    private let craftBundleIdentifiers = [
        "com.lukaland.Craft",
        "com.lukaland.craft",
        "com.luki.Craft"
    ]
    private let itermBundleIdentifiers = [
        "com.googlecode.iterm2"
    ]
    private let atlasBundleIdentifiers = [
        "com.openai.chatgpt",
        "com.openai.chatgpt.atlas",
        "com.openai.chatgpt.mac",
        "com.openai.chatgpt.desktop"
    ]
    private let spotifyBundleIdentifiers = [
        "com.spotify.client"
    ]
    private let weatherBundleIdentifiers = [
        "com.apple.weather"
    ]
    private var refreshTimer: Timer?

    private init() {
        _ = checkPermissions()
    }

    // MARK: - Permissions

    func checkPermissions() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): false] as CFDictionary
        hasPermission = AXIsProcessTrustedWithOptions(options)
        return hasPermission
    }

    func requestPermissions() {
        hasPermission = checkPermissions()

        if hasPermission {
            refreshCraftWindows()
        }
    }

    // MARK: - Window Discovery

    func refreshCraftWindows() {
        guard hasPermission else {
            craftWindows = []
            statusMessage = "No accessibility permission"
            return
        }

        let result = findRunningApp(bundleIdentifiers: craftBundleIdentifiers, nameHint: "craft")
        guard let app = result.app else {
            craftWindows = []
            statusMessage = "Craft app not running"
            return
        }

        statusMessage = "Found Craft: \(result.bundleId ?? "unknown")"
        let discoveredWindows = discoverWindows(for: app, appKind: .craft)

        DispatchQueue.main.async {
            self.craftWindows = discoveredWindows
            self.statusMessage = "Found \(discoveredWindows.count) Craft window(s)"
        }
    }

    func refreshItermWindows() {
        guard hasPermission else {
            iTermWindows = []
            return
        }

        let result = findRunningApp(bundleIdentifiers: itermBundleIdentifiers, nameHint: "iterm")
        guard let app = result.app else {
            iTermWindows = []
            return
        }

        let discoveredWindows = discoverWindows(for: app, appKind: .iterm)
        DispatchQueue.main.async {
            self.iTermWindows = discoveredWindows
        }
    }

    func refreshAtlasWindows() {
        guard hasPermission else {
            atlasWindows = []
            return
        }

        let result = findRunningApp(bundleIdentifiers: atlasBundleIdentifiers, nameHint: "chatgpt")
        guard let app = result.app else {
            atlasWindows = []
            return
        }

        let discoveredWindows = discoverWindows(for: app, appKind: .atlas)
        DispatchQueue.main.async {
            self.atlasWindows = discoveredWindows
        }
    }

    func refreshSpotifyWindows() {
        guard hasPermission else {
            spotifyWindows = []
            return
        }

        let result = findRunningApp(bundleIdentifiers: spotifyBundleIdentifiers, nameHint: "spotify")
        guard let app = result.app else {
            spotifyWindows = []
            return
        }

        let discoveredWindows = discoverWindows(for: app, appKind: .spotify)
        DispatchQueue.main.async {
            self.spotifyWindows = discoveredWindows
        }
    }

    func refreshWeatherWindows() {
        guard hasPermission else {
            weatherWindows = []
            return
        }

        let result = findRunningApp(bundleIdentifiers: weatherBundleIdentifiers, nameHint: "weather")
        guard let app = result.app else {
            weatherWindows = []
            return
        }

        let discoveredWindows = discoverWindows(for: app, appKind: .weather)
        DispatchQueue.main.async {
            self.weatherWindows = discoveredWindows
        }
    }

    func launchWeatherApp() {
        // Launch Weather app if not running
        if let weatherURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.weather") {
            NSWorkspace.shared.openApplication(at: weatherURL, configuration: NSWorkspace.OpenConfiguration(), completionHandler: nil)
        }
    }

    private func findRunningApp(bundleIdentifiers: [String], nameHint: String) -> (app: NSRunningApplication?, bundleId: String?) {
        for bundleId in bundleIdentifiers {
            if let app = NSWorkspace.shared.runningApplications.first(where: {
                $0.bundleIdentifier == bundleId
            }) {
                return (app, bundleId)
            }
        }

        let app = NSWorkspace.shared.runningApplications.first(where: {
            $0.localizedName?.lowercased().contains(nameHint) == true
        })
        return (app, app?.bundleIdentifier)
    }

    private func discoverWindows(for app: NSRunningApplication, appKind: AppWindowKind) -> [CraftWindow] {
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        var windowsRef: CFTypeRef?

        let result = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef)

        guard result == .success, let windows = windowsRef as? [AXUIElement] else {
            return []
        }

        var discoveredWindows: [CraftWindow] = []

        for (index, windowElement) in windows.enumerated() {
            // Get window title
            var titleRef: CFTypeRef?
            AXUIElementCopyAttributeValue(windowElement, kAXTitleAttribute as CFString, &titleRef)
            let title = titleRef as? String ?? "Untitled"

            var windowId = index
            var windowNumberRef: CFTypeRef?
            let windowNumberKey = "AXWindowNumber" as CFString
            if AXUIElementCopyAttributeValue(
                windowElement,
                windowNumberKey,
                &windowNumberRef
            ) == .success, let windowNumber = windowNumberRef as? NSNumber {
                windowId = windowNumber.intValue
            }

            // Get window position
            var positionRef: CFTypeRef?
            AXUIElementCopyAttributeValue(windowElement, kAXPositionAttribute as CFString, &positionRef)
            var position = CGPoint.zero
            if let positionValue = positionRef {
                AXValueGetValue(positionValue as! AXValue, .cgPoint, &position)
            }

            // Get window size
            var sizeRef: CFTypeRef?
            AXUIElementCopyAttributeValue(windowElement, kAXSizeAttribute as CFString, &sizeRef)
            var size = CGSize.zero
            if let sizeValue = sizeRef {
                AXValueGetValue(sizeValue as! AXValue, .cgSize, &size)
            }

            // Skip minimized windows
            var minimizedRef: CFTypeRef?
            AXUIElementCopyAttributeValue(windowElement, kAXMinimizedAttribute as CFString, &minimizedRef)
            if let minimized = minimizedRef as? Bool, minimized {
                continue
            }

            // Skip windows with zero size (likely not real windows)
            if size.width < 10 || size.height < 10 {
                continue
            }

            let window = CraftWindow(
                id: windowId,
                title: title,
                axElement: windowElement,
                frame: NSRect(origin: position, size: size),
                appKind: appKind
            )
            discoveredWindows.append(window)
        }

        return discoveredWindows
    }

    // MARK: - Window Control

    private func runningApplication(for appKind: AppWindowKind) -> NSRunningApplication? {
        switch appKind {
        case .craft:
            return findRunningApp(bundleIdentifiers: craftBundleIdentifiers, nameHint: "craft").app
        case .iterm:
            return findRunningApp(bundleIdentifiers: itermBundleIdentifiers, nameHint: "iterm").app
        case .atlas:
            return findRunningApp(bundleIdentifiers: atlasBundleIdentifiers, nameHint: "chatgpt").app
        case .spotify:
            return findRunningApp(bundleIdentifiers: spotifyBundleIdentifiers, nameHint: "spotify").app
        case .weather:
            return findRunningApp(bundleIdentifiers: weatherBundleIdentifiers, nameHint: "weather").app
        }
    }

    func setWindowFrame(_ window: CraftWindow, to frame: NSRect) {
        guard hasPermission else { return }

        // Convert from AppKit coordinates (bottom-left origin) to AX coordinates (top-left origin)
        // AppKit: frame.origin.y is distance from bottom of screen to bottom of window
        // AX: position.y is distance from top of screen to top of window
        let screenHeight = NSScreen.main?.frame.height ?? 0
        let axY = screenHeight - frame.maxY  // frame.maxY = origin.y + height = top of window in AppKit

        // Set position (in AX coordinates)
        var position = CGPoint(x: frame.origin.x, y: axY)
        if let positionValue = AXValueCreate(.cgPoint, &position) {
            AXUIElementSetAttributeValue(window.axElement, kAXPositionAttribute as CFString, positionValue)
        }

        // Set size
        var size = CGSize(width: frame.width, height: frame.height)
        if let sizeValue = AXValueCreate(.cgSize, &size) {
            AXUIElementSetAttributeValue(window.axElement, kAXSizeAttribute as CFString, sizeValue)
        }
    }

    func activateWindow(_ window: CraftWindow) {
        guard hasPermission else { return }

        // First, raise and focus the specific window
        AXUIElementSetAttributeValue(window.axElement, kAXMainAttribute as CFString, kCFBooleanTrue)
        AXUIElementSetAttributeValue(window.axElement, kAXFocusedAttribute as CFString, kCFBooleanTrue)

        // Perform the raise action
        AXUIElementPerformAction(window.axElement, kAXRaiseAction as CFString)

        // Activate owning app and bring to front
        activateApp(for: window.appKind)
    }

    /// Raises a window to the front and activates Craft app
    func raiseWindow(_ window: CraftWindow) {
        guard hasPermission else { return }

        // Raise the window
        AXUIElementPerformAction(window.axElement, kAXRaiseAction as CFString)

        // Also activate owning app to ensure windows come to front
        activateApp(for: window.appKind)
    }

    private func activateApp(for appKind: AppWindowKind) {
        guard let app = runningApplication(for: appKind) else { return }
        if #available(macOS 14.0, *) {
            app.activate(options: [.activateAllWindows])
        } else {
            app.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
        }
    }

    func getWindowFrame(_ window: CraftWindow) -> NSRect? {
        guard hasPermission else { return nil }

        // Get window position (in AX coordinates - top-left origin)
        var positionRef: CFTypeRef?
        AXUIElementCopyAttributeValue(window.axElement, kAXPositionAttribute as CFString, &positionRef)
        var position = CGPoint.zero
        if let positionValue = positionRef {
            AXValueGetValue(positionValue as! AXValue, .cgPoint, &position)
        }

        // Get window size
        var sizeRef: CFTypeRef?
        AXUIElementCopyAttributeValue(window.axElement, kAXSizeAttribute as CFString, &sizeRef)
        var size = CGSize.zero
        if let sizeValue = sizeRef {
            AXValueGetValue(sizeValue as! AXValue, .cgSize, &size)
        }

        // Convert from AX coordinates (top-left origin) to AppKit coordinates (bottom-left origin)
        // AX: position.y is distance from top of screen to top of window
        // AppKit: origin.y is distance from bottom of screen to bottom of window
        let screenHeight = NSScreen.main?.frame.height ?? 0
        let appKitY = screenHeight - position.y - size.height

        return NSRect(x: position.x, y: appKitY, width: size.width, height: size.height)
    }

    // MARK: - Periodic Refresh

    func startRefreshing(interval: TimeInterval = 0.5) {
        stopRefreshing()
        refreshCraftWindows()
        refreshItermWindows()
        refreshAtlasWindows()
        refreshSpotifyWindows()
        refreshWeatherWindows()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.refreshCraftWindows()
            self?.refreshItermWindows()
            self?.refreshAtlasWindows()
            self?.refreshSpotifyWindows()
            self?.refreshWeatherWindows()
        }
    }

    func stopRefreshing() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
    
    // MARK: - Shortcut Simulation
    
    func simulateShortcut(_ shortcutString: String) {
        let components = shortcutString.lowercased().split(separator: "+")
        guard let keyChar = components.last else { return }
        
        var flags = CGEventFlags()
        if components.contains("cmd") || components.contains("command") { flags.insert(.maskCommand) }
        if components.contains("shift") { flags.insert(.maskShift) }
        if components.contains("opt") || components.contains("option") || components.contains("alt") { flags.insert(.maskAlternate) }
        if components.contains("ctrl") || components.contains("control") { flags.insert(.maskControl) }
        
        let keyCode = keyCodeForChar(String(keyChar))
        
        // Use combinedSessionState for better reliability with other apps
        guard let src = CGEventSource(stateID: .combinedSessionState) else { return }
        
        let keyDown = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: true)
        keyDown?.flags = flags
        keyDown?.post(tap: .cghidEventTap)
        
        let keyUp = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: false)
        keyUp?.flags = flags
        keyUp?.post(tap: .cghidEventTap)
    }
    
    private func keyCodeForChar(_ char: String) -> CGKeyCode {
        switch char {
        case "a": return 0x00
        case "s": return 0x01
        case "d": return 0x02
        case "f": return 0x03
        case "h": return 0x04
        case "g": return 0x05
        case "z": return 0x06
        case "x": return 0x07
        case "c": return 0x08
        case "v": return 0x09
        case "b": return 0x0B
        case "q": return 0x0C
        case "w": return 0x0D
        case "e": return 0x0E
        case "r": return 0x0F
        case "y": return 0x10
        case "t": return 0x11
        case "1": return 0x12
        case "2": return 0x13
        case "3": return 0x14
        case "4": return 0x15
        case "6": return 0x16
        case "5": return 0x17
        case "=": return 0x18
        case "9": return 0x19
        case "7": return 0x1A
        case "-": return 0x1B
        case "8": return 0x1C
        case "0": return 0x1D
        case "]": return 0x1E
        case "o": return 0x1F
        case "u": return 0x20
        case "[": return 0x21
        case "i": return 0x22
        case "p": return 0x23
        case "l": return 0x24
        case "j": return 0x26
        case "'": return 0x27
        case "k": return 0x28
        case ";": return 0x29
        case "\\": return 0x2A
        case ",": return 0x2B
        case "/": return 0x2C
        case "n": return 0x2D
        case "m": return 0x2E
        case ".": return 0x2F
        case "space": return 0x31
        case "return": return 0x24
        case "enter": return 0x24
        case "tab": return 0x30
        case "esc": return 0x35
        default: return 0
        }
    }
}
