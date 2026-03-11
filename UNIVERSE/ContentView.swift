import SwiftUI
import AppKit
import SceneKit
import CoreLocation

// MARK: - Theme Constants

enum UniverseTheme {
    static let background = Color.black
    static let controlStripHeight: CGFloat = 72
    static let accent = Color.white
    static let accentDim = Color.white.opacity(0.2)
    static let textPrimary = Color(red: 0.9, green: 0.9, blue: 0.9)
    static let textSecondary = Color(red: 0.5, green: 0.5, blue: 0.5)
    static let border = Color(red: 0.2, green: 0.2, blue: 0.2)
    static let panelBackground = Color(red: 0.05, green: 0.05, blue: 0.05)

    static let monoFont = Font.system(.caption, design: .monospaced)
    static let monoFontSmall = Font.system(.caption2, design: .monospaced)
    static let monoFontLarge = Font.system(.body, design: .monospaced)
}

// MARK: - Main Window View

struct MainWindowView: View {
    @EnvironmentObject var layoutManager: WindowLayoutManager

    var body: some View {
        VStack(spacing: 0) {
            // Spacer to push toolbar to bottom
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(false)

            // Bottom: Control strip (toolbar only)
            if layoutManager.isToolbarMinimized {
                ToolbarStripe()
                    .frame(height: 24)
            } else {
                ControlStrip()
                    .frame(height: UniverseTheme.controlStripHeight)
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Toolbar Stripe (Minimized)

struct ToolbarStripe: View {
    @EnvironmentObject var layoutManager: WindowLayoutManager
    @State private var isHovering = false

    var body: some View {
        ZStack(alignment: .bottom) {
            if isHovering {
                // Full toolbar when hovering - same height as expanded, anchored to bottom
                VStack(spacing: 0) {
                    ControlStripContent()
                        .frame(height: UniverseTheme.controlStripHeight - 24)

                    // Bottom stripe with collapse button
                    HStack {
                        Spacer()
                        Button(action: { layoutManager.toggleToolbar() }) {
                            Image(systemName: "chevron.up")
                                .font(.system(size: 10))
                                .foregroundColor(UniverseTheme.accent)
                                .frame(width: 40, height: 24)
                                .background(Color.white.opacity(0.15))
                        }
                        .buttonStyle(.plain)
                        Spacer()
                    }
                    .frame(height: 24)
                }
                .frame(height: UniverseTheme.controlStripHeight)
                .background(ThickGlassBackground())
                .contentShape(Rectangle())
                .onHover { hovering in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isHovering = hovering
                    }
                }
                .transition(.opacity)
            } else {
                // Collapsed stripe - just the thin bar
                HStack {
                    Spacer()
                    Button(action: { layoutManager.toggleToolbar() }) {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 10))
                            .foregroundColor(UniverseTheme.accent)
                            .frame(width: 40, height: 24)
                            .background(Color.white.opacity(0.05))
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
                .frame(height: 24)
                .background(ThickGlassBackground())
                .contentShape(Rectangle())
                .onHover { hovering in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isHovering = hovering
                    }
                }
            }
        }
        .frame(height: isHovering ? UniverseTheme.controlStripHeight : 24)
        .animation(.easeInOut(duration: 0.2), value: isHovering)
        .zIndex(100)
    }
}

// MARK: - Control Strip Content (Reusable for hover overlay)

struct ControlStripContent: View {
    @EnvironmentObject var layoutManager: WindowLayoutManager
    var timelineStyle: TimelineStyle = .standard

    var body: some View {
        HStack(spacing: 0) {
            // Left Column: Header + Timeline
            VStack(spacing: 0) {
                UniverseHeader()
                    .frame(height: 14)
                
                DailyTimeline(style: timelineStyle)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity)

            // Right Column: Usage (Full height)
            UsageStrip()
                .frame(width: 180)
                .frame(maxHeight: .infinity)
        }
    }
}

// MARK: - Universe Header (horizontal bar above timeline)

struct UniverseHeader: View {
    @ObservedObject var habitManager = DailyHabitManager.shared

    var body: some View {
        HStack(spacing: 6) {
            // INITIATIVES (compact, shows ~2 items then scrolls)
            InitiativesStrip()
                .layoutPriority(-1) // Lower priority, can shrink

            // Hidden habits bucket (next to initiatives)
            HiddenHabitsBucket(habitManager: habitManager)

            Spacer(minLength: 6)

            // Identity badge (editable)
            ToolbarIdentityField()
        }
        .padding(.leading, 5)  // Align with timeline start time buttons
        .padding(.trailing, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(maxHeight: .infinity)
    }
}

// MARK: - Glass Background

struct GlassBackground: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .hudWindow
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

// MARK: - Thick 3D Glass Background

struct ThickGlassBackground: View {
    var cornerRadius: CGFloat = 0

    var body: some View {
        ZStack {
            // Base blur layer
            GlassBackground(material: .hudWindow, blendingMode: .behindWindow)

            // Multiple glass layers for depth
            LinearGradient(
                colors: [
                    Color.white.opacity(0.15),
                    Color.white.opacity(0.05),
                    Color.clear,
                    Color.black.opacity(0.1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // Subtle specular highlight
            VStack {
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.2),
                        Color.white.opacity(0.05),
                        Color.clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 20)
                Spacer()
            }

            // Dark tint for contrast
            Color.black.opacity(0.25)
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

// MARK: - Control Strip

struct ControlStrip: View {
    @EnvironmentObject var layoutManager: WindowLayoutManager

    var body: some View {
        VStack(spacing: 0) {
            ControlStripContent()
                .padding(.vertical, 8)
                .padding(.horizontal, 10)
        }
        .frame(width: 720)
        .background(ThickGlassBackground(cornerRadius: 18))
    }
}

extension View {
    func glassGlow(radius: CGFloat = 8, opacity: Double = 0.4) -> some View {
        self.shadow(color: Color.white.opacity(opacity), radius: radius, x: 0, y: 0)
    }
}

// MARK: - Daily Habit Manager

struct DailyHabit: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var detail: String
    var isCompleted: Bool
    var isHidden: Bool    // Hidden in the "bucket"
    var startMinutes: Int // Start time in minutes from midnight
    var endMinutes: Int   // End time in minutes from midnight
    var customWidth: CGFloat? // Custom display width (nil = auto-fit to text)
    var colorIndex: Int? // Manual color assignment for graph

    // Computed property for backward compatibility and midpoint
    var scheduledMinutes: Int {
        get { (startMinutes + endMinutes) / 2 }
    }

    var durationMinutes: Int {
        get { endMinutes - startMinutes }
    }

    init(
        id: UUID = UUID(),
        name: String,
        detail: String = "",
        isCompleted: Bool = false,
        isHidden: Bool = false,
        startMinutes: Int = 720,
        endMinutes: Int = 780,
        customWidth: CGFloat? = nil,
        colorIndex: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.detail = detail
        self.isCompleted = isCompleted
        self.isHidden = isHidden
        self.startMinutes = startMinutes
        self.endMinutes = max(startMinutes + 15, endMinutes) // Minimum 15 min duration
        self.customWidth = customWidth
        self.colorIndex = colorIndex
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case detail
        case isCompleted
        case isHidden
        case startMinutes
        case endMinutes
        case scheduledMinutes // For backward compatibility
        case customWidth
        case colorIndex
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        detail = try container.decodeIfPresent(String.self, forKey: .detail) ?? ""
        isCompleted = try container.decodeIfPresent(Bool.self, forKey: .isCompleted) ?? false
        isHidden = try container.decodeIfPresent(Bool.self, forKey: .isHidden) ?? false
        customWidth = try container.decodeIfPresent(CGFloat.self, forKey: .customWidth)
        colorIndex = try container.decodeIfPresent(Int.self, forKey: .colorIndex)

        // Try new format first, fall back to legacy
        if let start = try container.decodeIfPresent(Int.self, forKey: .startMinutes),
           let end = try container.decodeIfPresent(Int.self, forKey: .endMinutes) {
            startMinutes = start
            endMinutes = end
        } else if let scheduled = try container.decodeIfPresent(Int.self, forKey: .scheduledMinutes) {
            // Migration: convert single time to 1-hour slot
            startMinutes = scheduled
            endMinutes = scheduled + 60
        } else {
            startMinutes = 720
            endMinutes = 780
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(detail, forKey: .detail)
        try container.encode(isCompleted, forKey: .isCompleted)
        try container.encode(isHidden, forKey: .isHidden)
        try container.encode(startMinutes, forKey: .startMinutes)
        try container.encode(endMinutes, forKey: .endMinutes)
        try container.encodeIfPresent(customWidth, forKey: .customWidth)
        try container.encodeIfPresent(colorIndex, forKey: .colorIndex)
    }

    var formattedStartTime: String {
        let hours = startMinutes / 60
        let mins = startMinutes % 60
        let roundedMins = (mins / 5) * 5
        return String(format: "%02d:%02d", hours, roundedMins)
    }

    var formattedEndTime: String {
        let hours = endMinutes / 60
        let mins = endMinutes % 60
        let roundedMins = (mins / 5) * 5
        return String(format: "%02d:%02d", hours % 24, roundedMins)
    }

    var formattedTime: String {
        formattedStartTime
    }
}

// Persistent data structure saved to file
struct UniverseData: Codable {
    var habits: [DailyHabit]
    var timelineStartMinutes: Int
    var lastResetDate: Date
}

class DailyHabitManager: ObservableObject {
    static let shared = DailyHabitManager()

    @Published var habits: [DailyHabit] = []
    @Published var lastResetDate: Date = Date.distantPast
    @Published var timelineStartMinutes: Int = 660  // 11:00 AM default
    @Published var selectedHabitId: UUID?
    @Published var hoveredHabitDetail: String?

    private let resetHour = 4 // 4 AM reset
    private let historyStore = HabitHistoryStore.shared

    // Timeline end is always midnight
    static let timelineEndMinutes = 1440   // 00:00 midnight

    // File-based persistence (survives rebuilds)
    private var dataFileURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let universeDir = appSupport.appendingPathComponent("Universe", isDirectory: true)

        // Create directory if needed
        try? FileManager.default.createDirectory(at: universeDir, withIntermediateDirectories: true)

        return universeDir.appendingPathComponent("habits.json")
    }

    private init() {
        loadData()
        checkAndResetIfNeeded()
        startResetMonitoring()
    }

    private func loadData() {
        // Try to load from file first
        if let data = try? Data(contentsOf: dataFileURL),
           let decoded = try? JSONDecoder().decode(UniverseData.self, from: data) {
            habits = decoded.habits.sorted {
                    if $0.startMinutes != $1.startMinutes {
                        return $0.startMinutes < $1.startMinutes
                    }
                    return $0.id.uuidString < $1.id.uuidString
                }
            timelineStartMinutes = decoded.timelineStartMinutes
            lastResetDate = decoded.lastResetDate
            
            // Retroactive fix: ensure specific habits have their colorIndex set if missing
            // Workout -> Green (0), Offline -> Red (1), Visualize -> Blue (2), Research -> Orange (3)
            var needsSave = false
            for i in habits.indices {
                if habits[i].colorIndex == nil {
                    let name = habits[i].name.lowercased()
                    if name.contains("workout") { habits[i].colorIndex = 0; needsSave = true }
                    else if name.contains("offline") { habits[i].colorIndex = 1; needsSave = true }
                    else if name.contains("visualize") { habits[i].colorIndex = 2; needsSave = true }
                    else if name.contains("research") { habits[i].colorIndex = 3; needsSave = true }
                }
            }
            if needsSave {
                saveData()
            }
            
            print("[Universe] Loaded \(habits.count) habits from \(dataFileURL.path)")
        } else {
            // Default habits spread evenly across the timeline
            let defaultNames = ["Habit 1", "Habit 2", "Habit 3", "Habit 4"]
            habits = createSpreadHabits(names: defaultNames)
            saveData()
            print("[Universe] Created default habits at \(dataFileURL.path)")
        }
    }

    /// Creates habits spread evenly across the timeline
    private func createSpreadHabits(names: [String]) -> [DailyHabit] {
        guard !names.isEmpty else { return [] }

        let totalMinutes = Self.timelineEndMinutes - timelineStartMinutes
        let slotDuration = totalMinutes / names.count

        return names.enumerated().map { index, name in
            let start = timelineStartMinutes + (index * slotDuration)
            let end = start + slotDuration
            
            var colorIndex: Int? = nil
            let lowerName = name.lowercased()
            if lowerName.contains("workout") { colorIndex = 0 }
            else if lowerName.contains("offline") { colorIndex = 1 }
            else if lowerName.contains("visualize") { colorIndex = 2 }
            else if lowerName.contains("research") { colorIndex = 3 }
            
            return DailyHabit(
                name: name,
                startMinutes: start,
                endMinutes: end,
                colorIndex: colorIndex
            )
        }
    }

    /// Spreads all habits evenly across the timeline (called on daily reset)
    func spreadHabitsEvenly() {
        guard !habits.isEmpty else { return }

        let totalMinutes = Self.timelineEndMinutes - timelineStartMinutes
        let slotDuration = totalMinutes / habits.count

        for (index, _) in habits.enumerated() {
            let start = timelineStartMinutes + (index * slotDuration)
            let end = start + slotDuration
            habits[index].startMinutes = start
            habits[index].endMinutes = end
        }

        saveData()
    }

    private func saveData() {
        let data = UniverseData(
            habits: habits,
            timelineStartMinutes: timelineStartMinutes,
            lastResetDate: lastResetDate
        )

        if let encoded = try? JSONEncoder().encode(data) {
            do {
                try encoded.write(to: dataFileURL, options: .atomic)
            } catch {
                print("[Universe] Failed to save: \(error)")
            }
        }
    }

    func setTimelineStart(_ minutes: Int) {
        timelineStartMinutes = max(0, min(Self.timelineEndMinutes - 60, minutes))
        saveData()
    }

    var formattedStartTime: String {
        let hours = timelineStartMinutes / 60
        let mins = timelineStartMinutes % 60
        return String(format: "%02d:%02d", hours, mins)
    }

    private func startResetMonitoring() {
        Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.checkAndResetIfNeeded()
        }
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.checkAndResetIfNeeded()
        }
    }

    func checkAndResetIfNeeded() {
        let calendar = Calendar.current
        let now = Date()

        var resetComponents = calendar.dateComponents([.year, .month, .day], from: now)
        resetComponents.hour = resetHour
        resetComponents.minute = 0
        resetComponents.second = 0
        guard let todayResetTime = calendar.date(from: resetComponents) else { return }

        let effectiveResetTime: Date
        if now < todayResetTime {
            effectiveResetTime = calendar.date(byAdding: .day, value: -1, to: todayResetTime) ?? todayResetTime
        } else {
            effectiveResetTime = todayResetTime
        }

        if lastResetDate < effectiveResetTime {
            resetAllHabits()
            lastResetDate = now
            saveData()
        }
    }

    func resetAllHabits() {
        for i in habits.indices {
            habits[i].isCompleted = false
        }
        // Spread habits evenly on new day
        spreadHabitsEvenly()
        saveData()
    }

    func toggleHabit(_ habit: DailyHabit) {
        if let index = habits.firstIndex(where: { $0.id == habit.id }) {
            let newValue = !habits[index].isCompleted
            habits[index].isCompleted = newValue
            saveData()
            historyStore.update(habitId: habit.id, date: Date(), isCompleted: newValue)
        }
    }

    /// Move the entire slot (preserving duration) by setting a new start time
    func updateHabitTime(_ habit: DailyHabit, minutes: Int, persist: Bool = true) {
        if let index = habits.firstIndex(where: { $0.id == habit.id }) {
            let duration = habits[index].durationMinutes
            // Clamp to timeline range and round to 5 minutes
            let clamped = max(timelineStartMinutes, min(Self.timelineEndMinutes - duration, minutes))
            let rounded = (clamped / 5) * 5
            habits[index].startMinutes = rounded
            habits[index].endMinutes = rounded + duration
            // Re-sort by start time
            habits.sort {
                if $0.startMinutes != $1.startMinutes {
                    return $0.startMinutes < $1.startMinutes
                }
                return $0.id.uuidString < $1.id.uuidString
            }
            if persist {
                saveData()
            }
        }
    }

    /// Update slot start time (changes duration)
    func updateHabitStart(_ habit: DailyHabit, startMinutes: Int, persist: Bool = true) {
        if let index = habits.firstIndex(where: { $0.id == habit.id }) {
            let clamped = max(timelineStartMinutes, min(habits[index].endMinutes - 30, startMinutes))
            let rounded = (clamped / 5) * 5
            habits[index].startMinutes = rounded
            habits.sort {
                if $0.startMinutes != $1.startMinutes {
                    return $0.startMinutes < $1.startMinutes
                }
                return $0.id.uuidString < $1.id.uuidString
            }
            if persist {
                saveData()
            }
        }
    }

    /// Update slot end time (changes duration)
    func updateHabitEnd(_ habit: DailyHabit, endMinutes: Int, persist: Bool = true) {
        if let index = habits.firstIndex(where: { $0.id == habit.id }) {
            let clamped = max(habits[index].startMinutes + 30, min(Self.timelineEndMinutes, endMinutes))
            let rounded = (clamped / 5) * 5
            habits[index].endMinutes = rounded
            if persist {
                saveData()
            }
        }
    }

    func addHabit(name: String) {
        // Find a gap or add at the end
        let calendar = Calendar.current
        let now = Date()
        let currentMinutes = calendar.component(.hour, from: now) * 60 + calendar.component(.minute, from: now)

        var startMinutes = max(timelineStartMinutes, currentMinutes)
        let defaultDuration = 20 // 20 min default (1/3 of previous)

        // Ensure we don't exceed timeline
        if startMinutes + defaultDuration > Self.timelineEndMinutes {
            startMinutes = Self.timelineEndMinutes - defaultDuration
        }

        let habit = DailyHabit(
            name: name,
            startMinutes: startMinutes,
            endMinutes: startMinutes + defaultDuration
        )
        habits.append(habit)
        habits.sort {
                if $0.startMinutes != $1.startMinutes {
                    return $0.startMinutes < $1.startMinutes
                }
                return $0.id.uuidString < $1.id.uuidString
            }
        saveData()
    }

    func updateHabit(_ habit: DailyHabit, name: String) {
        if let index = habits.firstIndex(where: { $0.id == habit.id }) {
            habits[index].name = name
            saveData()
        }
    }

    func updateHabitDetail(_ habit: DailyHabit, detail: String) {
        if let index = habits.firstIndex(where: { $0.id == habit.id }) {
            habits[index].detail = detail
            saveData()
        }
    }

    func updateHabitWidth(_ habit: DailyHabit, width: CGFloat, persist: Bool = true) {
        if let index = habits.firstIndex(where: { $0.id == habit.id }) {
            habits[index].customWidth = width
            if persist {
                saveData()
            }
        }
    }

    func deleteHabit(_ habit: DailyHabit) {
        habits.removeAll { $0.id == habit.id }
        if selectedHabitId == habit.id {
            selectedHabitId = nil
        }
        saveData()
    }

    func selectHabit(_ habit: DailyHabit) {
        if selectedHabitId == habit.id {
            selectedHabitId = nil
        } else {
            selectedHabitId = habit.id
        }
    }

    func setSelectedHabit(_ habitId: UUID?) {
        selectedHabitId = habitId
    }

    // MARK: - Hidden Habits (Bucket)

    /// Habits visible on the timeline (not hidden)
    var visibleHabits: [DailyHabit] {
        habits.filter { !$0.isHidden }
    }

    /// Habits hidden in the bucket
    var hiddenHabits: [DailyHabit] {
        habits.filter { $0.isHidden }
    }

    /// Hide a habit (move to bucket)
    func hideHabit(_ habit: DailyHabit) {
        if let index = habits.firstIndex(where: { $0.id == habit.id }) {
            habits[index].isHidden = true
            if selectedHabitId == habit.id {
                selectedHabitId = nil
            }
            saveData()
        }
    }

    /// Unhide a habit (bring back from bucket to timeline)
    func unhideHabit(_ habit: DailyHabit) {
        if let index = habits.firstIndex(where: { $0.id == habit.id }) {
            habits[index].isHidden = false
            // Default to 20:00-21:00 when unhiding
            habits[index].startMinutes = 1200  // 20:00
            habits[index].endMinutes = 1260    // 21:00
            habits.sort {
                if $0.startMinutes != $1.startMinutes {
                    return $0.startMinutes < $1.startMinutes
                }
                return $0.id.uuidString < $1.id.uuidString
            }
            saveData()
        }
    }
}

// MARK: - Quick Launch Buttons

struct QuickLaunchButton: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var icon: String
    var appBundleId: String  // Bundle identifier or special command
    var shortcutString: String? // Keyboard shortcut (e.g. "cmd+shift+p")

    init(
        id: UUID = UUID(),
        name: String,
        icon: String,
        appBundleId: String,
        shortcutString: String? = nil
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.appBundleId = appBundleId
        self.shortcutString = shortcutString
    }
}

final class QuickLaunchManager: ObservableObject {
    static let shared = QuickLaunchManager()

    @Published var buttons: [QuickLaunchButton] = []

    private var dataFileURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let universeDir = appSupport.appendingPathComponent("Universe", isDirectory: true)
        try? FileManager.default.createDirectory(at: universeDir, withIntermediateDirectories: true)
        return universeDir.appendingPathComponent("quick-launch.json")
    }

    private init() {
        loadData()
        if buttons.isEmpty {
            seedDefaults()
        }
    }

    func addButton(name: String, icon: String, appBundleId: String, shortcutString: String? = nil) {
        let button = QuickLaunchButton(name: name, icon: icon, appBundleId: appBundleId, shortcutString: shortcutString)
        buttons.append(button)
        saveData()
    }

    func updateButton(_ button: QuickLaunchButton, name: String, icon: String, appBundleId: String, shortcutString: String? = nil) {
        if let index = buttons.firstIndex(where: { $0.id == button.id }) {
            buttons[index].name = name
            buttons[index].icon = icon
            buttons[index].appBundleId = appBundleId
            buttons[index].shortcutString = shortcutString
            saveData()
        }
    }

    func deleteButton(_ button: QuickLaunchButton) {
        buttons.removeAll { $0.id == button.id }
        saveData()
    }
    
    func moveButton(from source: IndexSet, to destination: Int) {
        buttons.move(fromOffsets: source, toOffset: destination)
        saveData()
    }

    func launchApp(_ button: QuickLaunchButton) {
        if let shortcut = button.shortcutString, !shortcut.isEmpty {
            AccessibilityManager.shared.simulateShortcut(shortcut)
        } else if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: button.appBundleId) {
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
        }
    }

    private func seedDefaults() {
        buttons = [
            QuickLaunchButton(name: "CRAFT", icon: "C", appBundleId: "universe.mode.craft"),
            QuickLaunchButton(name: "GRAPH", icon: "▦", appBundleId: "universe.mode.graph"),
            QuickLaunchButton(name: "DEV", icon: "⌘", appBundleId: "com.googlecode.iterm2"),
            QuickLaunchButton(name: "WEB", icon: "⌥", appBundleId: "company.thebrowser.Browser"),
            QuickLaunchButton(name: "MUSIC", icon: "♪", appBundleId: "com.spotify.client"),
        ]
        saveData()
    }

    private func loadData() {
        if let data = try? Data(contentsOf: dataFileURL),
           let decoded = try? JSONDecoder().decode([QuickLaunchButton].self, from: data) {
            buttons = decoded
        }
    }

    private func saveData() {
        if let data = try? JSONEncoder().encode(buttons) {
            try? data.write(to: dataFileURL, options: .atomic)
        }
    }
}

// MARK: - Initiatives

struct Initiative: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var symbol: String
    var targetDate: Date
    var detail: String // Description tooltip

    init(
        id: UUID = UUID(),
        name: String,
        symbol: String = "sparkles",
        targetDate: Date = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date(),
        detail: String = ""
    ) {
        self.id = id
        self.name = name
        self.symbol = symbol
        self.targetDate = targetDate
        self.detail = detail
    }
}

final class InitiativeManager: ObservableObject {
    static let shared = InitiativeManager()

    @Published var initiatives: [Initiative] = []

    private var dataFileURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let universeDir = appSupport.appendingPathComponent("Universe", isDirectory: true)
        try? FileManager.default.createDirectory(at: universeDir, withIntermediateDirectories: true)
        return universeDir.appendingPathComponent("initiatives.json")
    }

    private init() {
        loadData()
        if initiatives.isEmpty {
            seedDefaults()
        }
    }

    func addInitiative(name: String) {
        let initiative = Initiative(name: name)
        initiatives.append(initiative)
        saveData()
    }

    func updateInitiative(_ initiative: Initiative, name: String) {
        if let index = initiatives.firstIndex(where: { $0.id == initiative.id }) {
            initiatives[index].name = name
            saveData()
        }
    }

    func updateSymbol(_ initiative: Initiative, symbol: String) {
        if let index = initiatives.firstIndex(where: { $0.id == initiative.id }) {
            initiatives[index].symbol = symbol
            saveData()
        }
    }

    func updateTargetDate(_ initiative: Initiative, date: Date) {
        if let index = initiatives.firstIndex(where: { $0.id == initiative.id }) {
            initiatives[index].targetDate = date
            saveData()
        }
    }
    
    func updateDetail(_ initiative: Initiative, detail: String) {
        if let index = initiatives.firstIndex(where: { $0.id == initiative.id }) {
            initiatives[index].detail = detail
            saveData()
        }
    }

    func deleteInitiative(_ initiative: Initiative) {
        initiatives.removeAll { $0.id == initiative.id }
        saveData()
    }

    private func seedDefaults() {
        initiatives = [
            Initiative(name: "Initiative 1"),
            Initiative(name: "Initiative 2")
        ]
        saveData()
    }

    private func loadData() {
        if let data = try? Data(contentsOf: dataFileURL),
           let decoded = try? JSONDecoder().decode([Initiative].self, from: data) {
            initiatives = decoded
        }
    }

    private func saveData() {
        if let data = try? JSONEncoder().encode(initiatives) {
            try? data.write(to: dataFileURL, options: .atomic)
        }
    }
}

// MARK: - System Audio Beat Manager

final class SystemAudioBeatManager: ObservableObject {
    static let shared = SystemAudioBeatManager()

    @Published var isPlaying: Bool = false
    @Published var beatIntensity: CGFloat = 0
    @Published var barLevels: [CGFloat] = Array(repeating: 0, count: 10)
    @Published var hasPermission: Bool = true // No permission needed

    private var pollTimer: Timer?
    private var beatTimer: Timer?
    private var lastBeat: TimeInterval = 0
    private let bpm: Double = 120.0 // Simulated BPM

    private init() {
        startPolling()
    }

    private func startPolling() {
        // Poll Spotify state every 2 seconds
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.checkSpotifyState()
        }
        checkSpotifyState()
        
        // Simulate beat animation
        beatTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            self?.updateBeat()
        }
    }

    private func checkSpotifyState() {
        let scriptSource = """
        if application "Spotify" is running then
            tell application "Spotify" to get player state as string
        else
            return "stopped"
        end if
        """
        
        var error: NSDictionary?
        if let script = NSAppleScript(source: scriptSource) {
            if let output = script.executeAndReturnError(&error).stringValue {
                DispatchQueue.main.async {
                    self.isPlaying = (output == "playing")
                }
            }
        }
    }

    private func updateBeat() {
        guard isPlaying else {
            if beatIntensity > 0 {
                withAnimation(.linear(duration: 0.2)) {
                    beatIntensity = 0
                    barLevels = Array(repeating: 0, count: 10)
                }
            }
            return
        }

        let now = Date().timeIntervalSince1970
        let beatInterval = 60.0 / bpm
        let timeSinceBeat = now.truncatingRemainder(dividingBy: beatInterval)
        
        // Pulse effect
        let progress = timeSinceBeat / beatInterval
        let pulse = max(0, 1 - pow(progress, 0.3)) // Sharp attack, slow decay
        
        beatIntensity = CGFloat(pulse)

        // Randomize bars based on beat
        var newLevels: [CGFloat] = []
        for i in 0..<10 {
            let baseLevel = pulse * Double.random(in: 0.5...1.0)
            let randomOffset = Double.random(in: -0.2...0.2)
            let level = max(0, min(1, baseLevel + randomOffset))
            // Bass bars (left) are stronger
            let multiplier = i < 3 ? 1.2 : (i < 6 ? 1.0 : 0.8)
            newLevels.append(CGFloat(level * multiplier))
        }
        
        barLevels = newLevels
    }

    func requestPermission() {
        // No permission needed
    }
}

// Keep backward compatibility alias
typealias SpotifyBeatManager = SystemAudioBeatManager

// MARK: - Habit History

final class HabitHistoryStore: ObservableObject {
    static let shared = HabitHistoryStore()

    @Published private(set) var history: [String: [String: Bool]] = [:]

    private let resetHour = 4
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar
    }()
    private let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private var dataFileURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let universeDir = appSupport.appendingPathComponent("Universe", isDirectory: true)
        try? FileManager.default.createDirectory(at: universeDir, withIntermediateDirectories: true)
        return universeDir.appendingPathComponent("habit-history.json")
    }

    private init() {
        loadData()
    }

    func update(habitId: UUID, date: Date, isCompleted: Bool) {
        let habitKey = habitId.uuidString
        let dayKey = dayKey(for: date)
        var habitHistory = history[habitKey] ?? [:]
        habitHistory[dayKey] = isCompleted
        history[habitKey] = habitHistory
        saveData()
    }

    func completionSeries(for habitId: UUID, days: Int = 30) -> [Bool] {
        let habitKey = habitId.uuidString
        let habitHistory = history[habitKey] ?? [:]
        let today = effectiveDayStart(for: Date())
        var results: [Bool] = []

        for offset in stride(from: days - 1, through: 0, by: -1) {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            let key = dayKey(for: date)
            results.append(habitHistory[key] ?? false)
        }

        return results
    }

    private func dayKey(for date: Date) -> String {
        dayFormatter.string(from: effectiveDayStart(for: date))
    }

    private func effectiveDayStart(for date: Date) -> Date {
        let components = calendar.dateComponents([.year, .month, .day, .hour], from: date)
        let hour = components.hour ?? 0
        let baseDate = calendar.startOfDay(for: date)

        if hour < resetHour {
            return calendar.date(byAdding: .day, value: -1, to: baseDate) ?? baseDate
        }
        return baseDate
    }

    private func loadData() {
        if let data = try? Data(contentsOf: dataFileURL),
           let decoded = try? JSONDecoder().decode([String: [String: Bool]].self, from: data) {
            history = decoded
        }
    }

    private func saveData() {
        if let data = try? JSONEncoder().encode(history) {
            try? data.write(to: dataFileURL, options: .atomic)
        }
    }
}

// MARK: - Usage Tracking

struct UsageDay: Identifiable {
    let id: String
    let date: Date
    let seconds: TimeInterval
}

final class UsageTracker: ObservableObject {
    static let shared = UsageTracker()

    @Published private(set) var todaySeconds: TimeInterval = 0
    @Published private(set) var records: [String: TimeInterval] = [:]

    // Day resets at 4am instead of midnight
    private let dayResetHour = 4

    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar
    }()
    private let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private var lastTick = Date()
    private var currentDayKey: String = ""
    private var timer: Timer?
    private var isSleeping = false

    private var dataFileURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let universeDir = appSupport.appendingPathComponent("Universe", isDirectory: true)
        try? FileManager.default.createDirectory(at: universeDir, withIntermediateDirectories: true)
        return universeDir.appendingPathComponent("usage.json")
    }

    private init() {
        loadData()
        currentDayKey = dayKey(for: Date())
        todaySeconds = records[currentDayKey] ?? 0
        lastTick = Date()
        startTracking()
        observeSleepWake()
    }

    var formattedToday: String {
        let totalMinutes = Int(todaySeconds / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return String(format: "%dh %02dm", hours, minutes)
    }

    var last30Days: [UsageDay] {
        // Get the "logical today" accounting for 4am boundary
        let logicalToday = logicalDayStart(for: Date())
        var days: [UsageDay] = []
        for offset in stride(from: 29, through: 0, by: -1) {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: logicalToday) else { continue }
            let key = dayKey(for: date)
            let seconds = records[key] ?? 0
            days.append(UsageDay(id: key, date: date, seconds: seconds))
        }
        return days
    }

    private func startTracking() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    private func observeSleepWake() {
        // Observe Mac going to sleep - pause tracking
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleSleep()
        }

        // Observe Mac waking up - resume tracking
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleWake()
        }
    }

    private func handleSleep() {
        // Tick one last time to save current progress before sleep
        tick()
        isSleeping = true
    }

    private func handleWake() {
        // Reset lastTick to now so sleep time isn't counted
        lastTick = Date()
        isSleeping = false

        // Check if we crossed the 4am boundary while sleeping
        let newDayKey = dayKey(for: Date())
        if newDayKey != currentDayKey {
            currentDayKey = newDayKey
            todaySeconds = records[currentDayKey] ?? 0
        }
    }

    private func tick() {
        guard !isSleeping else { return }

        let now = Date()
        let newDayKey = self.dayKey(for: now)

        // Check if we crossed the 4am boundary
        if newDayKey != currentDayKey {
            currentDayKey = newDayKey
            todaySeconds = records[currentDayKey] ?? 0
        }

        let elapsed = now.timeIntervalSince(lastTick)
        // Only count reasonable intervals (ignore large gaps from sleep/suspend)
        if elapsed > 0 && elapsed < 120 {
            todaySeconds += elapsed
            records[currentDayKey] = todaySeconds
            saveData()
        }

        lastTick = now
    }

    /// Returns the day key for tracking, accounting for 4am boundary.
    /// Times between midnight and 4am are counted as the previous day.
    private func dayKey(for date: Date) -> String {
        let adjustedDate = logicalDayStart(for: date)
        return dayFormatter.string(from: adjustedDate)
    }

    /// Returns the logical day start (4am boundary).
    /// If current time is before 4am, returns yesterday's date.
    private func logicalDayStart(for date: Date) -> Date {
        let hour = calendar.component(.hour, from: date)
        if hour < dayResetHour {
            // Before 4am - count as previous day
            return calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: date)) ?? date
        } else {
            return calendar.startOfDay(for: date)
        }
    }

    private func loadData() {
        if let data = try? Data(contentsOf: dataFileURL),
           let decoded = try? JSONDecoder().decode([String: TimeInterval].self, from: data) {
            records = decoded
        }
    }

    private func saveData() {
        if let data = try? JSONEncoder().encode(records) {
            try? data.write(to: dataFileURL, options: .atomic)
        }
    }
}

struct UsageStrip: View {
    @ObservedObject private var usageTracker = UsageTracker.shared
    @ObservedObject private var habitManager = DailyHabitManager.shared
    @ObservedObject private var historyStore = HabitHistoryStore.shared
    @ObservedObject private var widgetState = MenuBarWidgetState.shared

    var body: some View {
        let days = usageTracker.last30Days
        let completionSeries = habitManager.selectedHabitId.map {
            historyStore.completionSeries(for: $0)
        }
        let graphColor = graphColor(for: habitManager.selectedHabitId)
        let graphOptions = buildGraphOptions()

        let graphValues: [Double] = {
            if let completionSeries = completionSeries, !completionSeries.isEmpty {
                return completionSeries.map { $0 ? 1 : 0 }
            } else {
                let maxSeconds = max(days.map(\.seconds).max() ?? 1, 1)
                return days.map { $0.seconds / maxSeconds }
            }
        }()

        HStack(spacing: 10) {
            AudioMeter(
                seconds: usageTracker.todaySeconds,
                label: usageTracker.formattedToday
            )
            .scaleEffect(1.15)
            .offset(y: 3)
            .padding(.horizontal, 2)
            VStack(alignment: .leading, spacing: 4) {
                UsageMiniGraph(
                    values: graphValues,
                    dayCount: days.count,
                    completionSeries: completionSeries,
                    graphColor: graphColor
                )
                GraphToggleRow(
                    options: graphOptions,
                    selectedHabitId: habitManager.selectedHabitId,
                    onSelect: { habitManager.setSelectedHabit($0) }
                )
            }
        }
        .padding(.horizontal, 10)
        .frame(maxHeight: .infinity)
    }

    private func graphColor(for habitId: UUID?) -> Color {
        guard let habitId = habitId,
              let habit = habitManager.habits.first(where: { $0.id == habitId }) else {
            return Color.white
        }
        
        // Use manual color index if set, otherwise fallback to list index
        if let manualIndex = habit.colorIndex {
            return graphPalette[manualIndex % graphPalette.count]
        }

        if let index = habitManager.habits.firstIndex(where: { $0.id == habitId }) {
            return graphPalette[index % graphPalette.count]
        }
        
        return Color.white
    }

    private func buildGraphOptions() -> [GraphOption] {
        var options: [GraphOption] = [
            GraphOption(id: "timetrack", habitId: nil, label: "Timetrack", color: Color.white)
        ]

        let habits = habitManager.habits
        // Desired order: Index 1, 3, 2, 0, then 4...
        var reorderedHabits: [DailyHabit] = []
        var usedIndices = Set<Int>()
        
        let priorityIndices = [1, 3, 2, 0]
        
        for index in priorityIndices {
            if index < habits.count {
                reorderedHabits.append(habits[index])
                usedIndices.insert(index)
            }
        }
        
        for (index, habit) in habits.enumerated() {
            if !usedIndices.contains(index) {
                reorderedHabits.append(habit)
            }
        }

        for habit in reorderedHabits {
            // Find original index for color consistency
            let originalIndex = habits.firstIndex(where: { $0.id == habit.id }) ?? 0
            
            let color: Color
            if let manualIndex = habit.colorIndex {
                color = graphPalette[manualIndex % graphPalette.count]
            } else {
                color = graphPalette[originalIndex % graphPalette.count]
            }
            options.append(GraphOption(id: habit.id.uuidString, habitId: habit.id, label: habit.name, color: color))
        }

        return options
    }

    private var graphPalette: [Color] {
        [
            Color.green,
            Color.red,
            Color.blue,
            Color.orange,
            Color.purple,
            Color.teal,
            Color.yellow
        ]
    }

    private struct UsageMiniGraph: View {
        let values: [Double]
        let dayCount: Int
        let completionSeries: [Bool]?
        let graphColor: Color

        var body: some View {
            VStack(alignment: .leading, spacing: 4) {
                SparklineGraph(values: values, color: graphColor)

                if let completionSeries = completionSeries, completionSeries.count == dayCount {
                    HStack(spacing: 1) {
                        ForEach(completionSeries.indices, id: \.self) { index in
                            RoundedRectangle(cornerRadius: 1)
                                .fill(completionSeries[index] ? graphColor.opacity(0.9) : Color.white.opacity(0.15))
                                .frame(width: 2, height: 4)
                        }
                    }
                }
            }
        }

        private struct SparklineGraph: View {
            let values: [Double]
            let color: Color

            var body: some View {
                GeometryReader { geometry in
                    let width = geometry.size.width
                    let height = geometry.size.height
                    let points = makePoints(values: values, width: width, height: height)
                    let linePath = smoothLinePath(points: points)

                    ZStack(alignment: .topLeading) {
                        if let first = points.first, let last = points.last {
                            let areaPath = filledAreaPath(linePath: linePath, start: first, end: last, height: height)

                            areaPath
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            color.opacity(0.35),
                                            color.opacity(0.12),
                                            Color.clear
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )

                            linePath
                                .stroke(color.opacity(0.5), lineWidth: 6)
                                .blur(radius: 6)

                            linePath
                                .stroke(color, lineWidth: 2)
                                .glassGlow(radius: 5, opacity: 0.6) // Enhanced glow

                            Path { path in
                                path.move(to: CGPoint(x: last.x, y: last.y))
                                path.addLine(to: CGPoint(x: last.x, y: height))
                            }
                            .stroke(Color.white.opacity(0.6), lineWidth: 1)

                            Path { path in
                                path.move(to: CGPoint(x: last.x, y: last.y))
                                path.addLine(to: CGPoint(x: width, y: last.y))
                            }
                            .stroke(
                                color.opacity(0.6),
                                style: StrokeStyle(lineWidth: 1, dash: [4, 4])
                            )

                            Circle()
                                .fill(color.opacity(0.4))
                                .frame(width: 18, height: 18)
                                .blur(radius: 6)
                                .position(last)

                            Circle()
                                .fill(color)
                                .frame(width: 6, height: 6)
                                .position(last)
                        }
                    }
                }
                .frame(maxHeight: .infinity)
            }

            private func makePoints(values: [Double], width: CGFloat, height: CGFloat) -> [CGPoint] {
                guard !values.isEmpty else { return [] }

                let horizontalPadding: CGFloat = 2
                let usableWidth = max(width - horizontalPadding * 2, 1)
                let stepX = values.count > 1 ? usableWidth / CGFloat(values.count - 1) : 0
                let maxHeight = max(height - 4, 1)

                return values.enumerated().map { index, value in
                    let clamped = min(max(value, 0), 1)
                    let x = horizontalPadding + CGFloat(index) * stepX
                    let y = height - (CGFloat(clamped) * maxHeight) - 2
                    return CGPoint(x: x, y: y)
                }
            }

            private func smoothLinePath(points: [CGPoint]) -> Path {
                var path = Path()
                guard points.count > 1 else {
                    if let point = points.first {
                        path.addEllipse(in: CGRect(x: point.x - 1, y: point.y - 1, width: 2, height: 2))
                    }
                    return path
                }

                path.move(to: points[0])

                for index in 0..<(points.count - 1) {
                    let p0 = index > 0 ? points[index - 1] : points[index]
                    let p1 = points[index]
                    let p2 = points[index + 1]
                    let p3 = index + 2 < points.count ? points[index + 2] : p2

                    let control1 = CGPoint(
                        x: p1.x + (p2.x - p0.x) / 6,
                        y: p1.y + (p2.y - p0.y) / 6
                    )
                    let control2 = CGPoint(
                        x: p2.x - (p3.x - p1.x) / 6,
                        y: p2.y - (p3.y - p1.y) / 6
                    )

                    path.addCurve(to: p2, control1: control1, control2: control2)
                }

                return path
            }

            private func filledAreaPath(linePath: Path, start: CGPoint, end: CGPoint, height: CGFloat) -> Path {
                var path = linePath
                path.addLine(to: CGPoint(x: end.x, y: height))
                path.addLine(to: CGPoint(x: start.x, y: height))
                path.closeSubpath()
                return path
            }
        }
    }

    private struct GraphOption: Identifiable {
        let id: String
        let habitId: UUID?
        let label: String
        let color: Color
    }

    private struct GraphToggleRow: View {
        let options: [GraphOption]
        let selectedHabitId: UUID?
        let onSelect: (UUID?) -> Void

        var body: some View {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(options) { option in
                        GraphToggleButton(
                            label: option.label,
                            color: option.color,
                            isSelected: option.habitId == selectedHabitId
                        ) {
                            onSelect(option.habitId)
                        }
                    }
                }
            }
        }
    }

    private struct GraphToggleButton: View {
        let label: String
        let color: Color
        let isSelected: Bool
        let action: () -> Void

        var body: some View {
            Button(action: action) {
                Text(label)
                    .font(.system(size: 6, design: .monospaced))
                    .foregroundColor(isSelected ? color : Color.white.opacity(0.6))
                    .lineLimit(1)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 3)
                            .fill(isSelected ? color.opacity(0.2) : Color.clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(isSelected ? color.opacity(0.8) : Color.white.opacity(0.2), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
    }
}





// MARK: - Audio Meter (clickable, supports audio visualization)

private struct AudioMeter: View {
    let seconds: TimeInterval
    let label: String

    private let barCount = 10
    private let hoursToSeconds: Double = 3600

    var body: some View {
        let totalHours = seconds / hoursToSeconds
        let currentHourIndex = Int(totalHours)
        let currentHourProgress = totalHours - Double(currentHourIndex)

        VStack(spacing: 3) {
            VStack(spacing: 2) {
                // Stack fills bottom-to-top, so iterate reversed (9 down to 0)
                ForEach((0..<barCount).reversed(), id: \.self) { index in
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // Background (Grey)
                            RoundedRectangle(cornerRadius: 1)
                                .fill(Color.white.opacity(0.15))
                            
                            // Fill (White)
                            RoundedRectangle(cornerRadius: 1)
                                .fill(Color.white.opacity(0.8))
                                .frame(width: fillWidth(for: index, currentHourIndex: currentHourIndex, progress: currentHourProgress, totalWidth: geometry.size.width))
                        }
                    }
                    .frame(width: 12, height: 1)
                }
            }
            .padding(.vertical, 0)
            .padding(.horizontal, 0)

            Text(label)
                .font(.system(size: 6, weight: .medium, design: .monospaced))
                .foregroundColor(Color.white.opacity(0.6))
        }
    }
    
    private func fillWidth(for index: Int, currentHourIndex: Int, progress: Double, totalWidth: CGFloat) -> CGFloat {
        if index < currentHourIndex {
            return totalWidth // Fully filled (past hours)
        } else if index == currentHourIndex {
            return totalWidth * CGFloat(progress) // Partially filled (current hour)
        } else {
            return 0 // Empty (future hours)
        }
    }
}

// MARK: - Weather Forecast

struct WeatherDay: Identifiable {
    let id = UUID()
    let date: Date
    let maxTemp: Double
    let category: WeatherCategory
}

enum WeatherCategory {
    case sun
    case cloud
    case rain
    case snow

    var symbolName: String {
        switch self {
        case .sun:
            return "sun.max.fill"
        case .cloud:
            return "cloud.fill"
        case .rain:
            return "cloud.rain.fill"
        case .snow:
            return "cloud.snow.fill"
        }
    }

    static func fromSMHISymbol(_ code: Int) -> WeatherCategory {
        switch code {
        case 1, 2:
            return .sun
        case 3, 4, 5, 6, 7:
            return .cloud
        case 8, 9, 10, 11, 12, 13, 14, 15:
            return .rain
        case 16...27:
            return .snow
        default:
            return .cloud
        }
    }
}

@MainActor
final class WeatherManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = WeatherManager()

    @Published var days: [WeatherDay] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private static let savedLatitudeKey = "WeatherManager.savedLatitude"
    private static let savedLongitudeKey = "WeatherManager.savedLongitude"

    private let locationManager = CLLocationManager()
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Stockholm") ?? .current
        return calendar
    }()
    private let isoFormatter = ISO8601DateFormatter()
    private let isoFormatterNoFraction: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
    private var resolvedCoordinate: CLLocationCoordinate2D?

    private init() {
        super.init()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
        resolvedCoordinate = Self.environmentCoordinateOverride() ?? Self.loadSavedCoordinate()
    }

    func refresh() async {
        let shouldStart: Bool
        if isLoading {
            shouldStart = false
        } else {
            isLoading = true
            errorMessage = nil
            shouldStart = true
        }
        if !shouldStart {
            return
        }

        if let coordinate = Self.environmentCoordinateOverride() ?? resolvedCoordinate {
            await fetchForecast(for: coordinate)
            return
        }

        requestLocationIfNeeded()
    }

    private func buildDays(from series: [SMHITimeSeries]) -> [WeatherDay] {
        struct Bucket {
            var maxTemp: Double = -.infinity
            var symbolCounts: [Int: Int] = [:]
        }

        var buckets: [Date: Bucket] = [:]
        for entry in series {
            guard let date = parseDate(entry.validTime) else { continue }
            let dayStart = calendar.startOfDay(for: date)
            var bucket = buckets[dayStart] ?? Bucket()

            if let temp = entry.value(named: "t") {
                bucket.maxTemp = max(bucket.maxTemp, temp)
            }
            if let symbol = entry.intValue(named: "Wsymb2") {
                bucket.symbolCounts[symbol, default: 0] += 1
            }

            buckets[dayStart] = bucket
        }

        let today = calendar.startOfDay(for: Date())
        var results: [WeatherDay] = []

        for offset in 0..<7 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today),
                  let bucket = buckets[day],
                  bucket.maxTemp.isFinite else {
                continue
            }

            let dominantSymbol = bucket.symbolCounts.max { $0.value < $1.value }?.key ?? 1
            results.append(WeatherDay(
                date: day,
                maxTemp: bucket.maxTemp,
                category: WeatherCategory.fromSMHISymbol(dominantSymbol)
            ))
        }

        return results
    }

    private func parseDate(_ string: String) -> Date? {
        if let date = isoFormatter.date(from: string) {
            return date
        }
        return isoFormatterNoFraction.date(from: string)
    }

    private func requestLocationIfNeeded() {
        guard CLLocationManager.locationServicesEnabled() else {
            errorMessage = "LOCATION DISABLED"
            isLoading = false
            return
        }

        switch CLLocationManager.authorizationStatus() {
        case .authorizedAlways, .authorizedWhenInUse:
            locationManager.requestLocation()
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            errorMessage = "LOCATION REQUIRED"
            isLoading = false
        @unknown default:
            errorMessage = "LOCATION UNAVAILABLE"
            isLoading = false
        }
    }

    private func fetchForecast(for coordinate: CLLocationCoordinate2D) async {
        do {
            let (data, _) = try await URLSession.shared.data(from: forecastURL(for: coordinate))
            let forecast = try JSONDecoder().decode(SMHIForecast.self, from: data)
            days = buildDays(from: forecast.timeSeries)
        } catch {
            errorMessage = "WEATHER OFFLINE"
        }

        isLoading = false
    }

    private func forecastURL(for coordinate: CLLocationCoordinate2D) -> URL {
        let locale = Locale(identifier: "en_US_POSIX")
        let longitude = String(format: "%.4f", locale: locale, coordinate.longitude)
        let latitude = String(format: "%.4f", locale: locale, coordinate.latitude)
        return URL(string: "https://opendata-download-metfcst.smhi.se/api/category/pmp3g/version/2/geotype/point/lon/\(longitude)/lat/\(latitude)/data.json")!
    }

    private static func environmentCoordinateOverride() -> CLLocationCoordinate2D? {
        let environment = ProcessInfo.processInfo.environment
        guard let latitudeString = environment["UNIVERSE_WEATHER_LAT"],
              let longitudeString = environment["UNIVERSE_WEATHER_LON"],
              let latitude = Double(latitudeString),
              let longitude = Double(longitudeString),
              (-90.0...90.0).contains(latitude),
              (-180.0...180.0).contains(longitude) else {
            return nil
        }

        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    private static func loadSavedCoordinate() -> CLLocationCoordinate2D? {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: savedLatitudeKey) != nil,
              defaults.object(forKey: savedLongitudeKey) != nil else {
            return nil
        }

        let latitude = defaults.double(forKey: savedLatitudeKey)
        let longitude = defaults.double(forKey: savedLongitudeKey)
        guard (-90.0...90.0).contains(latitude),
              (-180.0...180.0).contains(longitude) else {
            return nil
        }

        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    private static func saveCoordinate(_ coordinate: CLLocationCoordinate2D) {
        let defaults = UserDefaults.standard
        defaults.set(coordinate.latitude, forKey: savedLatitudeKey)
        defaults.set(coordinate.longitude, forKey: savedLongitudeKey)
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard isLoading else { return }

        switch CLLocationManager.authorizationStatus() {
        case .authorizedAlways, .authorizedWhenInUse:
            manager.requestLocation()
        case .denied, .restricted:
            errorMessage = "LOCATION REQUIRED"
            isLoading = false
        case .notDetermined:
            break
        @unknown default:
            errorMessage = "LOCATION UNAVAILABLE"
            isLoading = false
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let coordinate = locations.last?.coordinate else {
            errorMessage = "LOCATION UNAVAILABLE"
            isLoading = false
            return
        }

        resolvedCoordinate = coordinate
        Self.saveCoordinate(coordinate)

        Task {
            await fetchForecast(for: coordinate)
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if let coordinate = resolvedCoordinate {
            Task {
                await fetchForecast(for: coordinate)
            }
            return
        }

        errorMessage = "LOCATION UNAVAILABLE"
        isLoading = false
    }
}

struct SMHIForecast: Decodable {
    let timeSeries: [SMHITimeSeries]
}

struct SMHITimeSeries: Decodable {
    let validTime: String
    let parameters: [SMHIParameter]

    func value(named name: String) -> Double? {
        parameters.first(where: { $0.name == name })?.values.first
    }

    func intValue(named name: String) -> Int? {
        guard let value = value(named: name) else { return nil }
        return Int(value.rounded())
    }
}

struct SMHIParameter: Decodable {
    let name: String
    let values: [Double]
}

struct WeatherStrip: View {
    @StateObject private var weatherManager = WeatherManager.shared
    private let refreshTimer = Timer.publish(every: 1800, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .center, spacing: 4) {
            // Larger weather display (detailed view)
            if weatherManager.days.isEmpty {
                Text(weatherManager.errorMessage ?? "...")
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundColor(UniverseTheme.textSecondary)
            } else {
                HStack(spacing: 6) {
                    ForEach(weatherManager.days) { day in
                        WeatherDayView(day: day)
                    }
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task { await weatherManager.refresh() }
        .onReceive(refreshTimer) { _ in
            Task {
                await weatherManager.refresh()
            }
        }
    }

    private struct WeatherDayView: View {
        let day: WeatherDay

        var body: some View {
            VStack(spacing: 2) {
                Image(systemName: day.category.symbolName)
                    .font(.system(size: 12))
                    .foregroundColor(UniverseTheme.textPrimary)
                    .glassGlow(radius: 3, opacity: 0.4)

                Text("\(Int(day.maxTemp.rounded()))°")
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundColor(UniverseTheme.textPrimary)
                    .glassGlow(radius: 2, opacity: 0.3)
            }
            .frame(width: 22)
        }
    }
}

// MARK: - Universe Timeline Colors

enum UniverseColors {
    static let violetDeep = Color(red: 0.4, green: 0.2, blue: 0.8)
    static let violetBright = Color(red: 0.6, green: 0.3, blue: 1.0)
    static let blueDeep = Color(red: 0.2, green: 0.3, blue: 0.7)
    static let blueBright = Color(red: 0.3, green: 0.5, blue: 1.0)
    static let cosmicPurple = Color(red: 0.5, green: 0.2, blue: 0.9)
}

struct TimelineStyle {
    let timelineY: CGFloat
    let slotY: CGFloat
    let slotHeight: CGFloat
    let padding: CGFloat
    let habitInnerPadding: CGFloat
    let timeLabelFontSize: CGFloat
    let slotTimeLabelFontSize: CGFloat
    let habitFontSize: CGFloat
    let checkboxFontSize: CGFloat
    let checkboxSize: CGFloat
    let addButtonSize: CGFloat
    let minimumSlotWidth: CGFloat
    let showsTimeLabels: Bool
    let showsAdjustButtons: Bool
    let showsAddButton: Bool
    let showsSlotMarkers: Bool
    let showsCheckbox: Bool
    let showsCurrentTimeMarker: Bool
    let isInline: Bool

    static let standard = TimelineStyle(
        timelineY: 10,
        slotY: 22,
        slotHeight: 24,
        padding: 50,
        habitInnerPadding: 2,
        timeLabelFontSize: 9,
        slotTimeLabelFontSize: 8,
        habitFontSize: 11.0,
        checkboxFontSize: 10,
        checkboxSize: 12,
        addButtonSize: 12,
        minimumSlotWidth: 60,
        showsTimeLabels: true,
        showsAdjustButtons: true,
        showsAddButton: true,
        showsSlotMarkers: true,
        showsCheckbox: true,
        showsCurrentTimeMarker: true,
        isInline: false
    )

    static let menubarInline = TimelineStyle(
        timelineY: -4,
        slotY: 6,
        slotHeight: 14,
        padding: 6,
        habitInnerPadding: 1,
        timeLabelFontSize: 12,
        slotTimeLabelFontSize: 8,
        habitFontSize: 10.5,
        checkboxFontSize: 9,
        checkboxSize: 8,
        addButtonSize: 10,
        minimumSlotWidth: 48,
        showsTimeLabels: false,
        showsAdjustButtons: false,
        showsAddButton: false,
        showsSlotMarkers: false,
        showsCheckbox: false,
        showsCurrentTimeMarker: true,
        isInline: true
    )

    // Same as menubarInline but without the current time marker (for overlay approach)
    static let menubarInlineNoMarker = TimelineStyle(
        timelineY: -4,
        slotY: 6,
        slotHeight: 14,
        padding: 6,
        habitInnerPadding: 1,
        timeLabelFontSize: 12,
        slotTimeLabelFontSize: 8,
        habitFontSize: 10.5,
        checkboxFontSize: 9,
        checkboxSize: 8,
        addButtonSize: 10,
        minimumSlotWidth: 48,
        showsTimeLabels: false,
        showsAdjustButtons: false,
        showsAddButton: false,
        showsSlotMarkers: false,
        showsCheckbox: false,
        showsCurrentTimeMarker: false,
        isInline: true
    )

    static let menubarExpanded = TimelineStyle(
        timelineY: 10,
        slotY: 22,
        slotHeight: 18,
        padding: 50,
        habitInnerPadding: 3,
        timeLabelFontSize: 9,
        slotTimeLabelFontSize: 8,
        habitFontSize: 11.0,
        checkboxFontSize: 10,
        checkboxSize: 12,
        addButtonSize: 12,
        minimumSlotWidth: 60,
        showsTimeLabels: true,
        showsAdjustButtons: true,
        showsAddButton: true,
        showsSlotMarkers: true,
        showsCheckbox: false,
        showsCurrentTimeMarker: true,
        isInline: false
    )
}

// MARK: - Toolbar Identity Field

struct ToolbarIdentityField: View {
    @AppStorage("toolbar_identity_title") private var title: String = "Controlcenter"
    @ObservedObject private var habitManager = DailyHabitManager.shared
    @State private var isFocused = false
    @State private var isEditing = false

    var body: some View {
        ZStack {
            if isEditing {
                SelectableTextField(text: $title, isFocused: $isFocused, fontSize: 8, weight: .semibold)
                    .tracking(1.1)
                    .onAppear {
                        isFocused = true
                    }
            } else {
                Text(habitManager.hoveredHabitDetail?.isEmpty == false ? habitManager.hoveredHabitDetail! : title)
                    .font(.system(size: 8, weight: .semibold, design: .monospaced))
                    .foregroundColor(habitManager.hoveredHabitDetail?.isEmpty == false ? UniverseTheme.accent : Color.white)
                    .tracking(1.1)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 2)
        .frame(minWidth: 160, maxWidth: 220)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color.white.opacity(0.08))
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.25),
                        Color.white.opacity(0.02)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(RoundedRectangle(cornerRadius: 5))
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .stroke(Color.white.opacity(0.25), lineWidth: 0.6)
        )
        .glassGlow(radius: 2, opacity: 0.35)
        .contentShape(Rectangle())
        .onTapGesture {
            isEditing = true
            isFocused = true
        }
        .onChange(of: isFocused) { _, focused in
            if !focused {
                isEditing = false
            }
        }
    }
}

struct SelectableTextField: NSViewRepresentable {
    @Binding var text: String
    @Binding var isFocused: Bool
    let fontSize: CGFloat
    let weight: NSFont.Weight

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSTextField {
        let textField = NSTextField(string: text)
        textField.isEditable = true
        textField.isBordered = false
        textField.drawsBackground = false
        textField.focusRingType = .none
        textField.alignment = .center
        textField.delegate = context.coordinator
        textField.usesSingleLineMode = true
        textField.lineBreakMode = .byTruncatingTail
        textField.font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: weight)
        textField.textColor = NSColor.white
        return textField
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
        nsView.font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: weight)
        nsView.textColor = NSColor.white
        if isFocused, nsView.currentEditor() == nil {
            DispatchQueue.main.async {
                nsView.window?.makeFirstResponder(nsView)
            }
        }
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        private let parent: SelectableTextField

        init(_ parent: SelectableTextField) {
            self.parent = parent
        }

        func controlTextDidBeginEditing(_ obj: Notification) {
            parent.isFocused = true
            guard let field = obj.object as? NSTextField else { return }
            DispatchQueue.main.async {
                field.currentEditor()?.selectAll(nil)
            }
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSTextField else { return }
            parent.text = field.stringValue
        }

        func controlTextDidEndEditing(_ obj: Notification) {
            parent.isFocused = false
            guard let field = obj.object as? NSTextField else { return }
            parent.text = field.stringValue
            field.selectText(nil)
        }
    }
}

// MARK: - Initiatives Strip

struct InitiativesStrip: View {
    @ObservedObject private var initiativeManager = InitiativeManager.shared
    @State private var showingEditPopup = false

    var body: some View {
        HStack(spacing: 6) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(initiativeManager.initiatives) { initiative in
                        InitiativeChip(
                            initiative: initiative,
                            initiativeManager: initiativeManager
                        )
                    }
                }
            }
            .frame(maxWidth: 225) // Shows ~2 items, scroll for more

            Button(action: { showingEditPopup = true }) {
                Image(systemName: "plus")
                    .font(.system(size: 9))
                    .foregroundColor(Color.white.opacity(0.6))
                    .frame(width: 12, height: 12)
                    .background(Circle().stroke(Color.white.opacity(0.3), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showingEditPopup, arrowEdge: .bottom) {
                InitiativeEditPopup(initiativeManager: initiativeManager)
            }
        }
        .frame(height: 12)
    }

    private struct InitiativeChip: View {
        let initiative: Initiative
        @ObservedObject var initiativeManager: InitiativeManager
        @State private var showingSymbolPicker = false
        @State private var showingDatePicker = false
        @State private var isHovering = false
        @State private var showDetails = false

        private static let dateFormatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "MMM d"
            return formatter
        }()

        private var daysLeft: Int {
            let calendar = Calendar.current
            let now = calendar.startOfDay(for: Date())
            let target = calendar.startOfDay(for: initiative.targetDate)
            return calendar.dateComponents([.day], from: now, to: target).day ?? 0
        }

        private var daysLeftText: String {
            let days = daysLeft
            if days < 0 {
                return "\(abs(days))d ago"
            } else if days == 0 {
                return "TODAY"
            } else {
                return "\(days)d"
            }
        }

        private var daysLeftColor: Color {
            let days = daysLeft
            if days < 0 {
                return Color.red.opacity(0.9)  // Overdue
            } else if days <= 3 {
                return Color.red.opacity(0.8)  // Urgent
            } else if days <= 7 {
                return Color.orange.opacity(0.8)  // Soon
            } else {
                return Color.red.opacity(0.6)  // Normal
            }
        }

        var body: some View {
            HStack(spacing: 2) {
                Button(action: { showingSymbolPicker = true }) {
                    Image(systemName: initiative.symbol)
                        .font(.system(size: 9))
                        .foregroundColor(Color.white)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showingSymbolPicker) {
                    SymbolPicker(selected: initiative.symbol) { symbol in
                        initiativeManager.updateSymbol(initiative, symbol: symbol)
                        showingSymbolPicker = false
                    }
                }

                Text(initiative.name)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(Color.white.opacity(0.9))

                Button(action: { showingDatePicker = true }) {
                    Text(daysLeftText)
                        .font(.system(size: 7, weight: .medium, design: .monospaced))
                        .foregroundColor(Color.white)
                        .padding(.horizontal, 3)
                        .padding(.vertical, 1)
                        .background(
                            RoundedRectangle(cornerRadius: 3)
                                .fill(daysLeftColor)
                        )
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showingDatePicker) {
                    DatePicker(
                        "Target Date",
                        selection: Binding(
                            get: { initiative.targetDate },
                            set: { initiativeManager.updateTargetDate(initiative, date: $0) }
                        ),
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .padding(10)
                    .frame(width: 220)
                }
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 1)
            .onHover { hovering in
                isHovering = hovering
                if hovering && !initiative.detail.isEmpty {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        if isHovering { showDetails = true }
                    }
                } else if !hovering {
                    showDetails = false
                }
            }
            .popover(isPresented: $showDetails, arrowEdge: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: initiative.symbol)
                            .font(.system(size: 10))
                            .foregroundColor(.white)
                        Text(initiative.name)
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                    }
                    if !initiative.detail.isEmpty {
                        Text(initiative.detail)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(Color.white.opacity(0.9))
                            .lineLimit(5)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Text("Target: \(Self.dateFormatter.string(from: initiative.targetDate))")
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundColor(Color.white.opacity(0.6))
                }
                .padding(10)
                .frame(minWidth: 150, maxWidth: 250)
            }
        }

    }
}

// MARK: - Symbol Picker (Reusable)

struct SymbolPicker: View {
    let selected: String
    let onSelect: (String) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 8)

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(Self.symbols, id: \.self) { symbol in
                    Button(action: { onSelect(symbol) }) {
                        Image(systemName: symbol)
                            .font(.system(size: 14))
                            .foregroundColor(Color.white)
                            .frame(width: 26, height: 26)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(symbol == selected ? Color.white.opacity(0.2) : Color.clear)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color.white.opacity(symbol == selected ? 0.6 : 0.2), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
        }
        .frame(width: 260, height: 220)
        .background(UniverseTheme.panelBackground)
    }

    private static let symbols: [String] = [
        "sparkles", "star", "star.fill", "star.circle", "moon", "moon.stars", "sun.max", "sun.max.fill",
        "cloud", "cloud.sun", "cloud.rain", "cloud.snow", "snowflake", "wind", "tornado", "drop", "drop.fill",
        "flame", "flame.fill", "bolt", "bolt.fill", "bolt.circle", "bolt.circle.fill", "leaf", "leaf.fill",
        "ant", "ladybug", "hare", "tortoise", "pawprint", "trophy", "medal", "flag", "flag.fill",
        "paperplane", "paperplane.fill", "paperclip", "pin", "pin.fill", "bookmark", "bookmark.fill", "book",
        "book.closed", "graduationcap", "folder", "folder.fill", "doc", "doc.text", "doc.plaintext", "tray",
        "tray.fill", "archivebox", "archivebox.fill", "shippingbox", "shippingbox.fill", "cube", "cube.box",
        "terminal", "keyboard", "display", "tv", "headphones", "music.note", "music.note.list", "mic",
        "camera", "camera.fill", "video", "photo", "paintbrush", "paintbrush.fill", "pencil", "pencil.circle",
        "scissors", "hammer", "wrench", "screwdriver", "ruler", "gearshape", "gearshape.fill", "atom", "globe",
        "network", "antenna.radiowaves.left.and.right", "waveform", "waveform.path", "waveform.path.ecg",
        "heart", "heart.fill", "shield", "lock", "key", "person", "person.fill", "person.2", "person.3",
        "person.crop.circle", "figure.walk", "figure.run", "figure.strengthtraining.traditional", "bicycle",
        "car", "airplane", "tram", "bus", "map", "location", "compass", "magnifyingglass",
        "sparkle.magnifyingglass", "chart.bar", "chart.line.uptrend.xyaxis", "chart.pie", "clock", "alarm",
        "timer", "calendar", "calendar.badge.clock", "sunrise", "sunset", "umbrella", "thermometer",
        "drop.triangle", "bag", "cart", "creditcard", "banknote", "briefcase", "case", "building.2", "house",
        "bed.double", "sofa", "chair", "lamp.table", "lightbulb", "power", "battery.100", "wifi",
        "globe.americas", "globe.europe.africa", "tuningfork", "guitars", "pianokeys", "gamecontroller", "dice",
        "paperplane.circle", "shield.lefthalf.fill", "bolt.slash", "snow", "command", "option", "control", "shift",
        "apple.logo"
    ]
}

// MARK: - Daily Timeline

struct DailyTimeline: View {
    @ObservedObject var habitManager = DailyHabitManager.shared
    @State private var showingEditPopup = false
    @State private var currentTime = Date()
    @State private var wavePhase: CGFloat = 0
    let style: TimelineStyle
    let customRange: (start: Int, end: Int)?

    // Drag states for slot manipulation
    @State private var draggingSlotId: UUID?
    @State private var dragMode: SlotDragMode = .move
    @State private var dragOffset: CGFloat = 0

    enum SlotDragMode {
        case move        // Drag entire slot
        case resizeStart // Drag left edge (changes start time)
        case resizeEnd   // Drag right edge (changes end time)
    }

    init(style: TimelineStyle = .standard, customRange: (start: Int, end: Int)? = nil) {
        self.style = style
        self.customRange = customRange
    }

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private let waveTimer = Timer.publish(every: 0.03, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { geometry in
            let timelineY = style.timelineY
            let slotY = style.slotY
            let slotHeight = style.slotHeight
            let padding = style.padding
            let timelineWidth = geometry.size.width - padding * 2
            let displayRange = displayTimelineRange

            ZStack(alignment: .topLeading) {
                if style.showsTimeLabels {
                    if style.isInline {
                        let labelY = max(1, timelineY - 1)
                        Text(formattedTime(displayRange.start))
                            .font(.system(size: style.timeLabelFontSize, weight: .semibold, design: .monospaced))
                            .foregroundColor(Color.white.opacity(0.9))
                            .offset(x: 8, y: labelY)

                        Text(formattedTime(displayRange.end))
                            .font(.system(size: style.timeLabelFontSize, weight: .semibold, design: .monospaced))
                            .foregroundColor(Color.white.opacity(0.75))
                            .offset(x: geometry.size.width - 38, y: labelY)
                    } else {
                        // Start time label (clickable to adjust)
                        Button(action: { adjustStartTime(by: -60) }) {
                            Text(habitManager.formattedStartTime)
                                .font(.system(size: style.timeLabelFontSize, design: .monospaced))
                                .foregroundColor(Color.white.opacity(0.85))
                        }
                        .buttonStyle(.plain)
                        .offset(x: 8, y: timelineY - 3)

                        // End time label
                        Text("00:00")
                            .font(.system(size: style.timeLabelFontSize, design: .monospaced))
                            .foregroundColor(Color.white.opacity(0.6))
                            .offset(x: geometry.size.width - 38, y: timelineY - 3)
                    }
                }

                // Neon timeline with wave
                NeonWaveLine(
                    width: timelineWidth,
                    wavePhase: wavePhase,
                    currentProgress: currentTimeProgress
                )
                .offset(x: padding, y: timelineY)

                // Current time marker (conditionally shown)
                if style.showsCurrentTimeMarker {
                    currentTimeMarker(timelineWidth: timelineWidth)
                        .offset(x: padding, y: timelineY)
                }

                // Habit slots
                let visibleHabits = habitsInRange(displayRange)
                ForEach(visibleHabits) { habit in
                    HabitSlotView(
                        habit: habit,
                        timelineWidth: timelineWidth,
                        padding: padding,
                        slotY: slotY,
                        slotHeight: slotHeight,
                        timelineY: timelineY,
                        intensity: habitIntensity(habit),
                        isDragging: draggingSlotId == habit.id,
                        dragMode: dragMode,
                        dragOffset: draggingSlotId == habit.id ? dragOffset : 0,
                        isSelected: habitManager.selectedHabitId == habit.id,
                        habitManager: habitManager,
                        style: style,
                        displayRangeStartMinutes: displayRange.start,
                        displayRangeEndMinutes: displayRange.end,
                        onDragStart: { mode in
                            draggingSlotId = habit.id
                            dragMode = mode
                            dragOffset = 0
                        },
                        onDragChange: { offset in
                            dragOffset = offset
                        },
                        onDragEnd: { newStart, newEnd in
                            if dragMode == .move {
                                habitManager.updateHabitTime(habit, minutes: newStart, persist: true)
                            } else if dragMode == .resizeStart {
                                habitManager.updateHabitStart(habit, startMinutes: newStart, persist: true)
                            } else if dragMode == .resizeEnd {
                                habitManager.updateHabitEnd(habit, endMinutes: newEnd, persist: true)
                            }
                            draggingSlotId = nil
                            dragOffset = 0
                        }
                    )
                }

                if style.showsAddButton {
                    // Add button
                    Button(action: { showingEditPopup = true }) {
                        Image(systemName: "plus")
                            .font(.system(size: max(6, style.addButtonSize - 6)))
                            .foregroundColor(Color.white.opacity(0.7))
                            .frame(width: style.addButtonSize, height: style.addButtonSize)
                            .background(Circle().stroke(Color.white.opacity(0.4), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .offset(x: geometry.size.width - (style.addButtonSize + 10), y: slotY + slotHeight / 2 - style.addButtonSize / 2)
                    .popover(isPresented: $showingEditPopup, arrowEdge: .bottom) {
                        HabitEditPopup(habitManager: habitManager)
                    }
                }

                if style.showsAdjustButtons {
                    // Adjust start time buttons
                    HStack(spacing: 4) {
                        Button("-1h") { adjustStartTime(by: -60) }
                            .font(.system(size: 7, design: .monospaced))
                            .foregroundColor(Color.white.opacity(0.6))
                        Button("+1h") { adjustStartTime(by: 60) }
                            .font(.system(size: 7, design: .monospaced))
                            .foregroundColor(Color.white.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                    .offset(x: 6, y: slotY + 2)
                }
            }
        }
        .onReceive(timer) { _ in
            currentTime = Date()
        }
        .onReceive(waveTimer) { _ in
            wavePhase += 0.08
            if wavePhase > 2 * .pi * 10 { wavePhase = 0 }
        }
    }

    private func adjustStartTime(by minutes: Int) {
        habitManager.setTimelineStart(habitManager.timelineStartMinutes + minutes)
    }

    private func formattedTime(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        return String(format: "%02d:%02d", hours % 24, mins)
    }

    private var currentTimeProgress: CGFloat {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: currentTime)
        let minute = calendar.component(.minute, from: currentTime)
        let currentMinutes = hour * 60 + minute

        let displayRange = displayTimelineRange
        let range = CGFloat(displayRange.end - displayRange.start)
        let offset = CGFloat(currentMinutes - displayRange.start)
        if range == 0 { return 0 }
        return offset / range
    }

    private func habitIntensity(_ habit: DailyHabit) -> CGFloat {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: currentTime)
        let minute = calendar.component(.minute, from: currentTime)
        let currentMinutes = hour * 60 + minute

        // Check if current time is within the habit slot
        if currentMinutes >= habit.startMinutes && currentMinutes <= habit.endMinutes {
            return 1.0
        }

        // Otherwise, calculate proximity
        let distToStart = abs(habit.startMinutes - currentMinutes)
        let distToEnd = abs(habit.endMinutes - currentMinutes)
        let closestDist = min(distToStart, distToEnd)
        let maxDiff: CGFloat = 120
        return max(0, 1 - CGFloat(closestDist) / maxDiff)
    }

    @ViewBuilder
    private func currentTimeMarker(timelineWidth: CGFloat) -> some View {
        // Use smooth real-time position (updates at 30 FPS via waveTimer)
        let rawProgress = smoothCurrentTimeProgress
        
        if rawProgress >= 0 && rawProgress <= 1 {
            let clampedProgress = min(max(rawProgress, 0), 1)
            let xPos = clampedProgress * timelineWidth
            let pulse = 0.6 + 0.4 * CGFloat(sin(Double(wavePhase) * 0.5))

            MartianMarker(pulse: pulse)
                .offset(x: xPos - 6, y: 0)  // Position so feet touch the timeline, body above
                .animation(.linear(duration: 0.03), value: xPos)
        }
    }

    /// Smooth time progress using real-time Date() for fluid movement
    private var smoothCurrentTimeProgress: CGFloat {
        let now = Date()
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)
        let second = calendar.component(.second, from: now)
        let nanosecond = calendar.component(.nanosecond, from: now)

        // Calculate precise current time in minutes (with fractional seconds)
        let currentMinutes = CGFloat(hour * 60 + minute) + CGFloat(second) / 60.0 + CGFloat(nanosecond) / 60_000_000_000.0

        let displayRange = displayTimelineRange
        let range = CGFloat(displayRange.end - displayRange.start)
        let offset = currentMinutes - CGFloat(displayRange.start)
        if range == 0 { return 0 }
        return offset / range
    }

    private var displayTimelineRange: (start: Int, end: Int) {
        if let custom = customRange { return custom }
        return (habitManager.timelineStartMinutes, DailyHabitManager.timelineEndMinutes)
    }

    private func habitsInRange(_ range: (start: Int, end: Int)) -> [DailyHabit] {
        // Only show visible (non-hidden) habits
        let visible = habitManager.visibleHabits

        if !style.isInline {
            return visible
        }

        return visible.filter { habit in
            habit.endMinutes >= range.start && habit.startMinutes <= range.end
        }
    }

    // MARK: - Current Time Marker

    private struct MartianMarker: View {
        let pulse: CGFloat

        var body: some View {
            TimelineView(.animation) { context in
                let time = context.date.timeIntervalSince1970
                let frameIndex = Int(time * 10) % 4 // 10 fps
                
                Canvas { context, size in
                    let pixelSize: CGFloat = 1.5
                    let color = Color.white
                    
                    // 4-frame running animation (side profile)
                    // Grid coordinates (x, y)
                    let frames: [[(Int, Int)]] = [
                        // Frame 0: Contact
                        [
                           (3,0),(4,0),(5,0), // Head
                           (3,1),(4,1),(5,1),
                           (4,2),(5,2),
                           (4,3),(5,3),(6,3), // Body + Arm forward
                           (3,4),(4,4),(5,4),
                           (4,5),(5,5),
                           (3,6),(5,6), // Legs
                           (2,7),(6,7),
                           (2,8),(6,8)
                        ],
                        // Frame 1: Recoil
                        [
                           (3,1),(4,1),(5,1), // Head bob down
                           (3,2),(4,2),(5,2),
                           (4,3),(5,3),
                           (4,4),(5,4),(6,4),
                           (3,5),(4,5),(5,5),
                           (4,6),(5,6),
                           (4,7),(4,8), // Leg planted
                           (5,7),(6,6)  // Leg back
                        ],
                        // Frame 2: Passing
                        [
                           (3,0),(4,0),(5,0), // Head up
                           (3,1),(4,1),(5,1),
                           (4,2),(5,2),
                           (4,3),(5,3),(6,3),
                           (3,4),(4,4),(5,4),
                           (4,5),(5,5),
                           (4,6),(5,6),
                           (4,7),(4,8), // Leg support
                           (4,7),(5,8)  // Leg swing
                        ],
                         // Frame 3: Extension
                        [
                           (3,0),(4,0),(5,0),
                           (3,1),(4,1),(5,1),
                           (4,2),(5,2),
                           (4,3),(5,3),(6,3),
                           (3,4),(4,4),(5,4),
                           (4,5),(5,5),
                           (3,6),(6,6), // Legs split wide
                           (2,7),(7,7),
                           (1,8),(8,7)
                        ]
                    ]
                    
                    let pixels = frames[frameIndex]
                    let xOffset: CGFloat = (size.width - 9 * pixelSize) / 2
                    
                    for (x, y) in pixels {
                        let rect = CGRect(
                            x: xOffset + CGFloat(x) * pixelSize,
                            y: CGFloat(y) * pixelSize,
                            width: pixelSize,
                            height: pixelSize
                        )
                        // Rounded corners on pixels for "soft retro" look
                        context.fill(Path(roundedRect: rect, cornerRadius: 0.5), with: .color(color))
                    }
                }
            }
            .frame(width: 18, height: 16)
            .shadow(color: Color.white.opacity(0.8), radius: 4)
            .shadow(color: Color.white.opacity(0.4), radius: 8)
            .allowsHitTesting(false)
        }
    }
}


// MARK: - Right Click Modifier

struct RightClickModifier: ViewModifier {
    let action: () -> Void

    func body(content: Content) -> some View {
        content.overlay(
            RightClickHelper(action: action)
        )
    }
}

struct RightClickHelper: NSViewRepresentable {
    let action: () -> Void

    func makeNSView(context: Context) -> RightClickView {
        let view = RightClickView()
        view.action = action
        return view
    }

    func updateNSView(_ nsView: RightClickView, context: Context) {
        nsView.action = action
    }

    class RightClickView: NSView {
        var action: (() -> Void)?

        override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            // Essential for the view to exist in the hierarchy but be transparent
            self.wantsLayer = true
            self.layer?.backgroundColor = NSColor.clear.cgColor
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func hitTest(_ point: NSPoint) -> NSView? {
            // Check if the point is geometrically within our bounds
            // super.hitTest handles the geometry check (point in superview coords)
            let hitView = super.hitTest(point)
            
            guard hitView == self else { return nil }

            // If we are hit, check the current event type
            if let event = NSApp.currentEvent, event.type == .rightMouseDown {
                return self // Capture right click
            }

            // For all other events (left click, drag, hover), return nil
            // This allows the event to fall through to the view underneath (HabitSlotView)
            return nil
        }

        override func rightMouseDown(with event: NSEvent) {
            // Execute the action instantly
            action?()
        }
    }
}

extension View {
    func onRightClick(_ action: @escaping () -> Void) -> some View {
        self.modifier(RightClickModifier(action: action))
    }
}

// MARK: - Habit Slot View

struct HabitSlotView: View {
    let habit: DailyHabit
    let timelineWidth: CGFloat
    let padding: CGFloat
    let slotY: CGFloat
    let slotHeight: CGFloat
    let timelineY: CGFloat
    let intensity: CGFloat
    let isDragging: Bool
    let dragMode: DailyTimeline.SlotDragMode
    let dragOffset: CGFloat
    let isSelected: Bool
    let habitManager: DailyHabitManager
    let style: TimelineStyle
    let displayRangeStartMinutes: Int
    let displayRangeEndMinutes: Int
    let onDragStart: (DailyTimeline.SlotDragMode) -> Void
    let onDragChange: (CGFloat) -> Void
    let onDragEnd: (Int, Int) -> Void

    // Local state for smooth dragging
    @State private var localDragOffset: CGFloat = 0
    @State private var isLocallyDragging = false
    @State private var isHovering = false

    private var cornerRadius: CGFloat { max(6, slotHeight / 2) }
    private var todoAreaWidth: CGFloat {
        if !style.showsCheckbox { return 0 }
        return max(CGFloat(style.checkboxSize) + 4, slotHeight)
    }
    private var isActive: Bool { isLocallyDragging || isDragging }

    private var startX: CGFloat {
        xFromMinutes(habit.startMinutes)
    }

    private var endX: CGFloat {
        xFromMinutes(habit.endMinutes)
    }

    private var displayStartX: CGFloat {
        guard isActive else { return startX }
        switch dragMode {
        case .move:
            return startX + (isLocallyDragging ? localDragOffset : dragOffset)
        case .resizeStart:
            return startX + (isLocallyDragging ? localDragOffset : dragOffset)
        case .resizeEnd:
            return startX
        }
    }

    private var displayEndX: CGFloat {
        guard isActive else { return endX }
        switch dragMode {
        case .move:
            return endX + (isLocallyDragging ? localDragOffset : dragOffset)
        case .resizeStart:
            return endX
        case .resizeEnd:
            return endX + (isLocallyDragging ? localDragOffset : dragOffset)
        }
    }

    private var textWidth: CGFloat {
        CGFloat(habit.name.count) * style.habitFontSize * 0.6
    }

    private var displayWidth: CGFloat {
        let basePadding: CGFloat = style.habitInnerPadding
        let raw = todoAreaWidth + textWidth + (basePadding * 2)
        let minWidth = todoAreaWidth + 6
        let clamped = max(minWidth, raw)
        return max(1, min(timelineWidth - displayStartX, clamped))
    }

    private var displayStartMinutes: Int {
        minutesFromX(displayStartX)
    }

    private var displayEndMinutes: Int {
        minutesFromX(displayEndX)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            if style.showsSlotMarkers {
                timeMarker(x: displayStartX, label: formattedTime(displayStartMinutes), emphasis: isActive || isHovering)
            }

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(habit.isCompleted ? 0.18 : 0.12),
                                Color.white.opacity(habit.isCompleted ? 0.08 : 0.05),
                                Color.white.opacity(habit.isCompleted ? 0.12 : 0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(
                                isActive || isHovering || isSelected
                                    ? Color.white.opacity(0.9)
                                    : Color.white.opacity(0.3 + intensity * 0.3),
                                lineWidth: 1
                            )
                    )
                    .overlay(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.35),
                                Color.white.opacity(0.05),
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                    )
                    .shadow(color: Color.white.opacity(intensity * 0.25), radius: intensity * 4)
                    .allowsHitTesting(false)

                HStack(alignment: .center, spacing: style.showsCheckbox ? 3 : 2) {
                    if style.showsCheckbox {
                        Button(action: { habitManager.toggleHabit(habit) }) {
                            ZStack {
                                Circle()
                                    .fill(habit.isCompleted ? Color.white.opacity(0.95) : Color.white.opacity(0.12))
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white.opacity(habit.isCompleted ? 0.95 : 0.45), lineWidth: 1)
                                    )
                                if habit.isCompleted {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: max(7, style.checkboxFontSize), weight: .bold))
                                        .foregroundColor(Color.black.opacity(0.85))
                                }
                            }
                            .frame(width: style.checkboxSize + 2, height: style.checkboxSize + 2)
                        }
                        .buttonStyle(.plain)
                        .frame(width: todoAreaWidth, height: slotHeight)
                        .contentShape(Rectangle())
                    }

                    VStack(alignment: .leading, spacing: 0) {
                        Text(habit.name)
                            .font(.system(size: style.habitFontSize, weight: .semibold))
                            .foregroundColor(habit.isCompleted ? Color.white.opacity(0.5) : Color.white.opacity(0.98))
                            .strikethrough(habit.isCompleted, color: Color.white.opacity(0.4))
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)

                    }
                }
                .padding(.horizontal, style.habitInnerPadding)
                .frame(width: displayWidth, height: slotHeight, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture {
                    if !style.showsCheckbox {
                        habitManager.toggleHabit(habit)
                    }
                }

            }
            .frame(width: displayWidth, height: slotHeight)
            .offset(x: padding + displayStartX, y: slotY)
            .highPriorityGesture(moveGesture)
            .simultaneousGesture(
                TapGesture(count: 2)
                    .onEnded {
                        habitManager.hideHabit(habit)
                    }
            )
            .onHover { hovering in
                isHovering = hovering
                if hovering {
                    habitManager.hoveredHabitDetail = habit.detail
                } else {
                    if habitManager.hoveredHabitDetail == habit.detail {
                        habitManager.hoveredHabitDetail = nil
                    }
                }
            }
            .onRightClick {
                habitManager.hideHabit(habit)
            }
        }
    }

    private func xFromMinutes(_ minutes: Int) -> CGFloat {
        let range = CGFloat(displayRangeEndMinutes - displayRangeStartMinutes)
        let offset = CGFloat(minutes - displayRangeStartMinutes)
        if range == 0 { return 0 }
        return (offset / range) * timelineWidth
    }

    private func minutesFromX(_ x: CGFloat) -> Int {
        let clampedX = min(max(0, x), timelineWidth)
        let ratio = clampedX / timelineWidth
        let range = displayRangeEndMinutes - displayRangeStartMinutes
        let minutes = displayRangeStartMinutes + Int(ratio * CGFloat(range))
        return (minutes / 5) * 5 // Round to 5 minutes
    }

    private func formattedTime(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        return String(format: "%02d:%02d", hours % 24, mins)
    }

    private func timeMarker(x: CGFloat, label: String, emphasis: Bool) -> some View {
        let lineHeight = max(0, slotY - timelineY - 6)
        return VStack(spacing: 2) {
            Text(label)
                .font(.system(size: max(7, style.slotTimeLabelFontSize), weight: .semibold, design: .monospaced))
                .foregroundColor(Color.white.opacity(emphasis ? 0.9 : 0.6))
            Capsule()
                .fill(Color.white.opacity(emphasis ? 0.6 : 0.35))
                .frame(width: 2, height: lineHeight)
        }
        .position(x: padding + x, y: timelineY + lineHeight / 2)
    }

    private var moveGesture: some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                if !isLocallyDragging {
                    isLocallyDragging = true
                    onDragStart(.move)
                }
                let duration = habit.durationMinutes
                let proposedStart = minutesFromX(startX + value.translation.width)
                let clampedStart = max(displayRangeStartMinutes, min(displayRangeEndMinutes - duration, proposedStart))
                localDragOffset = xFromMinutes(clampedStart) - startX
            }
            .onEnded { _ in
                onDragEnd(displayStartMinutes, displayEndMinutes)
                isLocallyDragging = false
                localDragOffset = 0
            }
    }

}

// MARK: - MartianSceneView (for 3D astronaut marker)
/*
private struct MartianSceneView: NSViewRepresentable {
    let scene: SCNScene
    let camera: SCNNode
    var debugOptions: SCNDebugOptions = []

    func makeNSView(context: Context) -> SCNView {
        let view = SCNView(frame: NSRect(x: 0, y: 0, width: 48, height: 48))
        view.scene = scene
        view.pointOfView = camera
        view.autoenablesDefaultLighting = true // Enable default lighting as fallback
        view.preferredFramesPerSecond = 60
        view.antialiasingMode = .multisampling4X

        // Ensure transparency
        view.backgroundColor = NSColor.clear
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.clear.cgColor
        view.layer?.isOpaque = false

        // Ensure scene plays
        view.isPlaying = true
        view.loops = true
        view.allowsCameraControl = false
        view.rendersContinuously = true

        view.debugOptions = debugOptions
        return view
    }

    func updateNSView(_ nsView: SCNView, context: Context) {
        nsView.scene = scene
        nsView.pointOfView = camera
        nsView.debugOptions = debugOptions
        // Keep playing
        if !nsView.isPlaying {
            nsView.isPlaying = true
        }
    }
}
*/

// MARK: - Hidden Habits Bucket

struct HiddenHabitsBucket: View {
    @ObservedObject var habitManager: DailyHabitManager
    @State private var isExpanded = false
    @State private var isHoveringPopup = false

    var body: some View {
        let hiddenCount = habitManager.hiddenHabits.count

        if hiddenCount > 0 {
            // Bucket button with popup
            Button(action: { withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { isExpanded.toggle() } }) {
                HStack(spacing: 3) {
                    Image(systemName: isExpanded ? "archivebox.fill" : "archivebox")
                        .font(.system(size: 9))
                    Text("\(hiddenCount)")
                        .font(.system(size: 8, weight: .semibold, design: .monospaced))
                }
                .foregroundColor(Color.white.opacity(0.7))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(isExpanded ? 0.2 : 0.1))
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.25), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)
            .help("Hidden habits (\(hiddenCount)) - Click to show")
            .popover(isPresented: $isExpanded, arrowEdge: .bottom) {
                // Scrollable list of hidden habits
                VStack(alignment: .leading, spacing: 0) {
                    Text("Hidden Habits")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(Color.white.opacity(0.5))
                        .padding(.horizontal, 8)
                        .padding(.top, 6)
                        .padding(.bottom, 4)

                    ScrollView(.vertical, showsIndicators: true) {
                        VStack(alignment: .leading, spacing: 3) {
                            ForEach(habitManager.hiddenHabits) { habit in
                                Button(action: {
                                    habitManager.unhideHabit(habit)
                                    // Close if no more hidden habits
                                    if habitManager.hiddenHabits.isEmpty {
                                        isExpanded = false
                                    }
                                }) {
                                    HStack(spacing: 5) {
                                        Image(systemName: "arrow.uturn.backward.circle")
                                            .font(.system(size: 8))
                                            .foregroundColor(Color.white.opacity(0.5))
                                        Text(habit.name)
                                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                                            .foregroundColor(Color.white.opacity(0.85))
                                            .lineLimit(1)
                                        Spacer()
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 5)
                                    .background(
                                        RoundedRectangle(cornerRadius: 5)
                                            .fill(Color.white.opacity(0.06))
                                    )
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 6)
                        .padding(.bottom, 6)
                    }
                    .frame(width: 140)
                    .frame(maxHeight: 120)
                }
                .background(
                    ZStack {
                        Color(red: 0.02, green: 0.025, blue: 0.08).opacity(0.92)
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.04),
                                Color.clear,
                                Color.black.opacity(0.3)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
                )
                .onHover { hovering in
                    isHoveringPopup = hovering
                    if !hovering {
                        // Close when mouse leaves popup
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            if !isHoveringPopup {
                                withAnimation(.easeOut(duration: 0.15)) {
                                    isExpanded = false
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Neon Wave Line

struct NeonWaveLine: View {
    let width: CGFloat
    let wavePhase: CGFloat
    let currentProgress: CGFloat

    var body: some View {
        ZStack {
            WaveAreaPath(width: width, amplitude: 2.5, frequency: 3, phase: wavePhase)
                .fill(
                    LinearGradient(
                        colors: [
                            UniverseColors.violetBright.opacity(0.25),
                            UniverseColors.violetDeep.opacity(0.12),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .blur(radius: 2)

            // Outer diffuse glow (widest)
            WavePath(width: width, amplitude: 2.5, frequency: 3, phase: wavePhase)
                .stroke(
                    LinearGradient(
                        colors: [
                            UniverseColors.blueDeep.opacity(0.3),
                            UniverseColors.cosmicPurple.opacity(0.5),
                            UniverseColors.violetBright.opacity(0.4),
                            UniverseColors.cosmicPurple.opacity(0.5),
                            UniverseColors.blueDeep.opacity(0.3)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .blur(radius: 8)

            // Mid glow
            WavePath(width: width, amplitude: 2, frequency: 3, phase: wavePhase)
                .stroke(
                    LinearGradient(
                        colors: [
                            UniverseColors.violetDeep.opacity(0.4),
                            UniverseColors.violetBright.opacity(0.7),
                            UniverseColors.cosmicPurple.opacity(0.8),
                            UniverseColors.violetBright.opacity(0.7),
                            UniverseColors.violetDeep.opacity(0.4)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .blur(radius: 4)

            // Inner bright glow
            WavePath(width: width, amplitude: 1.5, frequency: 3, phase: wavePhase)
                .stroke(
                    LinearGradient(
                        colors: [
                            UniverseColors.blueBright.opacity(0.5),
                            UniverseColors.violetBright.opacity(0.9),
                            Color.white.opacity(0.6),
                            UniverseColors.violetBright.opacity(0.9),
                            UniverseColors.blueBright.opacity(0.5)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .blur(radius: 2)

            // Core thin line (brightest)
            WavePath(width: width, amplitude: 1, frequency: 3, phase: wavePhase)
                .stroke(
                    LinearGradient(
                        colors: [
                            UniverseColors.violetBright.opacity(0.8),
                            Color.white.opacity(0.9),
                            UniverseColors.violetBright.opacity(0.8)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
                )
        }
        .frame(height: 30)
    }
}

// MARK: - Wave Path Shape

struct WavePath: Shape {
    let width: CGFloat
    let amplitude: CGFloat
    let frequency: CGFloat
    let phase: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let midY = rect.midY

        path.move(to: CGPoint(x: 0, y: midY))

        for x in stride(from: 0, through: width, by: 1) {
            let relativeX = x / width
            let waveY = sin(Double(relativeX * frequency * .pi * 2 + phase)) * Double(amplitude)
            // Add secondary wave for more organic feel
            let wave2 = sin(Double(relativeX * frequency * 1.7 * .pi * 2 + phase * 0.7)) * Double(amplitude * 0.3)
            let y = midY + CGFloat(waveY + wave2)
            path.addLine(to: CGPoint(x: x, y: y))
        }

        return path
    }
}

struct WaveAreaPath: Shape {
    let width: CGFloat
    let amplitude: CGFloat
    let frequency: CGFloat
    let phase: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let midY = rect.midY

        path.move(to: CGPoint(x: 0, y: midY))

        for x in stride(from: 0, through: width, by: 1) {
            let relativeX = x / width
            let waveY = sin(Double(relativeX * frequency * .pi * 2 + phase)) * Double(amplitude)
            let wave2 = sin(Double(relativeX * frequency * 1.7 * .pi * 2 + phase * 0.7)) * Double(amplitude * 0.3)
            let y = midY + CGFloat(waveY + wave2)
            path.addLine(to: CGPoint(x: x, y: y))
        }

        path.addLine(to: CGPoint(x: width, y: rect.maxY))
        path.addLine(to: CGPoint(x: 0, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Dotted Line Shape

struct DottedLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        return path
    }
}

// MARK: - Habit Chip

struct HabitChip: View {
    let habit: DailyHabit
    let intensity: CGFloat
    let isDragging: Bool
    let isSelected: Bool
    let onToggle: () -> Void
    let onSelect: () -> Void
    @State private var isHovering = false

    var body: some View {
        content
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(backgroundFill)
            .background(borderStroke)
            .shadow(color: Color.white.opacity(intensity * 0.25), radius: intensity * 3)
            .onHover { isHovering = $0 }
            .scaleEffect(isDragging ? 1.1 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isDragging)
    }

    private var content: some View {
        HStack(spacing: 4) {
            toggleButton
            nameLabel
        }
    }

    private var toggleButton: some View {
        Button(action: onToggle) {
            Image(systemName: habit.isCompleted ? "checkmark.square.fill" : "square")
                .font(.system(size: 8))
                .foregroundColor(habit.isCompleted ? Color.white : Color.white.opacity(0.6))
                .frame(width: 16, height: 16)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var nameLabel: some View {
        Text(habit.name)
            .font(.system(size: 8, design: .monospaced))
            .foregroundColor(habit.isCompleted ? Color.white.opacity(0.7) : Color.white.opacity(0.9))
            .strikethrough(habit.isCompleted, color: Color.white.opacity(0.5))
            .lineLimit(1)
            .contentShape(Rectangle())
            .onTapGesture(perform: onSelect)
    }

    private var backgroundFill: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(habit.isCompleted ? Color.white.opacity(0.12) : Color.white.opacity(0.05 + intensity * 0.08))
    }

    private var borderStroke: some View {
        RoundedRectangle(cornerRadius: 3)
            .stroke(
                isHovering || isDragging || isSelected ? Color.white : Color.white.opacity(0.25 + intensity * 0.3),
                lineWidth: 1
            )
    }
}

struct HabitEditPopup: View {
    @ObservedObject var habitManager: DailyHabitManager
    @Environment(\.dismiss) var dismiss
    @State private var newHabitName = ""
    @State private var editingHabit: DailyHabit?
    @State private var editingName = ""

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("HABITS")
                    .font(UniverseTheme.monoFontLarge)
                    .foregroundColor(.white)
                Spacer()
                Button("Done") { dismiss() }
                    .font(UniverseTheme.monoFont)
                    .foregroundColor(.white.opacity(0.9))
            }

            Text("Drag habits on timeline to reschedule")
                .font(UniverseTheme.monoFontSmall)
                .foregroundColor(.white.opacity(0.6))

            // Add new habit
            HStack {
                TextField("New habit...", text: $newHabitName)
                    .textFieldStyle(.plain)
                    .font(UniverseTheme.monoFont)
                    .padding(8)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(4)

                Button(action: addHabit) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                .disabled(newHabitName.isEmpty)
            }

            Divider()
                .background(Color.white.opacity(0.2))

            // Existing habits
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(habitManager.habits) { habit in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                // Time badge
                                Text(habit.formattedTime)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.8))
                                    .frame(width: 45)

                                if editingHabit?.id == habit.id {
                                    TextField("Name", text: $editingName, onCommit: saveEdit)
                                        .textFieldStyle(.plain)
                                        .font(UniverseTheme.monoFont)
                                } else {
                                    Text(habit.name)
                                        .font(UniverseTheme.monoFont)
                                        .foregroundColor(.white.opacity(0.9))
                                }

                                Spacer()

                                if editingHabit?.id == habit.id {
                                    Button("Save") { saveEdit() }
                                        .font(UniverseTheme.monoFontSmall)
                                        .foregroundColor(.white)
                                } else {
                                    Button(action: { startEditing(habit) }) {
                                        Image(systemName: "pencil")
                                            .foregroundColor(.white.opacity(0.6))
                                    }
                                    .buttonStyle(.plain)
                                }

                                Button(action: { habitManager.deleteHabit(habit) }) {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red.opacity(0.7))
                                }
                                .buttonStyle(.plain)
                            }

                            TextField(
                                "Detail...",
                                text: Binding(
                                    get: { habit.detail },
                                    set: { habitManager.updateHabitDetail(habit, detail: $0) }
                                )
                            )
                            .textFieldStyle(.plain)
                            .font(UniverseTheme.monoFontSmall)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(3)
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.white.opacity(0.05))
                        )
                    }
                }
            }
        }
        .padding(20)
        .frame(width: 400, height: 400)
        .background(
            ZStack {
                // Frosted glass effect
                GlassBackground(material: .hudWindow, blendingMode: .behindWindow)
                Color.black.opacity(0.3)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .preferredColorScheme(.dark)
    }

    private func addHabit() {
        guard !newHabitName.isEmpty else { return }
        habitManager.addHabit(name: newHabitName)
        newHabitName = ""
    }

    private func startEditing(_ habit: DailyHabit) {
        editingHabit = habit
        editingName = habit.name
    }

    private func saveEdit() {
        guard let habit = editingHabit, !editingName.isEmpty else {
            editingHabit = nil
            return
        }
        habitManager.updateHabit(habit, name: editingName)
        editingHabit = nil
    }
}

struct InitiativeEditPopup: View {
    @ObservedObject var initiativeManager: InitiativeManager
    @Environment(\.dismiss) var dismiss
    @State private var newName = ""
    @State private var editingId: UUID?
    @State private var editingName = ""

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("INITIATIVES")
                    .font(UniverseTheme.monoFontLarge)
                    .foregroundColor(.white)
                Spacer()
                Button("Done") { dismiss() }
                    .font(UniverseTheme.monoFont)
                    .foregroundColor(.white.opacity(0.9))
            }

            // Add new
            HStack {
                TextField("New initiative...", text: $newName)
                    .textFieldStyle(.plain)
                    .font(UniverseTheme.monoFont)
                    .padding(8)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(4)

                Button(action: add) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                .disabled(newName.isEmpty)
            }

            Divider()
                .background(Color.white.opacity(0.2))

            // List
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(initiativeManager.initiatives) { initiative in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Image(systemName: initiative.symbol)
                                    .font(.system(size: 12))
                                    .foregroundColor(.white)

                                if editingId == initiative.id {
                                    TextField("Name", text: $editingName, onCommit: saveEdit)
                                        .textFieldStyle(.plain)
                                        .font(UniverseTheme.monoFont)
                                } else {
                                    Text(initiative.name)
                                        .font(UniverseTheme.monoFont)
                                        .foregroundColor(.white.opacity(0.9))
                                }

                                Spacer()

                                if editingId == initiative.id {
                                    Button("Save") { saveEdit() }
                                        .font(UniverseTheme.monoFontSmall)
                                        .foregroundColor(.white)
                                } else {
                                    Button(action: { startEditing(initiative) }) {
                                        Image(systemName: "pencil")
                                            .foregroundColor(.white.opacity(0.6))
                                    }
                                    .buttonStyle(.plain)
                                }

                                Button(action: { initiativeManager.deleteInitiative(initiative) }) {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red.opacity(0.7))
                                }
                                .buttonStyle(.plain)
                            }

                            // Detail / Description
                            TextField(
                                "Description (tooltip)...",
                                text: Binding(
                                    get: { initiative.detail },
                                    set: { initiativeManager.updateDetail(initiative, detail: $0) }
                                )
                            )
                            .textFieldStyle(.plain)
                            .font(UniverseTheme.monoFontSmall)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(3)
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.white.opacity(0.05))
                        )
                    }
                }
            }
        }
        .padding(20)
        .frame(width: 400, height: 400)
        .background(
            ZStack {
                // Frosted glass effect
                GlassBackground(material: .hudWindow, blendingMode: .behindWindow)
                Color.black.opacity(0.3)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .preferredColorScheme(.dark)
    }

    private func add() {
        guard !newName.isEmpty else { return }
        initiativeManager.addInitiative(name: newName)
        newName = ""
    }

    private func startEditing(_ initiative: Initiative) {
        editingId = initiative.id
        editingName = initiative.name
    }

    private func saveEdit() {
        if let id = editingId,
           let initiative = initiativeManager.initiatives.first(where: { $0.id == id }),
           !editingName.isEmpty {
            initiativeManager.updateInitiative(initiative, name: editingName)
        }
        editingId = nil
    }
}

// MARK: - Controls Section

struct ControlsSection: View {
    @EnvironmentObject var layoutManager: WindowLayoutManager

    var body: some View {
        HStack(spacing: 8) {
            // Toolbar toggle button
            TriangleButton(
                direction: .down,
                isActive: layoutManager.isToolbarMinimized,
                label: "BAR"
            ) {
                layoutManager.toggleToolbar()
            }
        }
        .padding(.horizontal, 12)
        .frame(maxHeight: .infinity)
    }
}

struct QuickLaunchDropDelegate: DropDelegate {
    let item: QuickLaunchButton
    @Binding var currentItems: [QuickLaunchButton]
    let onMove: (IndexSet, Int) -> Void

    func performDrop(info: DropInfo) -> Bool {
        return true
    }

    func dropEntered(info: DropInfo) {
        guard let itemProvider = info.itemProviders(for: [.text]).first else { return }
        
        itemProvider.loadItem(forTypeIdentifier: "public.text", options: nil) { (data, error) in
            DispatchQueue.main.async {
                guard let data = data as? Data,
                      let idString = String(data: data, encoding: .utf8),
                      let fromIndex = currentItems.firstIndex(where: { $0.id.uuidString == idString }),
                      let toIndex = currentItems.firstIndex(of: item),
                      fromIndex != toIndex else { return }
                
                withAnimation {
                    // Calculate correct offset
                    let offset = toIndex > fromIndex ? toIndex + 1 : toIndex
                    onMove(IndexSet(integer: fromIndex), offset)
                }
            }
        }
    }
    
    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .move)
    }
}

// MARK: - Editable Quick Launch Button

struct EditableQuickLaunchButton: View {
    let button: QuickLaunchButton
    @ObservedObject var quickLaunchManager: QuickLaunchManager
    @State private var isHovering = false
    @State private var showingEditor = false
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: {
            // Simply launch the app
            quickLaunchManager.launchApp(button)
        }) {
            VStack(spacing: 2) {
                if NSImage(systemSymbolName: button.icon, accessibilityDescription: nil) != nil {
                    Image(systemName: button.icon)
                        .font(.system(size: 14))
                } else {
                    Text(button.icon)
                        .font(.system(size: 12, design: .monospaced))
                }

                Text(button.name)
                    .font(.system(size: 8, design: .monospaced))
            }
            .foregroundColor(
                !isEnabled ? UniverseTheme.textSecondary.opacity(0.5) :
                isHovering ? UniverseTheme.accent : UniverseTheme.textPrimary
            )
            .glassGlow(radius: isHovering ? 6 : 0, opacity: 0.5)
            .frame(width: 44, height: 36)
            .background(
                RoundedRectangle(cornerRadius: 3)
                    .stroke(
                        !isEnabled ? UniverseTheme.border.opacity(0.5) :
                        isHovering ? UniverseTheme.accent : UniverseTheme.border,
                        lineWidth: 1
                    )
                    .glassGlow(radius: isHovering ? 4 : 0, opacity: 0.3)
            )
            .background(
                RoundedRectangle(cornerRadius: 3)
                    .fill(isHovering && isEnabled ? UniverseTheme.accentDim.opacity(0.3) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
        .contextMenu {
            Button("Edit...") {
                showingEditor = true
            }
            Divider()
            Button("Delete", role: .destructive) {
                quickLaunchManager.deleteButton(button)
            }
        }
        .popover(isPresented: $showingEditor) {
            QuickLaunchEditorView(
                button: button,
                quickLaunchManager: quickLaunchManager,
                onDismiss: { showingEditor = false }
            )
        }
    }
}

// MARK: - Quick Launch Editor

struct QuickLaunchEditorView: View {
    let button: QuickLaunchButton
    @ObservedObject var quickLaunchManager: QuickLaunchManager
    let onDismiss: () -> Void

    @State private var name: String = ""
    @State private var icon: String = ""
    @State private var selectedAppPath: String = ""
    @State private var shortcutString: String = ""
    @State private var scannedApps: [(name: String, bundleId: String, icon: String)] = []
    @State private var showingSymbolPicker = false
    @State private var searchText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Edit Quick Launch")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(Color.white)

            VStack(alignment: .leading, spacing: 6) {
                Text("NAME")
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundColor(Color.white.opacity(0.6))

                TextField("Name", text: $name)
                    .textFieldStyle(.plain)
                    .font(.system(size: 10, design: .monospaced))
                    .padding(6)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(4)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("ICON")
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundColor(Color.white.opacity(0.6))

                HStack {
                    TextField("Icon", text: $icon)
                        .textFieldStyle(.plain)
                        .font(.system(size: 10, design: .monospaced))
                        .padding(6)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(4)
                    
                    Button(action: { showingSymbolPicker.toggle() }) {
                        Image(systemName: "square.grid.2x2")
                            .font(.system(size: 12))
                            .foregroundColor(Color.white.opacity(0.7))
                            .frame(width: 24, height: 24)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showingSymbolPicker) {
                        SymbolPicker(selected: icon) { symbol in
                            icon = symbol
                            showingSymbolPicker = false
                        }
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text("SHORTCUT (Optional)")
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundColor(Color.white.opacity(0.6))

                TextField("e.g. cmd+shift+p", text: $shortcutString)
                    .textFieldStyle(.plain)
                    .font(.system(size: 10, design: .monospaced))
                    .padding(6)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(4)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("APP")
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundColor(Color.white.opacity(0.6))
                
                TextField("Search apps...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 9, design: .monospaced))
                    .padding(6)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(4)

                ScrollView {
                    VStack(spacing: 4) {
                        let filteredApps = searchText.isEmpty ? scannedApps : scannedApps.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
                        
                        ForEach(filteredApps, id: \.bundleId) { app in
                            Button(action: {
                                selectedAppPath = app.bundleId
                                if icon.isEmpty || icon == "★" { icon = app.icon }
                                if name.isEmpty || name == "NEW" { name = app.name.uppercased() }
                            }) {
                                HStack {
                                    Text(app.icon)
                                        .font(.system(size: 12))
                                    Text(app.name)
                                        .font(.system(size: 9, design: .monospaced))
                                    Spacer()
                                    if selectedAppPath == app.bundleId {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 8))
                                    }
                                }
                                .foregroundColor(Color.white.opacity(selectedAppPath == app.bundleId ? 1 : 0.7))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(selectedAppPath == app.bundleId ? Color.white.opacity(0.15) : Color.clear)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(height: 150)

                // Custom app bundle ID input
                TextField("Or enter bundle ID...", text: $selectedAppPath)
                    .textFieldStyle(.plain)
                    .font(.system(size: 9, design: .monospaced))
                    .padding(6)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(4)
            }

            HStack {
                Button("Cancel") {
                    onDismiss()
                }
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(Color.white.opacity(0.7))

                Spacer()

                Button("Save") {
                    quickLaunchManager.updateButton(
                        button,
                        name: name.isEmpty ? button.name : name,
                        icon: icon.isEmpty ? button.icon : icon,
                        appBundleId: selectedAppPath.isEmpty ? button.appBundleId : selectedAppPath,
                        shortcutString: shortcutString.isEmpty ? nil : shortcutString
                    )
                    onDismiss()
                }
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(UniverseTheme.accent)
            }
        }
        .padding(16)
        .frame(width: 280)
        .background(UniverseTheme.panelBackground)
        .preferredColorScheme(.dark)
        .onAppear {
            name = button.name
            icon = button.icon
            selectedAppPath = button.appBundleId
            shortcutString = button.shortcutString ?? ""
            scanApplications()
        }
    }
    
    private func scanApplications() {
        DispatchQueue.global(qos: .userInitiated).async {
            let fileManager = FileManager.default
            let appDirs = ["/Applications", "/System/Applications"]
            var foundApps: [(name: String, bundleId: String, icon: String)] = []
            
            // Add Universe Modes
            foundApps.append(("Craft Mode", "universe.mode.craft", "C"))
            foundApps.append(("Graph Mode", "universe.mode.graph", "▦"))
            foundApps.append(("Dev Mode", "com.googlecode.iterm2", "⌘"))
            foundApps.append(("Web Mode", "company.thebrowser.Browser", "⌥"))
            foundApps.append(("Music Mode", "com.spotify.client", "♪"))

            for dir in appDirs {
                guard let contents = try? fileManager.contentsOfDirectory(atPath: dir) else { continue }
                for item in contents where item.hasSuffix(".app") {
                    let path = (dir as NSString).appendingPathComponent(item)
                    if let bundle = Bundle(path: path),
                       let bundleId = bundle.bundleIdentifier,
                       let info = bundle.infoDictionary,
                       let name = info["CFBundleName"] as? String {
                         // Simple heuristic for icon - just use first letter or generic
                        foundApps.append((name, bundleId, String(name.prefix(1))))
                    }
                }
            }
            
            DispatchQueue.main.async {
                self.scannedApps = foundApps.sorted { $0.name < $1.name }
            }
        }
    }
}

struct TerminalButton: View {
    let label: String
    let icon: String
    var isActive: Bool = false
    var shortcut: String? = nil
    let action: () -> Void

    @State private var isHovering = false
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(icon)
                    .font(.system(size: 12, design: .monospaced))

                Text(label)
                    .font(.system(size: 8, design: .monospaced))
            }
            .foregroundColor(
                !isEnabled ? UniverseTheme.textSecondary.opacity(0.5) :
                isActive ? UniverseTheme.accent :
                isHovering ? UniverseTheme.accent : UniverseTheme.textPrimary
            )
            .glassGlow(radius: isActive || isHovering ? 6 : 0, opacity: 0.5) // Glow content
            .frame(width: 44, height: 36)
            .background(
                RoundedRectangle(cornerRadius: 3)
                    .stroke(
                        !isEnabled ? UniverseTheme.border.opacity(0.5) :
                        isActive ? UniverseTheme.accent :
                        isHovering ? UniverseTheme.accent : UniverseTheme.border,
                        lineWidth: 1
                    )
                    .glassGlow(radius: isActive || isHovering ? 4 : 0, opacity: 0.3) // Glow border
            )
            .background(
                RoundedRectangle(cornerRadius: 3)
                    .fill(isHovering && isEnabled ? UniverseTheme.accentDim.opacity(0.3) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

struct TriangleButton: View {
    enum Direction {
        case down, right, up, left
    }

    let direction: Direction
    var isActive: Bool = false
    let label: String
    let action: () -> Void

    @State private var isHovering = false
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            VStack(spacing: 1) {
                TriangleShape(direction: direction)
                    .fill(
                        !isEnabled ? UniverseTheme.textSecondary.opacity(0.3) :
                        isActive ? UniverseTheme.accent :
                        isHovering ? UniverseTheme.accent : UniverseTheme.textPrimary
                    )
                    .frame(width: 14, height: 10)

                Text(label)
                    .font(.system(size: 6, design: .monospaced))
                    .foregroundColor(
                        !isEnabled ? UniverseTheme.textSecondary.opacity(0.5) :
                        isActive ? UniverseTheme.accent :
                        isHovering ? UniverseTheme.accent : UniverseTheme.textSecondary
                    )
            }
            .frame(width: 22, height: 36)
            .background(
                isHovering && isEnabled ? UniverseTheme.accentDim.opacity(0.2) : Color.clear
            )
            .overlay(
                Rectangle()
                    .stroke(
                        !isEnabled ? UniverseTheme.border.opacity(0.3) :
                        isActive ? UniverseTheme.accent.opacity(0.5) :
                        isHovering ? UniverseTheme.accent.opacity(0.5) : UniverseTheme.border.opacity(0.5),
                        lineWidth: 0.5
                    )
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

struct TriangleShape: Shape {
    let direction: TriangleButton.Direction

    func path(in rect: CGRect) -> Path {
        var path = Path()
        switch direction {
        case .down:
            path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        case .right:
            path.move(to: CGPoint(x: rect.maxX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        case .up:
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        case .left:
            path.move(to: CGPoint(x: rect.minX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        }
        path.closeSubpath()
        return path
    }
}


// MARK: - Legacy ContentView (for compatibility)

struct ContentView: View {
    @EnvironmentObject var layoutManager: WindowLayoutManager

    var body: some View {
        MainWindowView()
            .environmentObject(layoutManager)
    }
}

#Preview {
    MainWindowView()
        .environmentObject(WindowLayoutManager.shared)
        .frame(width: 1200, height: 800)
}
