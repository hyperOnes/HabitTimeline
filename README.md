# Habit Timeline

Habit Timeline is a native macOS menubar habit tracker built with SwiftUI. It shows your day as a compact timeline in the menu bar and expands into a popover where you can plan habits, track completion, watch daily usage trends, manage quick-launch buttons, and see a local weather strip.

## What It Does

- Menubar-first UI with a compact inline timeline and an expanded popover
- Draggable daily habit timeline with editable start and end times
- Habit completion tracking with rolling history graphs
- Hidden-habit bucket for parking habits without deleting them
- Initiative badges with editable labels, symbols, and target dates
- Quick-launch buttons for apps or simulated keyboard shortcuts
- Daily usage tracking with a 4 AM reset boundary
- Local weather forecast in the usage strip
- Persistent local storage in Application Support

## Current Product Scope

The current app is the menubar habit tracker described above.

This repository still contains some legacy Accessibility and Craft/app-window integration helpers, but the old two-pane Craft window organizer is not the main shipped experience and the previous README for that workflow was outdated.

## Requirements

- macOS 14.0 or later
- Xcode for building and running the app

## Installation

1. Open `UNIVERSE.xcodeproj` in Xcode.
2. Build and run the `UNIVERSE` scheme.
3. Allow location access if you want live weather in the widget.
4. Allow Accessibility access only if you want shortcut-based quick-launch actions or to experiment with the legacy window/app integration helpers.

## Usage

1. Launch the app from Xcode.
2. Click the menu bar item to open the expanded popover.
3. Add habits, drag them across the timeline, or resize them to adjust duration.
4. Click a habit to inspect its recent completion history in the usage graph.
5. Hide habits into the bucket when you want them off the main timeline without deleting them.
6. Edit initiatives and quick-launch buttons from the popover UI.

## Keyboard Shortcut

- `Ctrl+A`: Toggle the menubar popover

## Data Storage

The app stores its local data under Application Support in JSON files, including:

- habits
- habit history
- usage history
- initiatives
- quick-launch buttons
- the last successful weather coordinate cache

## Permissions

Habit Timeline may use these macOS permissions:

- Location: used to fetch a local weather forecast for the weather strip
- Accessibility: used for simulated keyboard shortcuts and legacy app/window integration helpers
- Microphone: declared in the app today, but the current menubar tracker flow does not prominently expose a microphone-driven feature

## Architecture

- `UNIVERSE/UniverseApp.swift`: app entry point and global shortcut handling
- `UNIVERSE/MenuBarWidget.swift`: status item, popover, and menubar interaction
- `UNIVERSE/ContentView.swift`: main timeline UI plus habit, initiative, usage, history, and weather models/managers
- `UNIVERSE/Managers/AccessibilityManager.swift`: Accessibility-based app/window helpers and shortcut simulation
- `UNIVERSE/Managers/WindowLayoutManager.swift`: current toolbar state manager
- `UNIVERSE/Views/NativeDividerView.swift`: native divider and quick-launch related UI code, including some legacy references

## Repository Notes

- The `UNIVERSE` target name is historical.
- Some legacy code paths still refer to Craft, graph mode, and external app window control.
- If you are evaluating the current app behavior, use the menubar timeline widget as the source of truth rather than the older Craft-oriented concepts.
