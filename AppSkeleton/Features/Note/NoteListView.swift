import SwiftUI
import SwiftData

struct NoteListView: View {
    @State private var search = ""
    @Environment(AppRouter.self) private var router

    var body: some View {
        NoteResultsView(search: search)
            .background(Theme.Palette.background.ignoresSafeArea())
            .navigationTitle(AppTab.note.title)
            .searchable(text: $search, prompt: "搜索记录")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        router.present(.noteEditor(nil))
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("新建记录")
                }
            }
    }
}

private struct NoteResultsView: View {
    @Query private var notes: [NoteItem]
    @Environment(AppRouter.self) private var router
    @Environment(\.modelContext) private var context
    private let search: String

    init(search: String) {
        self.search = search
        if search.isEmpty {
            _notes = Query(sort: \NoteItem.updatedAt, order: .reverse)
        } else {
            _notes = Query(
                filter: #Predicate<NoteItem> {
                    $0.title.localizedStandardContains(search) || $0.body.localizedStandardContains(search)
                },
                sort: \NoteItem.updatedAt,
                order: .reverse
            )
        }
    }

    var body: some View {
        Group {
            if notes.isEmpty {
                if search.isEmpty {
                    ContentUnavailableView(
                        "暂无记录",
                        systemImage: "pencil.and.scribble",
                        description: Text("点右上角 + 写点什么")
                    )
                } else {
                    ContentUnavailableView.search(text: search)
                }
            } else {
                List {
                    ForEach(notes) { note in
                        NoteRow(note: note)
                            .listRowBackground(Theme.Palette.surface)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    context.delete(note)
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }
                            }
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
    }
}

private struct NoteRow: View {
    let note: NoteItem
    @Environment(AppRouter.self) private var router

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(note.title.isEmpty ? "无标题" : note.title)
                .font(Theme.Typography.headline)
                .accessibilityIdentifier("note.row.\(note.id.uuidString)")
            if !note.body.isEmpty {
                Text(note.body)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Palette.secondaryLabel)
                    .lineLimit(2)
            }
            Text(note.updatedAt.formatted(.dateTime.month().day().hour().minute()))
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Palette.secondaryLabel)
        }
        .padding(.vertical, 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture { router.present(.noteEditor(note.id)) }
    }
}
