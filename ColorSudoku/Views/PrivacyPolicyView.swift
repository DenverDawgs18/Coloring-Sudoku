import SwiftUI

/// In-app copy of the privacy policy (App Review Guideline 5.1.1 requires it to be reachable inside the app).
/// Keep in sync with PRIVACY.md, which you can host as the Privacy Policy URL in App Store Connect.
struct PrivacyPolicyView: View {
    @EnvironmentObject private var ads: AdsManager
    @EnvironmentObject private var store: StoreManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Last updated: November 2026").font(.footnote).foregroundStyle(.secondary)

                section("Overview", """
                Color Sudoku does not require an account and does not collect personal information itself. \
                Your games, settings and statistics are stored only on your device.
                """)

                section("Advertising", """
                The free version shows ads served by Google AdMob. Google may collect and use data such as \
                your device's advertising identifier (only if you allow tracking), IP address, approximate \
                location, device information and ad interactions, to show and measure ads and to prevent fraud. \
                Where required by law (for example in the EEA, UK and some US states) you are asked for consent \
                first, and you can change your choice at any time in Settings › Ad Privacy Choices. Whether apps \
                may use your advertising identifier is controlled by Apple's "Allow Apps to Request to Track" \
                setting. See Google's policy at https://policies.google.com/technologies/ads.
                """)

                section("Purchases", """
                The optional "Remove Ads" purchase is processed by Apple. We receive no payment details. \
                After purchase the advertising SDK is not started at all.
                """)

                section("Children", """
                Color Sudoku is not directed at children under 13 and does not knowingly collect data from them.
                """)

                section("Deleting your data", """
                All game data is stored on your device; deleting the app deletes it. For data held by Google, \
                see https://policies.google.com/privacy.
                """)

                section("Changes", """
                We may update this policy; the date above shows the latest version.
                """)

                if ads.privacyOptionsRequired && !store.adsRemoved {
                    Button("Change Ad Privacy Choices") { ads.presentPrivacyOptions() }
                        .buttonStyle(.bordered)
                }
            }
            .padding()
            .frame(maxWidth: 700, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func section(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline)
            Text(body).font(.body)
        }
    }
}
