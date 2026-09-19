import Foundation
import Observation
import SwiftUI

/// Owns navigation state: the selected tab, one back-stack per tab, and the modal sheet.
/// Views call intent methods instead of mutating bindings, which keeps back-stack rules
/// in one place.
@MainActor
@Observable
final class AppRouter {
    var selectedTab: AppTab = .todo
    var paths: [AppTab: [AppRoute]] = [:]
    var activeSheet: AppSheet?

    init() {
        #if DEBUG
        if let raw = ProcessInfo.processInfo.environment["SKELETON_PREVIEW_TAB"],
           let tab = AppTab(rawValue: raw) {
            selectedTab = tab
        }
        #endif
    }

    /// Back-stack of the selected tab.
    var path: [AppRoute] {
        get { paths[selectedTab, default: []] }
        set { paths[selectedTab] = newValue }
    }

    /// Binding for a specific tab's stack, for `NavigationStack(path:)`.
    func pathBinding(for tab: AppTab) -> Binding<[AppRoute]> {
        Binding(
            get: { self.paths[tab, default: []] },
            set: { self.paths[tab] = $0 }
        )
    }

    func push(_ route: AppRoute) {
        path.append(route)
    }

    func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    func popToRoot() {
        path.removeAll()
    }

    func replaceTop(with route: AppRoute) {
        if path.isEmpty { push(route) } else { path[path.count - 1] = route }
    }

    func present(_ sheet: AppSheet) {
        guard activeSheet == nil else { return }
        activeSheet = sheet
    }

    func dismissSheet() {
        activeSheet = nil
    }

    /// Entry point for universal links, widgets and push notifications.
    @discardableResult
    func open(_ url: URL) -> Bool {
        guard let link = DeepLink.from(url: url) else { return false }
        selectedTab = link.tab
        paths[link.tab] = link.route.map { [$0] } ?? []
        return true
    }
}

/// Modal destinations. `nil` payload means "create", a UUID means "edit that record".
enum AppSheet: Hashable, Identifiable, Sendable {
    case todoEditor(UUID?)
    case noteEditor(UUID?)
    case ledgerEditor(UUID?)

    var id: AppSheet { self }
}
