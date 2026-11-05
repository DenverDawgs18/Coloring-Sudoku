import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: StoreManager
    @EnvironmentObject private var ads: AdsManager
    @Environment(\.dismiss) private var dismiss
    @AppStorage(SettingsKey.symbolStyle) private var symbolStyle = SymbolStyle.shapes.rawValue
    @AppStorage(SettingsKey.highlightMistakes) private var highlightMistakes = true
    @AppStorage(SettingsKey.highlightRelated) private var highlightRelated = true
    @AppStorage(SettingsKey.highlightSameColor) private var highlightSameColor = true
    @AppStorage(SettingsKey.haptics) private var haptics = true

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Symbols", selection: $symbolStyle) {
                        ForEach(SymbolStyle.allCases) { Text($0.label).tag($0.rawValue) }
                    }
                    HStack(spacing: 6) {
                        ForEach(1...9, id: \.self) { v in
                            ZStack {
                                Circle().fill(Palette.color(v).gradient)
                                CellSymbol(value: v, style: SymbolStyle(rawValue: symbolStyle) ?? .shapes, onColor: true)
                                    .padding(7)
                            }
                            .aspectRatio(1, contentMode: .fit)
                        }
                    }
                    .padding(.vertical, 4)
                    .accessibilityHidden(true)
                } header: {
                    Text("Display")
                } footer: {
                    Text("Shapes or numbers make every color easy to identify, including for color-blind players.")
                }

                Section("Assists") {
                    Toggle("Show mistakes", isOn: $highlightMistakes)
                    Toggle("Highlight row, column & box", isOn: $highlightRelated)
                    Toggle("Highlight matching colors", isOn: $highlightSameColor)
                    Toggle("Haptic feedback", isOn: $haptics)
                }

                Section {
                    if store.adsRemoved {
                        Label("Ads removed — thank you!", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                    } else {
                        Button {
                            Task { await store.purchaseRemoveAds() }
                        } label: {
                            HStack {
                                Label("Remove Ads", systemImage: "nosign")
                                Spacer()
                                if store.isPurchasing {
                                    ProgressView()
                                } else {
                                    Text(store.priceText).foregroundStyle(.secondary)
                                }
                            }
                        }
                        .disabled(store.isPurchasing)
                    }
                    Button("Restore Purchases") {
                        Task { await store.restorePurchases() }
                    }
                    if ads.privacyOptionsRequired && !store.adsRemoved {
                        Button("Ad Privacy Choices") { ads.presentPrivacyOptions() }
                    }
                } header: {
                    Text("Ads")
                } footer: {
                    Text("A single one-time purchase removes all ads permanently, on every device signed in with your Apple ID.")
                }

                Section("About") {
                    LabeledContent("Version", value: Bundle.main.appVersion)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .purchaseErrorAlert()
        }
    }
}

extension Bundle {
    var appVersion: String {
        let version = infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}
