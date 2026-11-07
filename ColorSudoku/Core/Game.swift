import Foundation

enum MoveResult: Equatable {
    /// Nothing changed (given cell, same value, game already solved…).
    case ignored
    case placed
    case mistake
    case solved
}

/// The full, serializable state of one game in progress. Pure value type: no UI dependencies.
struct Game: Codable, Equatable {
    struct CellState: Codable, Equatable {
        let index: Int
        let value: Int
        let notes: UInt16
    }

    /// One undoable step: the previous state of every cell it touched.
    struct Move: Codable, Equatable {
        let changes: [CellState]
    }

    let id: UUID
    let puzzle: Puzzle
    private(set) var values: [Int]
    /// Pencil marks per cell, bit `n` set = color `n` noted.
    private(set) var notes: [UInt16]
    private(set) var mistakes = 0
    private(set) var hintsUsed = 0
    var elapsed: TimeInterval = 0
    private var history: [Move] = []

    init(puzzle: Puzzle, id: UUID = UUID()) {
        self.id = id
        self.puzzle = puzzle
        values = puzzle.givens
        notes = [UInt16](repeating: 0, count: Sudoku.cellCount)
    }

    // MARK: Queries

    var difficulty: Difficulty { puzzle.difficulty }
    var isSolved: Bool { values == puzzle.solution }
    var canUndo: Bool { !history.isEmpty && !isSolved }

    func isGiven(_ i: Int) -> Bool { puzzle.givens[i] != 0 }
    func isWrong(_ i: Int) -> Bool { values[i] != 0 && values[i] != puzzle.solution[i] }
    func hasNote(_ value: Int, at i: Int) -> Bool { notes[i] & (UInt16(1) << value) != 0 }

    /// True when the cell's value is repeated somewhere in its row, column or box.
    func hasConflict(at i: Int) -> Bool {
        let v = values[i]
        return v != 0 && Sudoku.peers[i].contains { values[$0] == v }
    }

    /// How many more cells still need this color (correctly placed ones count as done).
    func remaining(_ value: Int) -> Int {
        var placed = 0
        for i in 0..<Sudoku.cellCount where values[i] == value && puzzle.solution[i] == value { placed += 1 }
        return Sudoku.size - placed
    }

    var filledCount: Int { values.filter { $0 != 0 }.count }

    // MARK: Moves

    @discardableResult
    mutating func place(_ value: Int, at i: Int) -> MoveResult {
        guard Sudoku.values.contains(value), !isGiven(i), !isSolved, values[i] != value else { return .ignored }
        var changes = [snapshot(i)]
        values[i] = value
        notes[i] = 0
        // Placing a color removes that color's pencil marks from the row, column and box.
        let bit = UInt16(1) << value
        for p in Sudoku.peers[i] where notes[p] & bit != 0 {
            changes.append(snapshot(p))
            notes[p] &= ~bit
        }
        record(Move(changes: changes))

        if value != puzzle.solution[i] {
            mistakes += 1
            return .mistake
        }
        return isSolved ? .solved : .placed
    }

    @discardableResult
    mutating func toggleNote(_ value: Int, at i: Int) -> Bool {
        guard Sudoku.values.contains(value), !isGiven(i), values[i] == 0, !isSolved else { return false }
        record(Move(changes: [snapshot(i)]))
        notes[i] ^= UInt16(1) << value
        return true
    }

    @discardableResult
    mutating func erase(at i: Int) -> Bool {
        guard !isGiven(i), !isSolved, values[i] != 0 || notes[i] != 0 else { return false }
        record(Move(changes: [snapshot(i)]))
        values[i] = 0
        notes[i] = 0
        return true
    }

    @discardableResult
    mutating func undo() -> Bool {
        guard canUndo, let move = history.popLast() else { return false }
        for change in move.changes.reversed() {
            values[change.index] = change.value
            notes[change.index] = change.notes
        }
        return true
    }

    /// Reveals the correct color for `preferred` if it still needs one, otherwise for a random unsolved cell.
    /// Returns the revealed cell index.
    @discardableResult
    mutating func hint(preferring preferred: Int? = nil) -> Int? {
        guard !isSolved else { return nil }
        let current = values, solution = puzzle.solution
        let needsHelp = { (i: Int) in current[i] != solution[i] }
        let target: Int
        if let preferred, needsHelp(preferred) {
            target = preferred
        } else if let random = (0..<Sudoku.cellCount).filter(needsHelp).randomElement() {
            target = random
        } else {
            return nil
        }
        let value = puzzle.solution[target]
        var changes = [snapshot(target)]
        values[target] = value
        notes[target] = 0
        let bit = UInt16(1) << value
        for p in Sudoku.peers[target] where notes[p] & bit != 0 {
            changes.append(snapshot(p))
            notes[p] &= ~bit
        }
        record(Move(changes: changes))
        hintsUsed += 1
        return target
    }

    /// Undo depth. Keeps the saved game (encoded after every move) small during very long sessions.
    static let maxUndoSteps = 300

    private mutating func record(_ move: Move) {
        history.append(move)
        if history.count > Self.maxUndoSteps {
            history.removeFirst(history.count - Self.maxUndoSteps)
        }
    }

    private func snapshot(_ i: Int) -> CellState {
        CellState(index: i, value: values[i], notes: notes[i])
    }
}
