import StoreKit
import SwiftUI

/// Handles the one-time "Remove Ads" non-consumable in-app purchase (StoreKit 2).
@MainActor
final class StoreManager: ObservableObject {
    /// Must match the product you create in App Store Connect (and ColorSudoku.storekit for local testing).
    static let removeAdsProductID = "com.example.colorsudoku.removeads"
    private static let cacheKey = "adsRemoved"

    /// Cached in UserDefaults so ads stay hidden on launch even before StoreKit answers (or when offline).
    @Published private(set) var adsRemoved: Bool {
        didSet { UserDefaults.standard.set(adsRemoved, forKey: Self.cacheKey) }
    }
    @Published private(set) var removeAdsProduct: Product?
    @Published private(set) var isPurchasing = false
    @Published var errorMessage: String?

    private var updatesTask: Task<Void, Never>?

    init() {
        adsRemoved = UserDefaults.standard.bool(forKey: Self.cacheKey)
        // Purchases can complete outside the app (Ask to Buy, other devices, refunds): listen for them.
        updatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                await self?.handle(result)
            }
        }
        Task { await loadProducts() }
    }

    deinit { updatesTask?.cancel() }

    var priceText: String { removeAdsProduct?.displayPrice ?? "" }

    func loadProducts() async {
        do {
            removeAdsProduct = try await Product.products(for: [Self.removeAdsProductID]).first
        } catch {
            print("StoreKit: failed to load products: \(error)")
        }
    }

    func purchaseRemoveAds() async {
        if removeAdsProduct == nil { await loadProducts() }
        guard let product = removeAdsProduct else {
            errorMessage = "The store is unavailable right now. Please try again later."
            return
        }
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            switch try await product.purchase() {
            case .success(let verification):
                await handle(verification)
            case .pending:
                errorMessage = "Your purchase is pending approval."
            case .userCancelled:
                break
            @unknown default:
                break
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// "Restore Purchases" — required by App Review for non-consumables.
    func restorePurchases() async {
        do {
            try await AppStore.sync()
        } catch {
            errorMessage = error.localizedDescription
        }
        await refreshEntitlements()
        if !adsRemoved, errorMessage == nil {
            errorMessage = "No previous purchase was found for this Apple ID."
        }
    }

    func refreshEntitlements() async {
        var owned = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == Self.removeAdsProductID,
               transaction.revocationDate == nil {
                owned = true
            }
        }
        adsRemoved = owned
    }

    private func handle(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = result else { return } // ignore unverified (tampered) transactions
        if transaction.productID == Self.removeAdsProductID {
            adsRemoved = transaction.revocationDate == nil
        }
        await transaction.finish()
    }
}
