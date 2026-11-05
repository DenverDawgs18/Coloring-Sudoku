import SwiftUI

struct GameView: View {
    @EnvironmentObject private var vm: GameViewModel
    @EnvironmentObject private var ads: AdsManager
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss
    @State private var newGameAfterWin: Difficulty?
    @State private var leaveAfterWin = false

    var body: some View {
        VStack(spacing: 0) {
            if let game = vm.game {
                VStack(spacing: 14) {
                    header(game)
                    BoardView(game: game)
                    ControlsBar(game: game)
                    PaletteView(game: game)
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .frame(maxWidth: 600)
                .frame(maxWidth: .infinity)
            }
            Spacer(minLength: 0)
            BannerAdView()
        }
        .navigationTitle(vm.game?.difficulty.displayName ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { vm.resumeTimer() }
        .onDisappear { vm.pauseTimer() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { vm.resumeTimer() } else { vm.pauseTimer() }
        }
        .sheet(isPresented: $vm.showWin, onDismiss: afterWin) {
            if let game = vm.game {
                WinView(game: game, stats: vm.stats[game.difficulty]) { choice in
                    switch choice {
                    case .newGame(let d): newGameAfterWin = d
                    case .home: leaveAfterWin = true
                    }
                    vm.showWin = false
                }
                .presentationDetents([.medium, .large])
                .interactiveDismissDisabled()
            }
        }
    }

    private func header(_ game: Game) -> some View {
        HStack {
            Label("\(game.mistakes)", systemImage: "xmark.circle")
                .foregroundStyle(game.mistakes > 0 ? .red : .secondary)
                .accessibilityLabel("\(game.mistakes) mistakes")
            Spacer()
            Label("\(game.hintsUsed)", systemImage: "lightbulb")
                .foregroundStyle(.secondary)
                .accessibilityLabel("\(game.hintsUsed) hints used")
            Spacer()
            Label(TimeFormat.clock(game.elapsed), systemImage: "clock")
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .accessibilityLabel("Time \(TimeFormat.clock(game.elapsed))")
        }
        .font(.subheadline.weight(.medium))
        .padding(.horizontal, 4)
    }

    private func afterWin() {
        ads.puzzleFinished()
        if let d = newGameAfterWin {
            newGameAfterWin = nil
            Task {
                await vm.newGame(d)
                vm.resumeTimer()
            }
        } else if leaveAfterWin {
            leaveAfterWin = false
            dismiss()
        }
    }
}

private struct ControlsBar: View {
    @EnvironmentObject private var vm: GameViewModel
    let game: Game

    var body: some View {
        HStack {
            control("Undo", "arrow.uturn.backward", enabled: game.canUndo) { vm.undo() }
            control("Erase", "eraser", enabled: vm.selected.map { !game.isGiven($0) } ?? false) { vm.erase() }
            control(vm.notesMode ? "Notes On" : "Notes Off", vm.notesMode ? "pencil.circle.fill" : "pencil.circle",
                    enabled: true, highlighted: vm.notesMode) { vm.notesMode.toggle() }
            control("Hint", "lightbulb", enabled: !game.isSolved) { vm.hint() }
        }
    }

    private func control(_ title: String, _ icon: String, enabled: Bool, highlighted: Bool = false,
                         action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon).font(.title2)
                Text(title).font(.caption2.weight(.medium))
            }
            .frame(maxWidth: .infinity, minHeight: 48)
            .foregroundStyle(highlighted ? Color.accentColor : Color.primary)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.35)
    }
}

private struct PaletteView: View {
    @EnvironmentObject private var vm: GameViewModel
    @AppStorage(SettingsKey.symbolStyle) private var symbolStyle = SymbolStyle.shapes.rawValue
    let game: Game

    var body: some View {
        HStack(spacing: 6) {
            ForEach(1...9, id: \.self) { value in
                let remaining = game.remaining(value)
                Button { vm.chooseColor(value) } label: {
                    VStack(spacing: 3) {
                        ZStack {
                            if vm.notesMode {
                                Circle().strokeBorder(Palette.color(value), lineWidth: 4)
                            } else {
                                Circle().fill(Palette.color(value).gradient)
                            }
                            CellSymbol(value: value, style: SymbolStyle(rawValue: symbolStyle) ?? .shapes,
                                       onColor: !vm.notesMode)
                                .padding(9)
                        }
                        .aspectRatio(1, contentMode: .fit)
                        Text("\(remaining)")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
                .disabled(remaining == 0 || vm.selected == nil)
                .opacity(remaining == 0 ? 0.2 : (vm.selected == nil ? 0.6 : 1))
                .accessibilityLabel("\(Palette.name(value)), \(remaining) left")
            }
        }
    }
}

enum WinChoice { case newGame(Difficulty), home }

private struct WinView: View {
    @EnvironmentObject private var store: StoreManager
    let game: Game
    let stats: DifficultyStats
    let onChoice: (WinChoice) -> Void

    var body: some View {
        VStack(spacing: 20) {
            LogoView().frame(width: 72, height: 72).padding(.top, 24)
            Text("Solved!").font(.system(.largeTitle, design: .rounded).weight(.heavy))
            HStack(spacing: 28) {
                stat("Time", TimeFormat.clock(game.elapsed))
                stat("Mistakes", "\(game.mistakes)")
                stat("Best", stats.bestTime.map(TimeFormat.clock) ?? "–")
            }
            if game.mistakes == 0 && game.hintsUsed == 0 {
                Label("Perfect game", systemImage: "star.fill").foregroundStyle(.yellow)
            }
            VStack(spacing: 10) {
                Button { onChoice(.newGame(game.difficulty)) } label: {
                    Text("New \(game.difficulty.displayName) Game").frame(maxWidth: .infinity, minHeight: 36)
                }
                .buttonStyle(.borderedProminent)
                Button { onChoice(.home) } label: {
                    Text("Home").frame(maxWidth: .infinity, minHeight: 36)
                }
                .buttonStyle(.bordered)
                if !store.adsRemoved {
                    Button {
                        Task { await store.purchaseRemoveAds() }
                    } label: {
                        Text(store.priceText.isEmpty ? "Remove ads forever" : "Remove ads forever · \(store.priceText)")
                            .font(.footnote)
                    }
                    .disabled(store.isPurchasing)
                    .padding(.top, 4)
                }
            }
            .controlSize(.large)
            .padding(.horizontal, 32)
            Spacer()
        }
        .purchaseErrorAlert()
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.title3.weight(.bold)).monospacedDigit()
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
    }
}
