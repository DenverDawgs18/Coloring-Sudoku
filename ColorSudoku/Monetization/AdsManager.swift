import SwiftUI
import AppTrackingTransparency
#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif
#if canImport(UserMessagingPlatform)
import UserMessagingPlatform
#endif

enum AdConfig {
    // These are Google's public TEST ad unit IDs. Replace them (and GADApplicationIdentifier in
    // Info.plist) with your own AdMob IDs before submitting to the App Store.
    static let bannerUnitID = "ca-app-pub-3940256099942544/2435281174"
    static let interstitialUnitID = "ca-app-pub-3940256099942544/4411468910"

    /// Show an interstitial at most every N completed puzzles…
    static let puzzlesBetweenInterstitials = 2
    /// …and never more often than this.
    static let minimumSecondsBetweenInterstitials: TimeInterval = 180
}

/// Gathers ad consent (GDPR / US state privacy via Google UMP, then Apple ATT),
/// starts the Google Mobile Ads SDK and manages interstitials.
/// Does nothing at all once the user has bought "Remove Ads".
@MainActor
final class AdsManager: NSObject, ObservableObject {
    /// True once the SDK is running and ads may be requested.
    @Published private(set) var isReady = false
    /// True when the user must be offered a way to change their privacy choices (Settings screen).
    @Published private(set) var privacyOptionsRequired = false

    private let store: StoreManager
    private var hasStarted = false
    private var puzzlesSinceInterstitial = 0
    private var lastInterstitialDate = Date.distantPast

    #if canImport(GoogleMobileAds)
    private var interstitial: InterstitialAd?
    #endif

    init(store: StoreManager) {
        self.store = store
        super.init()
    }

    var adsEnabled: Bool { !store.adsRemoved }

    func startIfNeeded() {
        guard adsEnabled, !hasStarted else { return }
        hasStarted = true

        #if canImport(UserMessagingPlatform)
        ConsentInformation.shared.requestConsentInfoUpdate(with: RequestParameters()) { [weak self] error in
            Task { @MainActor in
                guard let self else { return }
                if let error { print("UMP: consent info update failed: \(error)") }
                guard let presenter = UIApplication.topViewController else {
                    await self.finishConsent()
                    return
                }
                ConsentForm.loadAndPresentIfRequired(from: presenter) { [weak self] error in
                    if let error { print("UMP: consent form error: \(error)") }
                    Task { @MainActor in await self?.finishConsent() }
                }
            }
        }
        // Consent obtained in a previous session lets us start right away.
        startSDKIfAllowed()
        #else
        Task { await finishConsent() }
        #endif
    }

    private func finishConsent() async {
        #if canImport(UserMessagingPlatform)
        privacyOptionsRequired = ConsentInformation.shared.privacyOptionsRequirementStatus == .required
        #endif
        if ATTrackingManager.trackingAuthorizationStatus == .notDetermined {
            _ = await ATTrackingManager.requestTrackingAuthorization()
        }
        startSDKIfAllowed()
    }

    private func startSDKIfAllowed() {
        guard adsEnabled, !isReady else { return }
        #if canImport(GoogleMobileAds)
        #if canImport(UserMessagingPlatform)
        guard ConsentInformation.shared.canRequestAds else { return }
        #endif
        MobileAds.shared.start { _ in }
        isReady = true
        loadInterstitial()
        #endif
    }

    func presentPrivacyOptions() {
        #if canImport(UserMessagingPlatform)
        guard let presenter = UIApplication.topViewController else { return }
        ConsentForm.presentPrivacyOptionsForm(from: presenter) { error in
            if let error { print("UMP: privacy options error: \(error)") }
        }
        #endif
    }

    // MARK: Interstitials

    /// Call after each completed puzzle, once the win screen has been dismissed.
    func puzzleFinished() {
        guard adsEnabled, isReady else { return }
        puzzlesSinceInterstitial += 1
        guard puzzlesSinceInterstitial >= AdConfig.puzzlesBetweenInterstitials,
              Date().timeIntervalSince(lastInterstitialDate) >= AdConfig.minimumSecondsBetweenInterstitials
        else { return }

        #if canImport(GoogleMobileAds)
        guard let ad = interstitial, let presenter = UIApplication.topViewController else {
            loadInterstitial()
            return
        }
        puzzlesSinceInterstitial = 0
        lastInterstitialDate = Date()
        interstitial = nil
        ad.present(from: presenter)
        #endif
    }

    private func loadInterstitial() {
        #if canImport(GoogleMobileAds)
        guard adsEnabled, interstitial == nil else { return }
        InterstitialAd.load(with: AdConfig.interstitialUnitID, request: Request()) { [weak self] ad, error in
            Task { @MainActor in
                guard let self else { return }
                if let error {
                    print("Ads: interstitial failed to load: \(error)")
                    return
                }
                ad?.fullScreenContentDelegate = self
                self.interstitial = ad
            }
        }
        #endif
    }
}

#if canImport(GoogleMobileAds)
extension AdsManager: FullScreenContentDelegate {
    nonisolated func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        Task { @MainActor in self.loadInterstitial() }
    }

    nonisolated func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        Task { @MainActor in self.loadInterstitial() }
    }
}
#endif

extension UIApplication {
    /// The view controller currently on screen, for presenting UIKit-based ad and consent UI.
    static var topViewController: UIViewController? {
        let scenes = shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
        let window = scene?.windows.first { $0.isKeyWindow } ?? scene?.windows.first
        var top = window?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
}
