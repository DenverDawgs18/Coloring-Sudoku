import Foundation

/// Bitmask backtracking solver with "fewest candidates first" cell selection.
struct SudokuSolver {
    private static let allValues: UInt16 = 0b11_1111_1110 // bits 1...9

    private var cells: [Int]
    private var rows = [UInt16](repeating: 0, count: 9)
    private var columns = [UInt16](repeating: 0, count: 9)
    private var boxes = [UInt16](repeating: 0, count: 9)

    /// Returns nil if the grid is malformed or already breaks a rule.
    init?(_ grid: [Int]) {
        guard grid.count == Sudoku.cellCount else { return nil }
        cells = grid
        for i in 0..<Sudoku.cellCount where grid[i] != 0 {
            let value = grid[i]
            guard Sudoku.values.contains(value) else { return nil }
            let bit = UInt16(1) << value
            let r = Sudoku.row(of: i), c = Sudoku.column(of: i), b = Sudoku.box(of: i)
            if (rows[r] | columns[c] | boxes[b]) & bit != 0 { return nil }
            rows[r] |= bit
            columns[c] |= bit
            boxes[b] |= bit
        }
    }

    // MARK: Public API

    /// Counts solutions, stopping as soon as `limit` is reached.
    static func countSolutions(of grid: [Int], limit: Int = 2) -> Int {
        guard var solver = SudokuSolver(grid) else { return 0 }
        var rng = SystemRandomNumberGenerator()
        var count = 0
        var first: [Int]?
        solver.search(randomize: false, rng: &rng, limit: limit, count: &count, first: &first)
        return count
    }

    static func solve(_ grid: [Int]) -> [Int]? {
        guard var solver = SudokuSolver(grid) else { return nil }
        var rng = SystemRandomNumberGenerator()
        var count = 0
        var first: [Int]?
        solver.search(randomize: false, rng: &rng, limit: 1, count: &count, first: &first)
        return first
    }

    /// A random, completely filled valid grid.
    static func randomSolvedGrid<G: RandomNumberGenerator>(using rng: inout G) -> [Int] {
        var solver = SudokuSolver([Int](repeating: 0, count: Sudoku.cellCount))!
        var count = 0
        var first: [Int]?
        solver.search(randomize: true, rng: &rng, limit: 1, count: &count, first: &first)
        return first! // an empty grid always has a solution
    }

    // MARK: Search

    private func candidates(at i: Int) -> UInt16 {
        ~(rows[Sudoku.row(of: i)] | columns[Sudoku.column(of: i)] | boxes[Sudoku.box(of: i)]) & Self.allValues
    }

    private mutating func set(_ value: Int, at i: Int, on: Bool) {
        let bit = UInt16(1) << value
        let r = Sudoku.row(of: i), c = Sudoku.column(of: i), b = Sudoku.box(of: i)
        if on {
            rows[r] |= bit; columns[c] |= bit; boxes[b] |= bit
            cells[i] = value
        } else {
            rows[r] &= ~bit; columns[c] &= ~bit; boxes[b] &= ~bit
            cells[i] = 0
        }
    }

    private mutating func search<G: RandomNumberGenerator>(
        randomize: Bool, rng: inout G, limit: Int, count: inout Int, first: inout [Int]?
    ) {
        var best = -1
        var bestCount = 10
        var bestMask: UInt16 = 0
        for i in 0..<Sudoku.cellCount where cells[i] == 0 {
            let mask = candidates(at: i)
            let n = mask.nonzeroBitCount
            if n < bestCount {
                best = i; bestCount = n; bestMask = mask
                if n <= 1 { break }
            }
        }
        if best == -1 { // board full
            count += 1
            if first == nil { first = cells }
            return
        }
        if bestCount == 0 { return } // dead end

        var options = Sudoku.values.filter { bestMask & (UInt16(1) << $0) != 0 }
        if randomize { options.shuffle(using: &rng) }
        for value in options {
            set(value, at: best, on: true)
            search(randomize: randomize, rng: &rng, limit: limit, count: &count, first: &first)
            set(value, at: best, on: false)
            if count >= limit { return }
        }
    }
}
