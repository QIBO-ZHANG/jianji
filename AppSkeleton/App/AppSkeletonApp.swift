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
                .task { Self.seedDemoDataIfRequested(modelContainer) }
        }
    }

    /// DEBUG-only screenshot fixture: `SKELETON_SEED_TODO=1` fills an empty store
    /// with sample todos shaped like the 首页 mockup; `force` wipes todos first;
    /// `clear` only wipes.
    #if DEBUG
    static func seedDemoDataIfRequested(_ container: ModelContainer) {
        let mode = ProcessInfo.processInfo.environment["SKELETON_SEED_TODO"] ?? ""
        guard mode == "1" || mode == "force" || mode == "clear" else { return }
        // mainContext so @Query snapshots see the writes immediately — a fresh
        // ModelContext saving this early can race the queries' first snapshot.
        let context = container.mainContext
        if mode == "force" || mode == "clear" {
            try? context.delete(model: TodoItem.self)
            try? context.save()
        }
        if mode == "clear" { return }
        let existing = (try? context.fetchCount(FetchDescriptor<TodoItem>())) ?? -1
        print("[seed] mode=\(mode) existing=\(existing)")
        guard existing == 0 else { return }

        let calendar = Calendar.current
        let today = calendar.date(bySettingHour: 14, minute: 30, second: 0, of: .now) ?? .now
        var remindAt = today
        if remindAt < .now { remindAt = calendar.date(byAdding: .day, value: 1, to: remindAt) ?? .now }

        context.insert(TodoItem(
            title: "给客户打电话，询问十一假期前的进度，要汇报给领导确认",
            dueDate: today,
            remindAt: remindAt,
            isFlagged: true
        ))
        context.insert(TodoItem(title: "整理项目资料", dueDate: today, isFlagged: true))
        context.insert(TodoItem(title: "预约下周会议室"))
        context.insert(TodoItem(title: "阅读产品调研报告"))

        let donePhone = TodoItem(title: "给客户打电话", dueDate: today, remindAt: remindAt, isFlagged: true)
        donePhone.setDone(true)
        context.insert(donePhone)

        let doneReport = TodoItem(title: "提交报销材料", isFlagged: true)
        doneReport.setDone(true)
        context.insert(doneReport)

        try? context.save()
    }
    #endif
}
