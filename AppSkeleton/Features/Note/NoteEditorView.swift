import SwiftUI
import SwiftData

struct NoteEditorView: View {
    let itemID: UUID?

    @Environment(\.modelContext) private var context
    @Environment(AppRouter.self) private var router

    @State private var editing: NoteItem?
    @State private var title = ""
    @State private var bodyText = ""

    private var isCreating: Bool { editing == nil }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("标题", text: $title)
                }
                Section("正文") {
                    TextEditor(text: $bodyText)
                        .frame(minHeight: 220)
                        .accessibilityLabel("正文")
                }
            }
            .navigationTitle(isCreating ? "新建记录" : "编辑记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { router.dismissSheet() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", action: save)
                        .disabled(
                            title.trimmingCharacters(in: .whitespaces).isEmpty
                                && bodyText.trimmingCharacters(in: .whitespaces).isEmpty
                        )
                }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        guard let itemID else { return }
        let descriptor = FetchDescriptor<NoteItem>(predicate: #Predicate { $0.id == itemID })
        guard let note = try? context.fetch(descriptor).first else { return }
        editing = note
        title = note.title
        bodyText = note.body
    }

    private func save() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        if let editing {
            editing.title = trimmedTitle
            editing.body = bodyText
            editing.touch()
        } else {
            context.insert(NoteItem(title: trimmedTitle, body: bodyText))
        }
        try? context.save()
        router.dismissSheet()
    }
}
