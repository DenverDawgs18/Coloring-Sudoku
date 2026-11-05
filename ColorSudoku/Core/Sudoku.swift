import Foundation

/// Geometry helpers for a standard 9×9 board stored as a flat array of 81 cells.
/// Values are 1...9 (each value maps to a color in the UI); 0 means empty.
enum Sudoku {
    static let size = 9
    static let cellCount = 81
    static let values = 1...9

    @inline(__always) static func row(of index: Int) -> Int { index / 9 }
    @inline(__always) static func column(of index: Int) -> Int { index % 9 }
    @inline(__always) static func box(of index: Int) -> Int { (index / 27) * 3 + (index % 9) / 3 }

    /// For every cell, the indices of the 20 other cells sharing its row, column or box.
    static let peers: [[Int]] = (0..<cellCount).map { i in
        (0..<cellCount).filter { j in
            j != i && (row(of: j) == row(of: i) || column(of: j) == column(of: i) || box(of: j) == box(of: i))
        }
    }

    /// True when `a` and `b` share a row, column or box (or are the same cell).
    static func areRelated(_ a: Int, _ b: Int) -> Bool {
        row(of: a) == row(of: b) || column(of: a) == column(of: b) || box(of: a) == box(of: b)
    }
}

enum Difficulty: String, CaseIterable, Codable, Identifiable {
    case easy, medium, hard, expert

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .easy: return "Easy"
        case .medium: return "Medium"
        case .hard: return "Hard"
        case .expert: return "Expert"
        }
    }

    /// How many filled cells the generator aims to leave on the board.
    var targetClues: Int {
        switch self {
        case .easy: return 38
        case .medium: return 32
        case .hard: return 28
        case .expert: return 24
        }
    }
}

struct Puzzle: Codable, Equatable {
    /// Starting board (0 = empty).
    let givens: [Int]
    /// The unique solution.
    let solution: [Int]
    let difficulty: Difficulty

    var clueCount: Int { givens.filter { $0 != 0 }.count }
}
