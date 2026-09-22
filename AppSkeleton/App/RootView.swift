import SwiftUI

/// Hosts the tab bar and one navigation stack per tab. A feature adds its destination
/// in `RouteDestination` and gets stack, sheet and deep-link handling for free.
struct RootView: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.services) private var services

    var body: some View {
        @Bindable var router = router

        TabView(selection: $router.selectedTab) {
            Tab(AppTab.todo.title, systemImage: AppTab.todo.systemImage, value: AppTab.todo) {
                TodoTabRoot()
            }
            Tab(AppTab.note.title, systemImage: AppTab.note.systemImage, value: AppTab.note) {
                NoteTabRoot()
            }
            Tab(AppTab.ledger.title, systemImage: AppTab.ledger.systemImage, value: AppTab.ledger) {
                LedgerTabRoot()
            }
            Tab(AppTab.mine.title, systemImage: AppTab.mine.systemImage, value: AppTab.mine) {
                MineTabRoot()
            }
        }
        .sheet(item: $router.activeSheet) { sheet in
            sheetView(for: sheet)
        }
        .onOpenURL { url in
            if !router.open(url) {
                services.logger.info("Unhandled link: \(url.absoluteString)")
            }
        }
    }

    @ViewBuilder
    private func sheetView(for sheet: AppSheet) -> some View {
        switch sheet {
        case .todoEditor(let id):
            TodoEditorView(itemID: id)
        case .noteEditor(let id):
            NoteEditorView(itemID: id)
        case .ledgerEditor(let id):
            LedgerEditorView(itemID: id)
        }
    }
}

/// Shared push destinations for every tab stack.
struct RouteDestination: View {
    let route: AppRoute

    var body: some View {
        switch route {
        case .scaffoldCheck:
            ScaffoldCheckView()
        }
    }
}

struct TodoTabRoot: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        NavigationStack(path: router.pathBinding(for: .todo)) {
            TodoListView()
                .navigationDestination(for: AppRoute.self) { RouteDestination(route: $0) }
        }
    }
}

struct NoteTabRoot: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        NavigationStack(path: router.pathBinding(for: .note)) {
            NoteListView()
                .navigationDestination(for: AppRoute.self) { RouteDestination(route: $0) }
        }
    }
}

struct LedgerTabRoot: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        NavigationStack(path: router.pathBinding(for: .ledger)) {
            LedgerListView()
                .navigationDestination(for: AppRoute.self) { RouteDestination(route: $0) }
        }
    }
}

struct MineTabRoot: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        NavigationStack(path: router.pathBinding(for: .mine)) {
            SettingsView()
                .navigationDestination(for: AppRoute.self) { RouteDestination(route: $0) }
        }
    }
}
