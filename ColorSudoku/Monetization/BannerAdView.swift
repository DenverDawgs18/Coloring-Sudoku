import SwiftUI
#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif

/// Anchored adaptive banner. Renders nothing when ads are removed or not ready yet.
struct BannerAdView: View {
    @EnvironmentObject private var ads: AdsManager
    @EnvironmentObject private var store: StoreManager

    var body: some View {
        #if canImport(GoogleMobileAds)
        if ads.isReady && !store.adsRemoved {
            GeometryReader { geo in
                BannerRepresentable(width: geo.size.width)
                    .frame(width: geo.size.width, height: Self.height(for: geo.size.width))
            }
            .frame(height: Self.height(for: UIScreen.main.bounds.width))
            .transition(.opacity)
        }
        #endif
    }

    #if canImport(GoogleMobileAds)
    static func height(for width: CGFloat) -> CGFloat {
        currentOrientationAnchoredAdaptiveBanner(width: width).size.height
    }
    #endif
}

#if canImport(GoogleMobileAds)
private struct BannerRepresentable: UIViewRepresentable {
    let width: CGFloat

    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView(adSize: currentOrientationAnchoredAdaptiveBanner(width: width))
        banner.adUnitID = AdConfig.bannerUnitID
        banner.rootViewController = UIApplication.topViewController
        banner.load(Request())
        return banner
    }

    func updateUIView(_ banner: BannerView, context: Context) {
        let size = currentOrientationAnchoredAdaptiveBanner(width: width)
        if banner.adSize.size != size.size {
            banner.adSize = size
            banner.load(Request())
        }
    }
}
#endif
