import SwiftUI
import SwiftData

struct TodoEditorView: View {
    let itemID: UUID?

    @Environment(\.modelContext) private var context
    @Environment(AppRouter.self) private var router

    @State private var editing: TodoItem?
    @State private var title = ""
    @State private var note = ""
    @State private var hasDueDate = false
    @State private var dueDate = Date.now

    private var isCreating: Bool { editing == nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("内容") {
                    TextField("标题", text: $title)
                    TextField("备注", text: $note, axis: .vertical)
                        .lineLimit(2...5)
                }
                Section("截止日期") {
                    Toggle("设置截止日期", isOn: $hasDueDate)
                    if hasDueDate {
                        DatePicker("日期", selection: $dueDate, displayedComponents: .date)
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
        hasDueDate = item.dueDate != nil
        dueDate = item.dueDate ?? .now
    }

    private func save() {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        if let editing {
            editing.title = trimmed
            editing.note = note
            editing.dueDate = hasDueDate ? dueDate : nil
        } else {
            context.insert(TodoItem(title: trimmed, note: note, dueDate: hasDueDate ? dueDate : nil))
        }
        try? context.save()
        router.dismissSheet()
    }
}
