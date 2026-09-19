import SwiftUI
import SwiftData

struct TodoListView: View {
    @Query(sort: \TodoItem.createdAt, order: .reverse) private var items: [TodoItem]
    @Environment(AppRouter.self) private var router
    @Environment(\.modelContext) private var context

    var body: some View {
        Group {
            if items.isEmpty {
                ContentUnavailableView(
                    "暂无待办",
                    systemImage: "checklist",
                    description: Text("点右上角 + 记下第一件要做的事")
                )
            } else {
                List {
                    ForEach(items) { item in
                        TodoRow(item: item)
                    }
                }
            }
        }
        .navigationTitle(AppTab.todo.title)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    router.present(.todoEditor(nil))
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("新建待办")
            }
        }
    }
}

private struct TodoRow: View {
    let item: TodoItem
    @Environment(AppRouter.self) private var router
    @Environment(\.modelContext) private var context

    var body: some View {
        HStack(spacing: Theme.Spacing.medium.rawValue) {
            Button {
                withAnimation(.snappy) { item.setDone(!item.isDone) }
            } label: {
                Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(item.isDone ? Theme.Palette.primary : Theme.Palette.secondaryLabel)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(item.isDone ? "标记为未完成" : "标记为已完成")
            .accessibilityIdentifier("todo.toggle.\(item.title)")

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .strikethrough(item.isDone, color: Theme.Palette.secondaryLabel)
                    .foregroundStyle(item.isDone ? Theme.Palette.secondaryLabel : Theme.Palette.label)
                    .accessibilityIdentifier("todo.row.\(item.title)")
                    .accessibilityValue(item.isDone ? "已完成" : "进行中")
                if let dueDate = item.dueDate {
                    Label(dueDate.formatted(.dateTime.month().day()), systemImage: "calendar")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Palette.secondaryLabel)
                }
            }
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
        .onTapGesture { router.present(.todoEditor(item.id)) }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                context.delete(item)
            } label: {
                Label("删除", systemImage: "trash")
            }
        }
        .accessibilityElement(children: .contain)
    }
}
