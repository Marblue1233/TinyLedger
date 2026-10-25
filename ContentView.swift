import SwiftUI

struct ContentView: View {
    @ObservedObject var store: ExpenseStore
    @State private var showingAdd = false
    @State private var pendingDelete: Expense?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("累计支出", systemImage: "creditcard")
                            .font(.subheadline)
                        Text(Expense.money(store.totalCents))
                            .font(.system(size: 36, weight: .semibold, design: .rounded))
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)
                            .monospacedDigit()
                        Text("共 \(store.expenses.count) 笔 · 简单记录每一笔")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .listRowBackground(Color(red: 0.88, green: 0.95, blue: 0.91))

                Section("支出记录") {
                    if store.expenses.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "square.and.pencil")
                                .font(.system(size: 32)).foregroundStyle(.tint)
                            Text("还没有记账").font(.headline)
                            Text("点右上角＋，记下第一笔支出。")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 36)
                    } else {
                        ForEach(store.expenses) { expense in
                            expenseRow(expense)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) { pendingDelete = expense } label: {
                                        Label("删除", systemImage: "trash")
                                    }
                                    .disabled(!store.canEdit)
                                }
                        }
                    }
                }
                Section {
                    Text("仅记录支出 · 数据保存在本机")
                        .font(.footnote).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }.listRowBackground(Color.clear)
            }
            .navigationTitle("小账本")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showingAdd = true } label: { Image(systemName: "plus") }
                        .accessibilityLabel("新增支出")
                        .disabled(!store.canEdit)
                }
            }
            .sheet(isPresented: $showingAdd) {
                AddExpenseView(store: store)
            }
            .confirmationDialog("删除这笔支出？", isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ), titleVisibility: .visible) {
                if let expense = pendingDelete {
                    Button("删除 \(Expense.money(expense.amountCents))", role: .destructive) {
                        store.remove(id: expense.id)
                        pendingDelete = nil
                    }
                }
                Button("取消", role: .cancel) { pendingDelete = nil }
            }
            .alert("账本提示", isPresented: Binding(
                get: { store.showingError && !showingAdd },
                set: { if !$0 { store.showingError = false } }
            )) {
                Button("好", role: .cancel) {}
            } message: { Text(store.errorMessage) }
        }
    }

    private func expenseRow(_ expense: Expense) -> some View {
        HStack(spacing: 12) {
            Image(systemName: expense.category.symbol)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.tint)
                .frame(width: 42, height: 42)
                .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 13))
            VStack(alignment: .leading, spacing: 5) {
                Text(expense.note.isEmpty ? expense.category.rawValue : expense.note)
                    .font(.body).lineLimit(2)
                Text("\(expense.category.rawValue) · \(expense.date.formatted(.dateTime.month().day().hour().minute()))")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Text("−\(Expense.money(expense.amountCents))")
                .font(.system(.body, design: .rounded).weight(.semibold))
                .monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
        }.padding(.vertical, 5)
    }
}

struct AddExpenseView: View {
    @ObservedObject var store: ExpenseStore
    @Environment(\.dismiss) private var dismiss
    @State private var amount = ""
    @State private var category = ExpenseCategory.food
    @State private var note = ""
    @FocusState private var amountFocused: Bool

    private var amountCents: Int? { Expense.parseCents(amount) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(alignment: .firstTextBaseline) {
                        Text("¥").font(.title2).foregroundStyle(.secondary)
                        TextField("0.00", text: $amount)
                            .font(.system(size: 36, weight: .medium, design: .rounded))
                            .keyboardType(.decimalPad)
                            .focused($amountFocused)
                            .accessibilityLabel("支出金额")
                    }.padding(.vertical, 10)
                } header: { Text("支出金额") } footer: {
                    Text("金额大于 0，最多两位小数，最高 9,999,999.99 元。")
                }
                Section {
                    Picker("分类", selection: $category) {
                        ForEach(ExpenseCategory.allCases) { item in
                            Label(item.rawValue, systemImage: item.symbol).tag(item)
                        }
                    }
                    TextField("备注（可不填，最多40字）", text: $note)
                        .onChange(of: note) { value in
                            if value.count > 40 { note = String(value.prefix(40)) }
                        }
                }
                Section {
                    Button {
                        guard let cents = amountCents else { return }
                        if store.add(amountCents: cents, category: category, note: note) { dismiss() }
                    } label: {
                        Text("保存这笔支出").fontWeight(.semibold)
                            .frame(maxWidth: .infinity).padding(.vertical, 7)
                    }
                    .disabled(amountCents == nil || !store.canEdit)
                }
            }
            .navigationTitle("记一笔")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("取消") { dismiss() } }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完成") { amountFocused = false }
                }
            }
            .alert("保存失败", isPresented: $store.showingError) {
                Button("好", role: .cancel) {}
            } message: { Text(store.errorMessage) }
        }
    }
}
