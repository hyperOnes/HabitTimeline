import Cocoa
import ApplicationServices

enum AppWindowKind {
    case craft
    case iterm
    case atlas
    case spotify
    case weather
}

/// Represents a managed external window
struct CraftWindow: Identifiable, Equatable {
    let id: Int
    let title: String
    let axElement: AXUIElement
    var frame: NSRect
    let appKind: AppWindowKind

    static func == (lhs: CraftWindow, rhs: CraftWindow) -> Bool {
        lhs.id == rhs.id && lhs.appKind == rhs.appKind
    }
}
