import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var vm: GameViewModel
    @EnvironmentObject private var store: StoreManager
    @State private var showGame = false
    @State private var showSettings = false
    @State private var showStats = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 28) {
                        LogoView()
                            .frame(width: 132, height: 132)
                            .padding(.top, 32)

                        VStack(spacing: 6) {
                            Text("Color Sudoku")
                                .font(.system(.largeTitle, design: .rounded).weight(.heavy))
                            Text("Fill every row, column and box with all nine colors.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }

                        if let game = vm.game, vm.canContinue {
                            Button {
                                showGame = true
                            } label: {
                                VStack(spacing: 2) {
                                    Text("Continue").font(.headline)
                                    Text("\(game.difficulty.displayName) · \(TimeFormat.clock(game.elapsed))")
                                        .font(.caption)
                                        .opacity(0.85)
                                }
                                .frame(maxWidth: .infinity, minHeight: 44)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                        }

                        VStack(spacing: 12) {
                            Text("New Game")
                                .font(.headline)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            ForEach(Difficulty.allCases) { difficulty in
                                Button {
                                    Task {
                                        await vm.newGame(difficulty)
                                        showGame = true
                                    }
                                } label: {
                                    HStack {
                                        Text(difficulty.displayName).font(.body.weight(.semibold))
                                        Spacer()
                                        DifficultyDots(difficulty: difficulty)
                                    }
                                    .frame(maxWidth: .infinity, minHeight: 36)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.large)
                                .disabled(vm.isGenerating)
                            }
                        }

                        if !store.adsRemoved {
                            Button {
                                Task { await store.purchaseRemoveAds() }
                            } label: {
                                Label(
                                    store.priceText.isEmpty ? "Remove Ads" : "Remove Ads · \(store.priceText)",
                                    systemImage: "nosign"
                                )
                            }
                            .disabled(store.isPurchasing)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                    .frame(maxWidth: 520)
                    .frame(maxWidth: .infinity)
                }
                BannerAdView()
            }
            .overlay {
                if vm.isGenerating {
                    ProgressView("Creating puzzle…")
                        .padding(24)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showStats = true } label: { Image(systemName: "chart.bar.fill") }
                        .accessibilityLabel("Statistics")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: { Image(systemName: "gearshape.fill") }
                        .accessibilityLabel("Settings")
                }
            }
            .navigationDestination(isPresented: $showGame) { GameView() }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(isPresented: $showStats) { StatsView() }
            .purchaseErrorAlert()
        }
    }
}

private struct DifficultyDots: View {
    let difficulty: Difficulty
    var body: some View {
        let level = Difficulty.allCases.firstIndex(of: difficulty)! + 1
        HStack(spacing: 4) {
            ForEach(1...4, id: \.self) { i in
                Circle()
                    .fill(i <= level ? Palette.color(i * 2 - 1) : Color.secondary.opacity(0.25))
                    .frame(width: 8, height: 8)
            }
        }
        .accessibilityHidden(true)
    }
}

/// A 3×3 swatch of the palette, used as the app's logo.
struct LogoView: View {
    var body: some View {
        GeometryReader { geo in
            let gap = geo.size.width * 0.05
            let side = (geo.size.width - gap * 2) / 3
            VStack(spacing: gap) {
                ForEach(0..<3) { r in
                    HStack(spacing: gap) {
                        ForEach(0..<3) { c in
                            RoundedRectangle(cornerRadius: side * 0.25)
                                .fill(Palette.color(r * 3 + c + 1).gradient)
                                .frame(width: side, height: side)
                        }
                    }
                }
            }
        }
        .accessibilityHidden(true)
    }
}

extension View {
    /// Shows StoreManager's error messages (failed purchase, nothing to restore…).
    func purchaseErrorAlert() -> some View { modifier(PurchaseErrorAlert()) }
}

private struct PurchaseErrorAlert: ViewModifier {
    @EnvironmentObject private var store: StoreManager
    func body(content: Content) -> some View {
        content.alert(
            "Store",
            isPresented: Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } }),
            actions: { Button("OK", role: .cancel) {} },
            message: { Text(store.errorMessage ?? "") }
        )
    }
}
