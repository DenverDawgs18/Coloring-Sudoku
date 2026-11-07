import SwiftUI

@MainActor
final class GameViewModel: ObservableObject {
    @Published private(set) var game: Game?
    @Published var selected: Int?
    @Published var notesMode = false
    @Published private(set) var isGenerating = false
    @Published var showWin = false
    @Published private(set) var stats: GameStats
    /// Bumped on every puzzle completion; observed by the ads layer.
    @Published private(set) var completedCount = 0

    /// When the clock last started running. The running time is derived from this instead of being
    /// published every second, so only the small clock view redraws while you play.
    private var clockStartedAt: Date?
    private var pendingSave: Task<Void, Never>?
    private var isStartingGame = false
    private let defaults: UserDefaults
    private static let gameKey = "currentGame.v1"
    private static let statsKey = "stats.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        game = Self.load(Game.self, key: Self.gameKey, from: defaults)
        stats = Self.load(GameStats.self, key: Self.statsKey, from: defaults) ?? GameStats()
    }

    var canContinue: Bool { game.map { !$0.isSolved } ?? false }

    // MARK: Lifecycle

    func newGame(_ difficulty: Difficulty) async {
        if let old = game, !old.isSolved, old.filledCount > old.puzzle.clueCount {
            stats.recordAbandon(old.difficulty)
        }
        guard !isStartingGame else { return }
        isStartingGame = true
        defer { isStartingGame = false }
        // Generating takes a few milliseconds, so only show the spinner if it is unusually slow;
        // flashing it for every new game makes the app feel slower than it is.
        let spinner = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 250_000_000)
            if !Task.isCancelled { self?.isGenerating = true }
        }
        let puzzle = await Task.detached(priority: .userInitiated) {
            PuzzleGenerator.generate(difficulty: difficulty)
        }.value
        spinner.cancel()
        clockStartedAt = nil
        game = Game(puzzle: puzzle)
        selected = nil
        notesMode = false
        showWin = false
        isGenerating = false
        stats.recordStart(difficulty)
        save()
    }

    /// Total play time including the currently running stretch.
    var elapsed: TimeInterval {
        (game?.elapsed ?? 0) + (clockStartedAt.map { Date().timeIntervalSince($0) } ?? 0)
    }

    var isClockRunning: Bool { clockStartedAt != nil }

    func resumeTimer() {
        guard clockStartedAt == nil, let game, !game.isSolved else { return }
        clockStartedAt = Date()
    }

    func pauseTimer() {
        if clockStartedAt != nil {
            game?.elapsed = elapsed
            clockStartedAt = nil
        }
        save()
    }

    // MARK: Input

    func select(_ index: Int) {
        selected = (selected == index) ? nil : index
        Haptics.tap()
    }

    func chooseColor(_ value: Int) {
        guard var g = game, let i = selected else { return }
        if notesMode {
            if g.toggleNote(value, at: i) { Haptics.tap() }
        } else {
            switch g.place(value, at: i) {
            case .ignored: return
            case .placed: Haptics.tap()
            case .mistake: Haptics.notify(.error)
            case .solved: break
            }
        }
        commit(g)
    }

    func erase() {
        guard var g = game, let i = selected, g.erase(at: i) else { return }
        Haptics.tap()
        commit(g)
    }

    func undo() {
        guard var g = game, g.undo() else { return }
        Haptics.tap()
        commit(g)
    }

    func hint() {
        guard var g = game, let index = g.hint(preferring: selected) else { return }
        selected = index
        Haptics.notify(.success)
        commit(g)
    }

    private func commit(_ updated: Game) {
        game = updated
        if updated.isSolved { finish() } else { scheduleSave() }
    }

    private func finish() {
        pauseTimer() // folds the running time into game.elapsed
        guard let finished = game else { return }
        stats.recordWin(finished)
        completedCount += 1
        selected = nil
        notesMode = false
        Haptics.notify(.success)
        save()
        withAnimation(.spring()) { showWin = true }
    }

    // MARK: Persistence

    /// Coalesces the saves from a quick run of taps into one write.
    private func scheduleSave() {
        pendingSave?.cancel()
        pendingSave = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }
            self?.save()
        }
    }

    func save() {
        pendingSave?.cancel()
        pendingSave = nil
        var snapshot = game
        snapshot?.elapsed = elapsed // include the running stretch without stopping the clock
        Self.store(snapshot, key: Self.gameKey, in: defaults)
        Self.store(stats, key: Self.statsKey, in: defaults)
    }

    private static func load<T: Decodable>(_ type: T.Type, key: String, from defaults: UserDefaults) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private static func store<T: Encodable>(_ value: T?, key: String, in defaults: UserDefaults) {
        if let value, let data = try? JSONEncoder().encode(value) {
            defaults.set(data, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }
}
