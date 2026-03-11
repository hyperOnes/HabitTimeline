import Cocoa
import SwiftUI

/// Native NSView divider that captures mouse events without requiring window focus
class NativeDividerView: NSView {
    private let layoutManager = WindowLayoutManager.shared
    private let quickLaunchManager = QuickLaunchManager.shared

    private var trackingArea: NSTrackingArea?
    private var isHovering = false
    private var isDragging = false
    private var dragStartX: CGFloat = 0
    private var dragStartRatio: CGFloat = 0.5

    // UI Elements
    private var handleLayer: CALayer?
    private var buttonStackView: NSStackView?
    private var hoverBackgroundLayer: CALayer?

    private let handleWidth: CGFloat = 8
    private let handleHeight: CGFloat = 200

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor

        // Create hover background layer
        hoverBackgroundLayer = CALayer()
        hoverBackgroundLayer?.backgroundColor = NSColor.white.withAlphaComponent(0.02).cgColor
        hoverBackgroundLayer?.cornerRadius = 8
        layer?.addSublayer(hoverBackgroundLayer!)

        // Create handle layer
        handleLayer = CALayer()
        handleLayer?.backgroundColor = NSColor.white.withAlphaComponent(0.35).cgColor
        handleLayer?.cornerRadius = 4
        handleLayer?.shadowColor = NSColor.white.cgColor
        handleLayer?.shadowOpacity = 0.15
        handleLayer?.shadowRadius = 6
        handleLayer?.shadowOffset = .zero
        layer?.addSublayer(handleLayer!)

        // Add grip lines to handle
        for i in 0..<7 {
            let gripLine = CALayer()
            gripLine.backgroundColor = NSColor.white.withAlphaComponent(0.5).cgColor
            gripLine.cornerRadius = 1
            gripLine.frame = CGRect(x: 2, y: CGFloat(i) * 7 + 80, width: 4, height: 2)
            handleLayer?.addSublayer(gripLine)
        }

        // Create button stack
        setupButtonStack()

        updateTrackingArea()

        // Listen for rebuild notification
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(rebuildButtons),
            name: NSNotification.Name("RebuildDividerButtons"),
            object: nil
        )
    }

    @objc private func rebuildButtons() {
        setupButtonStack()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func setupButtonStack() {
        // Remove old container
        if let oldContainer = subviews.first(where: { $0.identifier?.rawValue == "buttonContainer" }) {
            oldContainer.removeFromSuperview()
        }
        buttonStackView?.removeFromSuperview()

        let stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.spacing = 6
        stackView.alignment = .centerX
        stackView.translatesAutoresizingMaskIntoConstraints = false

        // Control buttons row (FRONT, SWAP, GRAPH)
        let controlRow = NSStackView()
        controlRow.orientation = .horizontal
        controlRow.spacing = 4
        controlRow.alignment = .centerY

        let frontBtn = DividerControlButton(title: "⧉", tooltip: "Bring to Front") { [weak self] in
            self?.layoutManager.bringWindowsToFront()
        }
        let swapBtn = DividerControlButton(title: "⇄", tooltip: "Swap Windows") { [weak self] in
            self?.layoutManager.swapWindows()
        }
        let graphBtn = DividerControlButton(title: "▦", tooltip: "Toggle Graph", isActiveCheck: { [weak self] in
            self?.layoutManager.isGraphMode ?? false
        }) { [weak self] in
            self?.layoutManager.toggleGraphMode()
        }

        controlRow.addArrangedSubview(frontBtn)
        controlRow.addArrangedSubview(swapBtn)
        controlRow.addArrangedSubview(graphBtn)
        stackView.addArrangedSubview(controlRow)

        // Separator
        let separator = NSBox()
        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.widthAnchor.constraint(equalToConstant: 30).isActive = true
        stackView.addArrangedSubview(separator)

        // Panel toggle buttons (BAR, PNL)
        let panelRow = NSStackView()
        panelRow.orientation = .horizontal
        panelRow.spacing = 4
        panelRow.alignment = .centerY

        let barBtn = DividerControlButton(title: "▼", tooltip: "Toggle Toolbar", isActiveCheck: { [weak self] in
            self?.layoutManager.isToolbarMinimized ?? false
        }) { [weak self] in
            self?.layoutManager.toggleToolbar()
        }
        let pnlBtn = DividerControlButton(title: "▶", tooltip: "Toggle Panel", isActiveCheck: { [weak self] in
            self?.layoutManager.isRightPanelMinimized ?? false
        }) { [weak self] in
            self?.layoutManager.toggleRightPanel()
        }

        panelRow.addArrangedSubview(barBtn)
        panelRow.addArrangedSubview(pnlBtn)
        stackView.addArrangedSubview(panelRow)

        // Another separator
        let separator2 = NSBox()
        separator2.boxType = .separator
        separator2.translatesAutoresizingMaskIntoConstraints = false
        separator2.widthAnchor.constraint(equalToConstant: 30).isActive = true
        stackView.addArrangedSubview(separator2)

        // Quick launch buttons (editable)
        for button in quickLaunchManager.buttons {
            let btn = DividerModeButton(button: button, layoutManager: layoutManager, quickLaunchManager: quickLaunchManager)
            stackView.addArrangedSubview(btn)
        }

        // Add button
        let addBtn = DividerControlButton(title: "+", tooltip: "Add Button") { [weak self] in
            self?.quickLaunchManager.addButton(name: "NEW", icon: "★", appBundleId: "")
            self?.setupButtonStack() // Rebuild stack
        }
        stackView.addArrangedSubview(addBtn)

        // Container with background
        let container = NSView()
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.7).cgColor
        container.layer?.cornerRadius = 12
        container.layer?.borderWidth = 1
        container.layer?.borderColor = NSColor.white.withAlphaComponent(0.3).cgColor
        container.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(stackView)
        addSubview(container)

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: container.topAnchor, constant: 10),
            stackView.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -10),
            stackView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
            stackView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8),

            container.centerXAnchor.constraint(equalTo: centerXAnchor),
            container.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -30)
        ])

        container.isHidden = true
        container.alphaValue = 0
        buttonStackView = stackView

        // Store reference to container for show/hide
        container.identifier = NSUserInterfaceItemIdentifier("buttonContainer")
    }

    override func layout() {
        super.layout()

        // Position hover background
        hoverBackgroundLayer?.frame = bounds.insetBy(dx: 2, dy: 0)

        // Position handle in center
        let handleX = (bounds.width - handleWidth) / 2
        let handleY = (bounds.height - handleHeight) / 2
        handleLayer?.frame = CGRect(x: handleX, y: handleY, width: handleWidth, height: handleHeight)

        // Reposition grip lines
        if let sublayers = handleLayer?.sublayers {
            let startY = (handleHeight - CGFloat(sublayers.count) * 7) / 2
            for (i, layer) in sublayers.enumerated() {
                layer.frame = CGRect(x: 2, y: startY + CGFloat(i) * 7, width: 4, height: 2)
            }
        }
    }

    // MARK: - Tracking Area

    private func updateTrackingArea() {
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }

        trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea!)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        updateTrackingArea()
    }

    // MARK: - Mouse Events

    override func mouseEntered(with event: NSEvent) {
        isHovering = true
        updateAppearance()
        NSCursor.resizeLeftRight.push()

        // CRITICAL: Bring Universe window to front so divider is clickable
        // This temporarily elevates the window above managed windows
        window?.level = .floating
        window?.makeKeyAndOrderFront(nil)
    }

    override func mouseExited(with event: NSEvent) {
        if !isDragging {
            isHovering = false
            updateAppearance()
            NSCursor.pop()

            // Return window to normal level
            window?.level = .normal
        }
    }

    override func mouseDown(with event: NSEvent) {
        isDragging = true
        dragStartX = event.locationInWindow.x
        dragStartRatio = layoutManager.splitRatio
        updateAppearance()

        // Keep window floating during drag
        window?.level = .floating
        window?.makeKeyAndOrderFront(nil)
    }

    override func mouseDragged(with event: NSEvent) {
        guard isDragging, let window = window else { return }

        let currentX = event.locationInWindow.x
        let deltaX = currentX - dragStartX
        let containerWidth = window.frame.width

        // Calculate new ratio
        let deltaRatio = deltaX / containerWidth
        var newRatio = dragStartRatio + deltaRatio

        // Clamp to valid range
        newRatio = max(0.2, min(0.8, newRatio))

        layoutManager.updateSplitRatio(newRatio)
    }

    override func mouseUp(with event: NSEvent) {
        isDragging = false

        if !isHovering {
            NSCursor.pop()
            // Return window to normal level when not hovering
            window?.level = .normal
        }

        updateAppearance()
    }

    // MARK: - Appearance

    private func updateAppearance() {
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.2)

        // Update hover background
        hoverBackgroundLayer?.backgroundColor = (isHovering || isDragging)
            ? NSColor.white.withAlphaComponent(0.06).cgColor
            : NSColor.white.withAlphaComponent(0.015).cgColor

        // Update handle
        handleLayer?.backgroundColor = (isHovering || isDragging)
            ? NSColor.white.withAlphaComponent(0.7).cgColor
            : NSColor.white.withAlphaComponent(0.35).cgColor

        handleLayer?.shadowOpacity = (isHovering || isDragging) ? 0.5 : 0.15

        CATransaction.commit()

        // Show/hide button container
        if let container = subviews.first(where: { $0.identifier?.rawValue == "buttonContainer" }) {
            let shouldShow = isHovering || isDragging
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                container.animator().isHidden = !shouldShow
                container.animator().alphaValue = shouldShow ? 1 : 0
            }

            // Keep window at floating level while buttons are visible
            if shouldShow {
                window?.level = .floating
            }
        }
    }

    // MARK: - Hit Testing

    override func hitTest(_ point: NSPoint) -> NSView? {
        // Convert point to local coordinates
        let localPoint = convert(point, from: superview)

        // Check if point is within bounds
        guard bounds.contains(localPoint) else {
            return nil
        }

        // Check if clicking on a button - only buttons should intercept, not the container
        if let container = subviews.first(where: { $0.identifier?.rawValue == "buttonContainer" }),
           !container.isHidden,
           container.alphaValue > 0.5 {
            let containerPoint = container.convert(localPoint, from: self)
            // Only check for button hits, not the container itself
            if let button = findButton(in: container, at: containerPoint) {
                return button
            }
        }

        // If no button was hit, return self for drag handling
        // This allows dragging to resize even when the container is visible
        return self
    }

    private func findButton(in view: NSView, at point: NSPoint) -> NSButton? {
        // Check subviews in reverse order (front to back)
        for subview in view.subviews.reversed() {
            let subviewPoint = subview.convert(point, from: view)
            if subview.frame.contains(point) {
                // If it's a button, return it
                if let button = subview as? NSButton {
                    return button
                }
                // Otherwise, recurse into stack views etc.
                if let button = findButton(in: subview, at: subviewPoint) {
                    return button
                }
            }
        }
        return nil
    }

    override var acceptsFirstResponder: Bool { true }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        // Accept first mouse to allow interaction without focusing window first
        return true
    }

    override var mouseDownCanMoveWindow: Bool { false }
}

// MARK: - Divider Control Button (for FRONT, SWAP, etc.)

class DividerControlButton: NSButton {
    private var action_handler: () -> Void
    private var isActiveCheck: (() -> Bool)?
    private var trackingArea: NSTrackingArea?
    private var isHoveringButton = false

    init(title: String, tooltip: String, isActiveCheck: (() -> Bool)? = nil, action: @escaping () -> Void) {
        self.action_handler = action
        self.isActiveCheck = isActiveCheck
        super.init(frame: NSRect(x: 0, y: 0, width: 24, height: 24))

        self.title = title
        self.toolTip = tooltip
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        font = NSFont.systemFont(ofSize: 12)
        isBordered = false
        wantsLayer = true
        layer?.cornerRadius = 4
        layer?.borderWidth = 1

        target = self
        action = #selector(buttonClicked)

        updateAppearance()
        setupTrackingArea()
    }

    private func setupTrackingArea() {
        trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea!)
    }

    override func mouseEntered(with event: NSEvent) {
        isHoveringButton = true
        updateAppearance()
    }

    override func mouseExited(with event: NSEvent) {
        isHoveringButton = false
        updateAppearance()
    }

    private func updateAppearance() {
        let active = isActiveCheck?() ?? false

        let textColor: NSColor = active ? .white : .white.withAlphaComponent(isHoveringButton ? 0.95 : 0.7)
        attributedTitle = NSAttributedString(
            string: title,
            attributes: [
                .foregroundColor: textColor,
                .font: NSFont.systemFont(ofSize: 12)
            ]
        )

        layer?.backgroundColor = active
            ? NSColor.white.withAlphaComponent(0.25).cgColor
            : NSColor.white.withAlphaComponent(isHoveringButton ? 0.1 : 0).cgColor

        layer?.borderColor = active
            ? NSColor.white.withAlphaComponent(0.6).cgColor
            : NSColor.white.withAlphaComponent(isHoveringButton ? 0.4 : 0.2).cgColor
    }

    @objc private func buttonClicked() {
        action_handler()
        updateAppearance()
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }
}

// MARK: - Divider Mode Button (Quick Launch with editing)

class DividerModeButton: NSButton {
    private let quickLaunchButton: QuickLaunchButton
    private weak var layoutManager: WindowLayoutManager?
    private weak var quickLaunchManager: QuickLaunchManager?
    private var trackingArea: NSTrackingArea?
    private var isHoveringButton = false

    init(button: QuickLaunchButton, layoutManager: WindowLayoutManager, quickLaunchManager: QuickLaunchManager? = nil) {
        self.quickLaunchButton = button
        self.layoutManager = layoutManager
        self.quickLaunchManager = quickLaunchManager
        super.init(frame: NSRect(x: 0, y: 0, width: 28, height: 28))
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        title = quickLaunchButton.icon
        font = NSFont.systemFont(ofSize: 14)
        isBordered = false
        wantsLayer = true

        layer?.cornerRadius = 6
        layer?.borderWidth = 1

        target = self
        action = #selector(buttonClicked)

        toolTip = "\(quickLaunchButton.name) (Right-click to edit)"

        // Setup right-click menu
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Edit \(quickLaunchButton.name)...", action: #selector(editButton), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Delete", action: #selector(deleteButton), keyEquivalent: ""))
        self.menu = menu

        updateAppearance()
        setupTrackingArea()
    }

    @objc private func editButton() {
        // Post notification to show edit sheet in SwiftUI
        NotificationCenter.default.post(
            name: NSNotification.Name("EditQuickLaunchButton"),
            object: quickLaunchButton
        )
    }

    @objc private func deleteButton() {
        quickLaunchManager?.deleteButton(quickLaunchButton)
        // Notify to rebuild the button stack
        NotificationCenter.default.post(name: NSNotification.Name("RebuildDividerButtons"), object: nil)
    }

    private func setupTrackingArea() {
        trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea!)
    }

    override func mouseEntered(with event: NSEvent) {
        isHoveringButton = true
        updateAppearance()
    }

    override func mouseExited(with event: NSEvent) {
        isHoveringButton = false
        updateAppearance()
    }

    override func rightMouseDown(with event: NSEvent) {
        if let menu = self.menu {
            NSMenu.popUpContextMenu(menu, with: event, for: self)
        }
    }

    private func updateAppearance() {
        // No permanent active state - just hover effects
        let textColor: NSColor = .white.withAlphaComponent(isHoveringButton ? 0.95 : 0.7)
        attributedTitle = NSAttributedString(
            string: quickLaunchButton.icon,
            attributes: [
                .foregroundColor: textColor,
                .font: NSFont.systemFont(ofSize: 14)
            ]
        )

        // Background - only on hover
        layer?.backgroundColor = NSColor.white.withAlphaComponent(isHoveringButton ? 0.15 : 0).cgColor

        // Border
        layer?.borderColor = NSColor.white.withAlphaComponent(isHoveringButton ? 0.4 : 0.2).cgColor
    }

    @objc private func buttonClicked() {
        guard let lm = layoutManager else { return }

        // Use non-toggle methods - just open the app in right panel
        switch quickLaunchButton.name.uppercased() {
        case "CRAFT":
            lm.activateCraftMode()
        case "DEV":
            lm.openDev()
        case "WEB":
            lm.openWeb()
        case "MUSIC":
            lm.openMusic()
        default:
            // Try to open the app
            if !quickLaunchButton.appBundleId.isEmpty {
                if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: quickLaunchButton.appBundleId) {
                    NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
                }
            }
        }

        updateAppearance()
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }
}

// MARK: - SwiftUI Wrapper

struct NativeDivider: NSViewRepresentable {
    func makeNSView(context: Context) -> NativeDividerView {
        let view = NativeDividerView()
        return view
    }

    func updateNSView(_ nsView: NativeDividerView, context: Context) {
        // Updates handled internally
    }
}
