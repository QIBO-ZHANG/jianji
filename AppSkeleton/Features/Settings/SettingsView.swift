import SwiftUI
import SwiftData
import UIKit

struct SettingsView: View {
    @Query private var todos: [TodoItem]
    @Query private var notes: [NoteItem]
    @Query private var entries: [LedgerEntry]

    @Environment(AppRouter.self) private var router
    @Environment(\.modelContext) private var context
    @Environment(\.openURL) private var openURL

    @State private var confirmClear = false

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    var body: some View {
        Form {
            Section {
                HStack(spacing: Theme.Spacing.medium.rawValue) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(Theme.Palette.primary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("简记")
                            .font(Theme.Typography.title)
                        Text("待办 · 记录 · 记账")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Palette.secondaryLabel)
                    }
                }
                .padding(.vertical, Theme.Spacing.small.rawValue)
            }
            .listRowBackground(Theme.Palette.surface)

            Section("数据概览") {
                LabeledContent("待办", value: "\(todos.count) 条")
                LabeledContent("记录", value: "\(notes.count) 条")
                LabeledContent("账目", value: "\(entries.count) 笔")
            }
            .listRowBackground(Theme.Palette.surface)

            Section("通知") {
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                } label: {
                    Label("系统通知设置", systemImage: "bell.badge")
                }
            }
            .listRowBackground(Theme.Palette.surface)

            Section("数据管理") {
                Button("清空全部数据", role: .destructive) {
                    confirmClear = true
                }
            }
            .listRowBackground(Theme.Palette.surface)

            Section("开发") {
                Button("架构自检") {
                    router.push(.scaffoldCheck)
                }
            }
            .listRowBackground(Theme.Palette.surface)

            Section("关于") {
                LabeledContent("版本", value: version)
                LabeledContent("设计", value: "iOS 27 原生组件")
            }
            .listRowBackground(Theme.Palette.surface)
        }
        .scrollContentBackground(.hidden)
        .background(Theme.Palette.background.ignoresSafeArea())
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
        ReminderScheduler.cancelAll()
    }
}
