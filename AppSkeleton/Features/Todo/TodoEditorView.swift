import SwiftUI
import SwiftData

struct TodoEditorView: View {
    let itemID: UUID?

    @Environment(\.modelContext) private var context
    @Environment(AppRouter.self) private var router

    @State private var editing: TodoItem?
    @State private var title = ""
    @State private var note = ""
    @State private var isFlagged = false
    @State private var hasDueDate = false
    @State private var dueDate = Date.now
    @State private var hasReminder = false
    @State private var remindAt = Date.now.addingTimeInterval(3600)
    @State private var reminderDenied = false

    private var isCreating: Bool { editing == nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("内容") {
                    TextField("标题", text: $title)
                    TextField("备注", text: $note, axis: .vertical)
                        .lineLimit(2...5)
                    Toggle(isOn: $isFlagged) {
                        Label("标旗", systemImage: "flag.fill")
                            .foregroundStyle(Theme.Palette.flag)
                    }
                    .tint(Theme.Palette.flag)
                }
                Section("截止日期") {
                    Toggle("设置截止日期", isOn: $hasDueDate.animation())
                    if hasDueDate {
                        DatePicker("日期", selection: $dueDate, displayedComponents: .date)
                    }
                }
                Section {
                    Toggle("提醒我", isOn: $hasReminder.animation())
                    if hasReminder {
                        DatePicker("提醒时间", selection: $remindAt, displayedComponents: [.date, .hourAndMinute])
                    }
                } footer: {
                    if reminderDenied {
                        Label("通知权限被关闭，提醒不会弹出。请在系统设置中开启。", systemImage: "exclamationmark.triangle")
                            .foregroundStyle(Theme.Palette.negative)
                    } else if hasReminder {
                        Text("到点会发送本地通知")
                    }
                }
            }
            .navigationTitle(isCreating ? "新建待办" : "编辑待办")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { router.dismissSheet() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", action: save)
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        guard let itemID else { return }
        let descriptor = FetchDescriptor<TodoItem>(predicate: #Predicate { $0.id == itemID })
        guard let item = try? context.fetch(descriptor).first else { return }
        editing = item
        title = item.title
        note = item.note
        isFlagged = item.isFlagged
        hasDueDate = item.dueDate != nil
        dueDate = item.dueDate ?? .now
        hasReminder = item.remindAt != nil
        remindAt = item.remindAt ?? .now.addingTimeInterval(3600)
    }

    private func save() {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        let newDueDate = hasDueDate ? dueDate : nil
        let newRemindAt = hasReminder ? remindAt : nil

        let target: TodoItem
        if let editing {
            editing.title = trimmed
            editing.note = note
            editing.isFlagged = isFlagged
            editing.dueDate = newDueDate
            editing.remindAt = newRemindAt
            target = editing
        } else {
            let item = TodoItem(
                title: trimmed,
                note: note,
                dueDate: newDueDate,
                remindAt: newRemindAt,
                isFlagged: isFlagged
            )
            context.insert(item)
            target = item
        }
        try? context.save()
        syncReminder(for: target)
        router.dismissSheet()
    }

    private func syncReminder(for item: TodoItem) {
        guard item.remindAt != nil, !item.isDone else {
            ReminderScheduler.cancel(for: item)
            return
        }
        Task {
            let granted = await ReminderScheduler.requestAuthorization()
            reminderDenied = !granted
            if granted {
                ReminderScheduler.sync(item)
            }
        }
    }
}
