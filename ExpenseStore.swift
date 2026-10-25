import Foundation
import Combine

enum ExpenseCategory: String, CaseIterable, Codable, Identifiable {
    case food = "餐饮", travel = "交通", shopping = "购物", other = "其他"
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .food: return "fork.knife"
        case .travel: return "bus.fill"
        case .shopping: return "bag.fill"
        case .other: return "ellipsis"
        }
    }
}

struct Expense: Identifiable, Codable {
    var id = UUID()
    let amountCents: Int
    let category: ExpenseCategory
    let note: String
    var date = Date()

    // 以整数“分”保存金额，避免使用浮点数计算人民币。
    static func parseCents(_ input: String) -> Int? {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.range(of: #"^[0-9]{1,7}(\.[0-9]{1,2})?$"#,
                         options: .regularExpression) != nil else { return nil }
        let parts = text.split(separator: ".")
        guard let yuan = Int(parts[0]) else { return nil }
        let fraction = parts.count == 2 ? String(parts[1]) : ""
        let cents = Int(fraction.padding(toLength: 2, withPad: "0", startingAt: 0)) ?? 0
        let result = yuan * 100 + cents
        return result > 0 ? result : nil
    }

    static func money(_ cents: Int) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.numberStyle = .currency
        formatter.currencyCode = "CNY"
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        let value = NSDecimalNumber(value: cents).dividing(by: NSDecimalNumber(value: 100))
        return formatter.string(from: value) ?? "¥0.00"
    }
}

@MainActor
final class ExpenseStore: ObservableObject {
    @Published private(set) var expenses: [Expense] = []
    @Published var showingError = false
    @Published private(set) var errorMessage = ""
    private(set) var canEdit = true
    private let fileURL: URL

    var totalCents: Int { expenses.reduce(0) { $0 + $1.amountCents } }

    init() {
        fileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("expenses.json")
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let saved = try JSONDecoder().decode([Expense].self, from: Data(contentsOf: fileURL))
            guard saved.allSatisfy({ $0.amountCents > 0 && $0.amountCents <= 999_999_999 }),
                  Set(saved.map(\.id)).count == saved.count else {
                throw CocoaError(.fileReadCorruptFile)
            }
            expenses = saved.sorted { $0.date > $1.date }
        } catch {
            canEdit = false
            errorMessage = "无法读取已保存的账本。为保护原文件，已暂停新增和删除。请保留应用数据，勿直接卸载。"
            showingError = true
        }
    }

    @discardableResult
    func add(amountCents: Int, category: ExpenseCategory, note: String) -> Bool {
        guard amountCents > 0, amountCents <= 999_999_999 else { return false }
        let entry = Expense(amountCents: amountCents, category: category,
                            note: String(note.trimmingCharacters(in: .whitespacesAndNewlines).prefix(40)))
        return persist([entry] + expenses)
    }

    func remove(id: UUID) {
        _ = persist(expenses.filter { $0.id != id })
    }

    private func persist(_ updated: [Expense]) -> Bool {
        guard canEdit else { return false }
        do {
            let data = try JSONEncoder().encode(updated)
            try data.write(to: fileURL, options: .atomic)
            // 先保存成功，再更新页面；保存失败时保留原记录。
            expenses = updated
            return true
        } catch {
            errorMessage = "保存失败，原记录未变更。请检查设备剩余空间后重试。"
            showingError = true
            return false
        }
    }
}
