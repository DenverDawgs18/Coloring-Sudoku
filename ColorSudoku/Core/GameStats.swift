import Foundation

struct DifficultyStats: Codable, Equatable {
    var started = 0
    var won = 0
    var bestTime: TimeInterval?
    var totalWinTime: TimeInterval = 0
    var perfectWins = 0 // no mistakes, no hints
    var currentStreak = 0
    var bestStreak = 0

    var winRate: Double { started == 0 ? 0 : Double(won) / Double(started) }
    var averageTime: TimeInterval? { won == 0 ? nil : totalWinTime / Double(won) }
}

struct GameStats: Codable, Equatable {
    private var entries: [String: DifficultyStats] = [:]

    subscript(difficulty: Difficulty) -> DifficultyStats {
        get { entries[difficulty.rawValue] ?? DifficultyStats() }
        set { entries[difficulty.rawValue] = newValue }
    }

    mutating func recordStart(_ difficulty: Difficulty) {
        self[difficulty].started += 1
    }

    /// Call when a game is abandoned (a new game started before finishing the old one).
    mutating func recordAbandon(_ difficulty: Difficulty) {
        self[difficulty].currentStreak = 0
    }

    mutating func recordWin(_ game: Game) {
        var s = self[game.difficulty]
        s.won += 1
        s.totalWinTime += game.elapsed
        s.bestTime = min(s.bestTime ?? .infinity, game.elapsed)
        if game.mistakes == 0 && game.hintsUsed == 0 { s.perfectWins += 1 }
        s.currentStreak += 1
        s.bestStreak = max(s.bestStreak, s.currentStreak)
        self[game.difficulty] = s
    }
}

enum TimeFormat {
    static func clock(_ t: TimeInterval) -> String {
        let total = Int(t.rounded(.down))
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }
}
