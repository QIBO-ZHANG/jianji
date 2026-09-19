import Foundation

/// Every destination pushable on a tab stack. Adding a feature means adding one case
/// here plus one branch in `RouteDestination`.
enum AppRoute: Hashable, Sendable {
    case scaffoldCheck
}

extension AppRoute {
    var navigationTitle: String {
        switch self {
        case .scaffoldCheck: "Scaffold"
        }
    }
}

/// Where an external/universal link should land: which tab plus an optional push.
/// Unknown links decode to nil so the caller can fall back to opening them in a browser.
struct DeepLink: Hashable, Sendable {
    let tab: AppTab
    let route: AppRoute?

    static func from(url: URL) -> DeepLink? {
        guard let scheme = url.scheme?.lowercased(), scheme == "appskeleton" || scheme == "https" else { return nil }
        switch url.host ?? url.path {
        case "scaffold", "/scaffold": return DeepLink(tab: .mine, route: .scaffoldCheck)
        case "todo", "/todo": return DeepLink(tab: .todo, route: nil)
        case "note", "/note": return DeepLink(tab: .note, route: nil)
        case "ledger", "/ledger": return DeepLink(tab: .ledger, route: nil)
        case "mine", "/mine": return DeepLink(tab: .mine, route: nil)
        default: return nil
        }
    }
}
