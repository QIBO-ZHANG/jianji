import SwiftUI
import SwiftData

struct LedgerEditorView: View {
    let itemID: UUID?

    @Environment(\.modelContext) private var context
    @Environment(AppRouter.self) private var router

    @State private var editing: LedgerEntry?
    @State private var kind: LedgerKind = .expense
    @State private var category: LedgerCategory = .dining
    @State private var amount: Decimal = 0
    @State private var date = Date.now
    @State private var note = ""

    private var isCreating: Bool { editing == nil }
    private var canSave: Bool { amount > 0 }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("类型", selection: $kind) {
                        ForEach(LedgerKind.allCases) { kind in
                            Text(kind.label).tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                }
                Section("分类") {
                    Picker("分类", selection: $category) {
                        ForEach(LedgerCategory.cases(for: kind)) { category in
                            Label(category.label, systemImage: category.systemImage).tag(category)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }
                Section("金额") {
                    TextField("0.00", value: $amount, format: .number)
                        .keyboardType(.decimalPad)
                        .accessibilityLabel("金额")
                    DatePicker("日期", selection: $date, displayedComponents: .date)
                }
                Section("备注") {
                    TextField("备注（可选）", text: $note)
                }
            }
            .navigationTitle(isCreating ? "新建记账" : "编辑记账")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { router.dismissSheet() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", action: save).disabled(!canSave)
                }
            }
            .onAppear(perform: load)
            .onChange(of: kind) { _, newKind in
                guard !LedgerCategory.cases(for: newKind).contains(category) else { return }
                category = LedgerCategory.cases(for: newKind)[0]
            }
        }
    }

    private func load() {
        guard let itemID else { return }
        let descriptor = FetchDescriptor<LedgerEntry>(predicate: #Predicate { $0.id == itemID })
        guard let entry = try? context.fetch(descriptor).first else { return }
        editing = entry
        kind = entry.kind
        category = entry.category
        amount = entry.amount
        date = entry.date
        note = entry.note
    }

    private func save() {
        if let editing {
            editing.kind = kind
            editing.category = category
            editing.amount = amount
            editing.date = date
            editing.note = note
        } else {
            context.insert(LedgerEntry(amount: amount, kind: kind, category: category, date: date, note: note))
        }
        try? context.save()
        router.dismissSheet()
    }
}
