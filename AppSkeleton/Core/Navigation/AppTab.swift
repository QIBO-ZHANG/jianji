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
        case .note: "便签"
        case .ledger: "记账"
        case .mine: "我的"
        }
    }

    var systemImage: String {
        switch self {
        case .todo: "checklist"
        case .note: "note.text"
        case .ledger: "yensign.circle"
        case .mine: "person.crop.circle"
        }
    }
}
