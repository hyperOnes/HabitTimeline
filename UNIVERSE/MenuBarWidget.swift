import SwiftUI
import AppKit
import Combine
import WebKit

enum MenuBarPanel {
    case left
    case right
}

enum MenuBarTab: String, CaseIterable {
    case earth = "EARTH"
}

enum MenuBarWidgetConstants {
    static let inlineWidth: CGFloat = 80
    static let inlineHeight: CGFloat = 28
    static let inlineTickerHeight: CGFloat = 16
    static let popoverWidth: CGFloat = 740
    static let popoverCornerRadius: CGFloat = 18
    static let popoverPadding: CGFloat = 8
    static let popoverSpacing: CGFloat = 6
    static let tabBarHeight: CGFloat = 32
    static let panelHeight: CGFloat = 730
    static let popoverOverlap: CGFloat = 24
    static let popoverYOffset: CGFloat = 16
    static let hoverOpenDelay: TimeInterval = 0.08
    static let hoverCloseDelay: TimeInterval = 0.35
    static let tabsEnabled = false
}

final class MenuBarWidgetState: ObservableObject {
    static let shared = MenuBarWidgetState()

    @Published var isPopoverShown = false
    @Published var activePanel: MenuBarPanel = .left
    @Published var activeTab: MenuBarTab = .earth
    @Published var isInlineHovering = false
    @Published var isPopoverHovering = false

    var onShowPopover: ((MenuBarPanel) -> Void)?
    var onTogglePopover: ((MenuBarPanel) -> Void)?
    var onClosePopover: (() -> Void)?

    private var closeWorkItem: DispatchWorkItem?
    private var openWorkItem: DispatchWorkItem?

    private init() {}

    func showPopover(panel: MenuBarPanel) {
        onShowPopover?(panel)
    }

    func togglePopover(panel: MenuBarPanel) {
        onTogglePopover?(panel)
    }

    func closePopover() {
        onClosePopover?()
    }

    func setInlineHovering(_ hovering: Bool) {
        isInlineHovering = hovering
        updateHoverState()
    }

    func setPopoverHovering(_ hovering: Bool) {
        isPopoverHovering = hovering
        updateHoverState()
    }

    private func updateHoverState() {
        if isInlineHovering || isPopoverHovering {
            closeWorkItem?.cancel()
            closeWorkItem = nil
            scheduleOpenIfNeeded()
        } else {
            openWorkItem?.cancel()
            openWorkItem = nil
            scheduleClose()
        }
    }

    private func scheduleOpenIfNeeded() {
        if isPopoverShown {
            return
        }
        openWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self, self.isInlineHovering || self.isPopoverHovering else { return }
            self.showPopover(panel: .left)
        }
        openWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + MenuBarWidgetConstants.hoverOpenDelay, execute: workItem)
    }

    private func scheduleClose() {
        closeWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.closePopover()
        }
        closeWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + MenuBarWidgetConstants.hoverCloseDelay, execute: workItem)
    }
}

final class MenuBarWidgetController: NSObject, NSPopoverDelegate {
    private let state: MenuBarWidgetState
    private let layoutManager: WindowLayoutManager
    private let statusItem: NSStatusItem
    private let popover: NSPopover
    private var cancellables = Set<AnyCancellable>()
    private var globalClickMonitor: Any?
    private var localClickMonitor: Any?

    init(state: MenuBarWidgetState, layoutManager: WindowLayoutManager) {
        self.state = state
        self.layoutManager = layoutManager
        self.statusItem = NSStatusBar.system.statusItem(withLength: MenuBarWidgetConstants.inlineWidth)
        self.popover = NSPopover()
        super.init()
        configureStatusItem()
        configurePopover()
        bindState()
    }

    deinit {
        removeOutsideClickMonitors()
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }
        button.title = ""
        button.image = nil
        button.isBordered = false
        button.target = self
        button.action = #selector(handleStatusItemClick)

        let hostingView = NSHostingView(rootView: MenuBarInlineView(widgetState: state))
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        button.addSubview(hostingView)

        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: button.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: button.bottomAnchor)
        ])
    }

    @objc private func handleStatusItemClick() {
        state.togglePopover(panel: .left)
    }

    private func configurePopover() {
        popover.behavior = .semitransient
        popover.animates = true
        popover.delegate = self
        if popover.responds(to: Selector(("setShouldHideArrow:"))) {
            popover.setValue(true, forKey: "shouldHideArrow")
        }
        if popover.responds(to: Selector(("setShouldHideAnchor:"))) {
            popover.setValue(true, forKey: "shouldHideAnchor")
        }
        popover.contentViewController = NSHostingController(
            rootView: MenuBarPopoverView(widgetState: state)
                .environmentObject(layoutManager)
        )
        updatePopoverSize()
    }

    private func bindState() {
        state.onShowPopover = { [weak self] panel in
            self?.showPopover(panel: panel)
        }
        state.onTogglePopover = { [weak self] panel in
            self?.togglePopover(panel: panel)
        }
        state.onClosePopover = { [weak self] in
            self?.closePopover()
        }
    }

    private func updatePopoverSize() {
        var height = MenuBarWidgetConstants.popoverPadding * 2
            + UniverseTheme.controlStripHeight

        if MenuBarWidgetConstants.tabsEnabled {
            height += MenuBarWidgetConstants.popoverSpacing
            height += MenuBarWidgetConstants.tabBarHeight
            height += MenuBarWidgetConstants.popoverSpacing
            height += MenuBarWidgetConstants.panelHeight
        }
        applyPopoverSize(NSSize(width: MenuBarWidgetConstants.popoverWidth, height: height))
    }

    private func showPopover(panel: MenuBarPanel) {
        guard let button = statusItem.button else { return }
        state.activePanel = panel
        if popover.isShown {
            return
        }
        updatePopoverSize()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .maxY)
        state.isPopoverShown = true
        if popover.responds(to: Selector(("setShouldHideArrow:"))) {
            popover.setValue(true, forKey: "shouldHideArrow")
        }
        if popover.responds(to: Selector(("setShouldHideAnchor:"))) {
            popover.setValue(true, forKey: "shouldHideAnchor")
        }
        applyPopoverOverlap()
        installOutsideClickMonitors()
    }

    private func applyPopoverOverlap() {
        guard let button = statusItem.button,
              let buttonWindow = button.window,
              let popoverWindow = popover.contentViewController?.view.window else { return }
        let buttonRect = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
        var frame = popoverWindow.frame
        frame.size = popover.contentSize
        frame.origin.y = buttonRect.minY - frame.height + MenuBarWidgetConstants.popoverOverlap - MenuBarWidgetConstants.popoverYOffset
        popoverWindow.setFrame(frame, display: true)
    }

    private func applyPopoverSize(_ size: NSSize) {
        popover.contentSize = size
        popover.contentViewController?.preferredContentSize = size
        if popover.isShown {
            applyPopoverOverlap()
        }
    }

    private func togglePopover(panel: MenuBarPanel) {
        if popover.isShown {
            if state.activePanel == panel {
                closePopover()
            } else {
                state.activePanel = panel
            }
        } else {
            showPopover(panel: panel)
        }
    }

    private func closePopover() {
        popover.performClose(nil)
        state.isPopoverShown = false
        removeOutsideClickMonitors()
    }

    func popoverDidClose(_ notification: Notification) {
        state.isPopoverShown = false
        state.isPopoverHovering = false
        removeOutsideClickMonitors()
    }

    private func installOutsideClickMonitors() {
        guard globalClickMonitor == nil && localClickMonitor == nil else { return }
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            self?.handleOutsideClick(event)
        }
        localClickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            self?.handleOutsideClick(event)
            return event
        }
    }

    private func removeOutsideClickMonitors() {
        if let monitor = globalClickMonitor {
            NSEvent.removeMonitor(monitor)
            globalClickMonitor = nil
        }
        if let monitor = localClickMonitor {
            NSEvent.removeMonitor(monitor)
            localClickMonitor = nil
        }
    }

    private func handleOutsideClick(_ event: NSEvent) {
        guard popover.isShown,
              let popoverWindow = popover.contentViewController?.view.window else { return }
        let screenLocation = eventLocationOnScreen(event)
        if !popoverWindow.frame.contains(screenLocation) {
            if Thread.isMainThread {
                closePopover()
            } else {
                DispatchQueue.main.async { [weak self] in
                    self?.closePopover()
                }
            }
        }
    }

    private func eventLocationOnScreen(_ event: NSEvent) -> NSPoint {
        if let window = event.window {
            let point = event.locationInWindow
            return window.convertToScreen(NSRect(origin: point, size: .zero)).origin
        }
        return NSEvent.mouseLocation
    }
}

struct MenuBarInlineView: View {
    @ObservedObject var widgetState: MenuBarWidgetState
    @ObservedObject var habitManager = DailyHabitManager.shared

    var body: some View {
        let start = habitManager.timelineStartMinutes
        let end = DailyHabitManager.timelineEndMinutes
        let mid = (start + end) / 2

        ZStack {
            // Timeline layers with spaceman marker
            VStack(spacing: 0) {
                DailyTimeline(style: .menubarInline, customRange: (start: start, end: mid))
                    .frame(height: 28)
                DailyTimeline(style: .menubarInline, customRange: (start: mid, end: end))
                    .frame(height: 28)
            }
            .frame(width: 160, height: 56)
            .scaleEffect(0.5)
            .frame(width: 80, height: 28)
        }
        .frame(width: MenuBarWidgetConstants.inlineWidth, height: MenuBarWidgetConstants.inlineHeight)
        .background(Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            widgetState.togglePopover(panel: .left)
        }
    }
}



struct MenuBarPopoverView: View {
    @ObservedObject var widgetState: MenuBarWidgetState

    var body: some View {
        VStack(spacing: MenuBarWidgetConstants.popoverSpacing) {
            ControlStripContent(timelineStyle: .menubarExpanded)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .frame(height: UniverseTheme.controlStripHeight)
                .background(LiquidGlassBackground(cornerRadius: 14).opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.14), lineWidth: 0.6)
                )

            if MenuBarWidgetConstants.tabsEnabled {
                TabBarView(activeTab: $widgetState.activeTab)
                    .frame(height: MenuBarWidgetConstants.tabBarHeight)

                tabContent
                    .frame(height: MenuBarWidgetConstants.panelHeight)
            }
        }
        .padding(.horizontal, MenuBarWidgetConstants.popoverPadding)
        .padding(.vertical, MenuBarWidgetConstants.popoverPadding)
        .frame(width: MenuBarWidgetConstants.popoverWidth)
        .background(MidnightPopoverBackground(cornerRadius: MenuBarWidgetConstants.popoverCornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: MenuBarWidgetConstants.popoverCornerRadius)
                .stroke(Color.white.opacity(0.16), lineWidth: 0.8)
        )
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var tabContent: some View {
        switch widgetState.activeTab {
        case .earth:
            EarthPanel()
        }
    }
}

struct TabBarView: View {
    @Binding var activeTab: MenuBarTab

    var body: some View {
        HStack(spacing: 4) {
            ForEach(MenuBarTab.allCases, id: \.self) { tab in
                TabButton(
                    title: tab.rawValue,
                    isActive: activeTab == tab,
                    action: { activeTab = tab }
                )
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 4)
        .background(LiquidGlassBackground(cornerRadius: 10).opacity(0.12))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
        )
    }
}

struct TabButton: View {
    let title: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: isActive ? .bold : .semibold, design: .monospaced))
            .foregroundColor(isActive ? Color.white : Color.white.opacity(0.5))
            .frame(maxWidth: .infinity)
            .frame(height: 24)
            .background(
                Group {
                    if isActive {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.white.opacity(0.15))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                            )
                    } else {
                        Color.clear
                    }
                }
            )
            .contentShape(Rectangle())
            .onTapGesture {
                action()
            }
    }
}

struct EarthPanel: View {
    private let url = URL(string: "https://earthdata.nasa.gov")!

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.015, green: 0.02, blue: 0.06).opacity(0.95),
                            Color(red: 0.01, green: 0.015, blue: 0.05).opacity(0.75),
                            Color(red: 0.02, green: 0.03, blue: 0.08).opacity(0.8)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.05),
                            Color.clear,
                            Color.black.opacity(0.35)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                )

            EarthWebView(url: url)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.12), lineWidth: 0.8)
        )
    }
}

private struct EarthWebView: NSViewRepresentable {
    let url: URL
    private let cornerRadius: CGFloat = 14

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        let container = NSView()
        container.wantsLayer = true
        container.layer?.masksToBounds = true
        container.layer?.cornerRadius = cornerRadius

        let webView = makeWebView(context: context)
        webView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(webView)

        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            webView.topAnchor.constraint(equalTo: container.topAnchor),
            webView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        context.coordinator.webView = webView
        return container
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let webView = context.coordinator.webView else { return }
        if webView.url != url {
            webView.load(URLRequest(url: url))
        }
    }

    private func makeWebView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.setValue(false, forKey: "drawsBackground")
        webView.load(URLRequest(url: url))
        return webView
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        weak var webView: WKWebView?
    }
}

struct LiquidGlassBackground: View {
    var cornerRadius: CGFloat = 0

    var body: some View {
        ZStack {
            GlassBackground(material: .hudWindow, blendingMode: .behindWindow)

            LinearGradient(
                colors: [
                    Color.white.opacity(0.2),
                    Color.white.opacity(0.05),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            LinearGradient(
                colors: [
                    Color.white.opacity(0.08),
                    Color.clear,
                    Color.white.opacity(0.04)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

struct MidnightPopoverBackground: View {
    var cornerRadius: CGFloat = 0

    var body: some View {
        ZStack {
            GlassBackground(material: .hudWindow, blendingMode: .behindWindow)

            LinearGradient(
                colors: [
                    Color(red: 0.02, green: 0.025, blue: 0.08).opacity(0.88),
                    Color(red: 0.01, green: 0.015, blue: 0.05).opacity(0.82),
                    Color(red: 0.015, green: 0.02, blue: 0.06).opacity(0.86)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            LinearGradient(
                colors: [
                    Color.white.opacity(0.06),
                    Color.clear,
                    Color.black.opacity(0.45)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            Color.black.opacity(0.15)
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .blur(radius: 0.6)
    }
}
