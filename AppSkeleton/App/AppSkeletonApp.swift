import SwiftUI
import SwiftData

@main
struct AppSkeletonApp: App {
    private let services = ServiceContainer.live()
    private let modelContainer = ModelStore.make()
    @State private var router = AppRouter()

    var body: some Scene {
        WindowGroup {
            RootView()
                .services(services)
                .environment(router)
                .modelContainer(modelContainer)
        }
    }
}
