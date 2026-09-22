import Foundation
import SwiftData

@Model
final class TodoItem {
    @Attribute(.unique) var id: UUID
    var title: String
    var note: String
    var dueDate: Date?
    var remindAt: Date?
    var isFlagged: Bool
    var isDone: Bool
    var createdAt: Date
    var completedAt: Date?

    init(
        id: UUID = UUID(),
        title: String,
        note: String = "",
        dueDate: Date? = nil,
        remindAt: Date? = nil,
        isFlagged: Bool = false,
        isDone: Bool = false,
        createdAt: Date = .now,
        completedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.note = note
        self.dueDate = dueDate
        self.remindAt = remindAt
        self.isFlagged = isFlagged
        self.isDone = isDone
        self.createdAt = createdAt
        self.completedAt = completedAt
    }

    func setDone(_ done: Bool) {
        isDone = done
        completedAt = done ? .now : nil
    }

    /// Day bucket used by the week strip and the day filter.
    var dueDay: Date? {
        dueDate.map { Calendar.current.startOfDay(for: $0) }
    }
}
