import SwiftUI
import SwiftData

struct MineView: View {
    @Query private var todos: [TodoItem]
    @Query private var notes: [NoteItem]
    @Query private var entries: [LedgerEntry]

    @Environment(AppRouter.self) private var router
    @Environment(\.modelContext) private var context

    @State private var confirmClear = false

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    var body: some View {
        List {
            Section {
                HStack(spacing: Theme.Spacing.medium.rawValue) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 52))
                        .foregroundStyle(Theme.Palette.primary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("简记")
                            .font(Theme.Typography.title)
                        Text("待办 · 便签 · 记账")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Palette.secondaryLabel)
                    }
                }
                .padding(.vertical, Theme.Spacing.small.rawValue)
            }

            Section("数据概览") {
                LabeledContent("待办", value: "\(todos.count) 条")
                LabeledContent("便签", value: "\(notes.count) 条")
                LabeledContent("账目", value: "\(entries.count) 笔")
            }

            Section("数据管理") {
                Button("清空全部数据", role: .destructive) {
                    confirmClear = true
                }
            }

            Section("开发") {
                Button("架构自检") {
                    router.push(.scaffoldCheck)
                }
            }

            Section("关于") {
                LabeledContent("版本", value: version)
                LabeledContent("设计", value: "iOS 27 原生组件")
            }
        }
        .navigationTitle(AppTab.mine.title)
        .confirmationDialog(
            "清空后无法恢复",
            isPresented: $confirmClear,
            titleVisibility: .visible
        ) {
            Button("确认清空", role: .destructive, action: clearAll)
        }
    }

    private func clearAll() {
        try? context.delete(model: TodoItem.self)
        try? context.delete(model: NoteItem.self)
        try? context.delete(model: LedgerEntry.self)
        try? context.save()
    }
}
