import SwiftUI

@main
struct ColorSudokuApp: App {
    @StateObject private var store: StoreManager
    @StateObject private var ads: AdsManager
    @StateObject private var game = GameViewModel()

    init() {
        let store = StoreManager()
        _store = StateObject(wrappedValue: store)
        _ads = StateObject(wrappedValue: AdsManager(store: store))
    }

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(store)
                .environmentObject(ads)
                .environmentObject(game)
                .task {
                    // Check the purchase first so paying users never see a consent form or an ad.
                    await store.refreshEntitlements()
                    ads.startIfNeeded()
                }
        }
    }
}
