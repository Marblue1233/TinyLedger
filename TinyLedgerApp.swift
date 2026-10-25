import SwiftUI

@main
@MainActor
struct TinyLedgerApp: App {
    @StateObject private var store = ExpenseStore()

    var body: some Scene {
        WindowGroup {
            ContentView(store: store)
                .tint(Color(red: 0.06, green: 0.48, blue: 0.40))
        }
    }
}
