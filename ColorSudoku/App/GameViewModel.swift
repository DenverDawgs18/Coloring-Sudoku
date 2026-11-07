import SwiftUI
import Combine

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

    private var timer: AnyCancellable?
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
        isGenerating = true
        let puzzle = await Task.detached(priority: .userInitiated) {
            PuzzleGenerator.generate(difficulty: difficulty)
        }.value
        game = Game(puzzle: puzzle)
        selected = nil
        notesMode = false
        showWin = false
        isGenerating = false
        stats.recordStart(difficulty)
        save()
    }

    func resumeTimer() {
        guard timer == nil, let game, !game.isSolved else { return }
        timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect().sink { [weak self] _ in
            self?.game?.elapsed += 1
        }
    }

    func pauseTimer() {
        timer?.cancel()
        timer = nil
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
        if updated.isSolved { finish(updated) } else { save() }
    }

    private func finish(_ finished: Game) {
        pauseTimer()
        stats.recordWin(finished)
        completedCount += 1
        selected = nil
        notesMode = false
        Haptics.notify(.success)
        save()
        withAnimation(.spring()) { showWin = true }
    }

    // MARK: Persistence

    func save() {
        Self.store(game, key: Self.gameKey, in: defaults)
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
