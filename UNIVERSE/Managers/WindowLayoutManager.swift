import Cocoa
import Combine

/// Simplified layout manager - manages only toolbar state
class WindowLayoutManager: ObservableObject {
    static let shared = WindowLayoutManager()

    @Published var isToolbarMinimized = false

    private init() {}

    // MARK: - Toolbar

    func toggleToolbar() {
        isToolbarMinimized.toggle()
    }


}
