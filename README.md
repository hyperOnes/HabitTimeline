# UNIVERSE

A native macOS app that keeps two Craft document windows snapped side-by-side with a fixed 2/3 (left) - 1/3 (right) split ratio.

## Features

- **Side-by-side Layout**: Automatically positions two Craft windows with 2/3 and 1/3 width split
- **Minimizable Right Panel**: Collapse the right panel to a thin stripe, giving the left window full width. Expand it back with a single click.
- **Window Management**: Move and resize the UNIVERSE frame, and both Craft windows follow
- **Snap-back**: If you accidentally drag a Craft window, it snaps back to its assigned position
- **Focus Routing**: Click anywhere in the left or right pane to focus that Craft window
- **Menubar Integration**: Quick access from the menubar with keyboard shortcuts
- **Dock Presence**: Full macOS app experience with dock icon

## Requirements

- macOS 14.0 (Sonoma) or later
- Craft app installed
- Accessibility permission granted

## Installation

1. Open `UNIVERSE.xcodeproj` in Xcode
2. Build and run (⌘R)
3. Grant Accessibility permission when prompted
   - If not prompted, go to System Preferences → Privacy & Security → Accessibility
   - Add UNIVERSE to the allowed apps

## Usage

1. **Open Craft**: Make sure you have at least 2 Craft document windows open
2. **Launch UNIVERSE**: The app will appear in both the dock and menubar
3. **Start Managing**: Click "Start Managing" in the main window or use the menubar
4. **Windows Auto-Position**: Your two Craft windows will snap into the 2/3 + 1/3 layout
5. **Resize the Frame**: Resize the UNIVERSE window to resize both Craft windows proportionally
6. **Move the Frame**: Move the UNIVERSE window to reposition both Craft windows
7. **Focus Craft Windows**: Click in the left or right area to focus that Craft window
8. **Minimize Right Panel**: Click the minimize button in the right panel (or use ⌘]) to collapse it to a stripe
9. **Expand Right Panel**: Click the stripe or the expand button to restore the 1/3 width

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| ⌘⇧M | Toggle managing on/off |
| ⌘] | Toggle right panel minimize/expand |
| ⌘⇧R | Reset layout |
| ⌘O | Open UNIVERSE window |
| ⌘Q | Quit |

## Architecture

```
UNIVERSE/
├── UniverseApp.swift          # App entry + menubar
├── ContentView.swift          # Main UI
├── FrameWindow/
│   ├── FrameWindowController.swift  # Frame window management
│   └── ClickThroughView.swift       # Focus routing
├── Managers/
│   ├── AccessibilityManager.swift   # AX API for window control
│   └── WindowLayoutManager.swift    # Position sync logic
└── Models/
    └── CraftWindow.swift            # Window data model
```

## How It Works

1. **Accessibility API**: Uses macOS Accessibility APIs (AXUIElement) to discover and control Craft windows
2. **Window Discovery**: Finds Craft windows by querying the running application with bundle ID `com.lukaland.craft`
3. **Position Sync**: When the UNIVERSE frame moves or resizes, it calculates new positions for both panes and applies them to the Craft windows
4. **Snap-back Logic**: Periodically checks if Craft windows have drifted from their target positions and snaps them back

## Permissions

UNIVERSE requires Accessibility permission to:
- Discover Craft windows
- Read window positions and sizes
- Move and resize windows programmatically

The app is non-sandboxed (required for Accessibility APIs) but does not access any user data or network resources.

## Troubleshooting

### "Need at least 2 Craft windows"
Open two separate Craft documents in their own windows (not tabs).

### Windows not responding
1. Check that Accessibility permission is granted
2. Restart UNIVERSE
3. Make sure Craft is the app with bundle ID `com.lukaland.craft`

### Windows fighting with user
The snap-back feature has a 20-pixel threshold and 0.3-second debounce to avoid conflicts with intentional user drags.

## License

MIT License
