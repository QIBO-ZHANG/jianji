import Foundation

/// The four top-level modules. Adding a module means adding a case here plus a
/// `Tab` entry in `RootView`.
enum AppTab: String, CaseIterable, Identifiable, Sendable {
    case todo
    case note
    case ledger
    case mine

    var id: String { rawValue }

    var title: String {
        switch self {
        case .todo: "待办"
        case .note: "记录"
        case .ledger: "记账"
        case .mine: "设置"
        }
    }

    var systemImage: String {
        switch self {
        case .todo: "checkmark"
        case .note: "pencil.and.scribble"
        case .ledger: "yensign.circle"
        case .mine: "gearshape"
        }
    }
}
