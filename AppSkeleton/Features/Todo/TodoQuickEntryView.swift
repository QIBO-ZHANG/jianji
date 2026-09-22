import SwiftUI
import SwiftData

/// 快捷新建待办 per the 新建待办 mockup: a compact bottom sheet with the title
/// field on top and one accessory row — reminder toggle, due date+time pill
/// (compact DatePicker), flag toggle — and a round send button. Editing an
/// existing todo keeps using the full editor.
struct TodoQuickEntryView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let defaultDay: Date

    @State private var title = ""
    @State private var due: Date
    @State private var hasReminder = false
    @State private var isFlagged = false
    @FocusState private var titleFocused: Bool

    init(defaultDay: Date) {
        self.defaultDay = defaultDay
        _due = State(initialValue: Calendar.current.date(bySettingHour: 14, minute: 30, second: 0, of: defaultDay) ?? defaultDay)
    }

    var body: some View {
        VStack(spacing: 0) {
            TextField("请输入待办", text: $title, axis: .vertical)
                .lineLimit(1...3)
                .font(.body.weight(.medium))
                .padding(.horizontal, Theme.Spacing.large.rawValue)
                .padding(.vertical, Theme.Spacing.medium.rawValue)
                .focused($titleFocused)
                .accessibilityLabel("标题")
                .onSubmit(save)

            Divider()
                .padding(.horizontal, Theme.Spacing.large.rawValue)

            HStack(spacing: Theme.Spacing.medium.rawValue) {
                Button {
                    hasReminder.toggle()
                } label: {
                    Image(systemName: hasReminder ? "bell.fill" : "bell.slash.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(hasReminder ? Theme.Palette.primary : Theme.Palette.secondaryLabel)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(Theme.Palette.secondaryLabel.opacity(0.15)))
                }
                .accessibilityLabel("提醒")
                .accessibilityValue(hasReminder ? "开" : "关")

                DatePicker(selection: $due, displayedComponents: [.date, .hourAndMinute]) { EmptyView() }
                    .labelsHidden()
                    .environment(\.locale, Locale(identifier: "zh_CN"))

                Button {
                    isFlagged.toggle()
                } label: {
                    Image(systemName: isFlagged ? "flag.fill" : "flag")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(isFlagged ? Theme.Palette.flag : Theme.Palette.secondaryLabel)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(Theme.Palette.secondaryLabel.opacity(0.15)))
                }
                .accessibilityLabel("标旗")
                .accessibilityValue(isFlagged ? "开" : "关")

                Spacer(minLength: 0)

                Button(action: save) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(
                            Circle().fill(title.isEmpty ? Theme.Palette.secondaryLabel.opacity(0.4) : Theme.Palette.primary)
                        )
                }
                // Empty title + send = cancel, so the sheet always has a
                // tappable way out even with the keyboard up.
                .accessibilityLabel("保存")
            }
            .padding(.horizontal, Theme.Spacing.large.rawValue)
            .padding(.vertical, Theme.Spacing.medium.rawValue)
        }
        .presentationDetents([.height(180)])
        .presentationDragIndicator(.hidden)
        .onAppear { titleFocused = true }
    }

    private func save() {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            dismiss()
            return
        }
        let item = TodoItem(title: trimmed, dueDate: due, remindAt: hasReminder ? due : nil, isFlagged: isFlagged)
        context.insert(item)
        try? context.save()
        if hasReminder {
            Task {
                if await ReminderScheduler.requestAuthorization() {
                    ReminderScheduler.schedule(for: item)
                }
            }
        }
        dismiss()
    }
}
