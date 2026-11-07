import SwiftUI

struct StatsView: View {
    @EnvironmentObject private var vm: GameViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(Difficulty.allCases) { difficulty in
                    let s = vm.stats[difficulty]
                    Section(difficulty.displayName) {
                        row("Games started", "\(s.started)")
                        row("Games won", "\(s.won)")
                        row("Win rate", s.started == 0 ? "–" : s.winRate.formatted(.percent.precision(.fractionLength(0))))
                        row("Perfect wins", "\(s.perfectWins)")
                        row("Best time", s.bestTime.map(TimeFormat.clock) ?? "–")
                        row("Average time", s.averageTime.map(TimeFormat.clock) ?? "–")
                        row("Current streak", "\(s.currentStreak)")
                        row("Best streak", "\(s.bestStreak)")
                    }
                }
            }
            .navigationTitle("Statistics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }

    private func row(_ title: String, _ value: String) -> some View {
        LabeledContent(title) { Text(value).monospacedDigit() }
    }
}
