import XCTest
@testable import ColorSudokuCore

/// Small deterministic RNG so generator tests are reproducible.
struct SplitMix64: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

func isValidSolution(_ grid: [Int]) -> Bool {
    guard grid.count == 81, grid.allSatisfy({ (1...9).contains($0) }) else { return false }
    for i in 0..<81 where Sudoku.peers[i].contains(where: { grid[$0] == grid[i] }) { return false }
    return true
}

final class SolverTests: XCTestCase {
    func testPeersHaveTwentyCells() {
        XCTAssertTrue(Sudoku.peers.allSatisfy { $0.count == 20 })
        XCTAssertEqual(Sudoku.box(of: 80), 8)
        XCTAssertEqual(Sudoku.box(of: 30), 4)
    }

    func testRandomSolvedGridIsValid() {
        var rng = SplitMix64(state: 1)
        for _ in 0..<20 {
            XCTAssertTrue(isValidSolution(SudokuSolver.randomSolvedGrid(using: &rng)))
        }
    }

    func testSolvesKnownPuzzle() {
        let puzzle = Array("530070000600195000098000060800060003400803001700020006060000280000419005000080079")
            .map { Int(String($0))! }
        let solution = SudokuSolver.solve(puzzle)
        XCTAssertNotNil(solution)
        XCTAssertTrue(isValidSolution(solution!))
        XCTAssertEqual(SudokuSolver.countSolutions(of: puzzle), 1)
    }

    func testDetectsMultipleAndInvalid() {
        XCTAssertEqual(SudokuSolver.countSolutions(of: [Int](repeating: 0, count: 81)), 2)
        var bad = [Int](repeating: 0, count: 81)
        bad[0] = 5; bad[1] = 5
        XCTAssertEqual(SudokuSolver.countSolutions(of: bad), 0)
        XCTAssertNil(SudokuSolver.solve(bad))
    }
}

final class GeneratorTests: XCTestCase {
    func testGeneratedPuzzlesAreUniqueAndConsistent() {
        var rng = SplitMix64(state: 42)
        for difficulty in Difficulty.allCases {
            for _ in 0..<3 {
                let p = PuzzleGenerator.generate(difficulty: difficulty, using: &rng)
                XCTAssertTrue(isValidSolution(p.solution))
                XCTAssertEqual(SudokuSolver.countSolutions(of: p.givens), 1, "\(difficulty) not unique")
                for i in 0..<81 where p.givens[i] != 0 { XCTAssertEqual(p.givens[i], p.solution[i]) }
                XCTAssertGreaterThanOrEqual(p.clueCount, difficulty.targetClues)
                XCTAssertLessThanOrEqual(p.clueCount, difficulty.targetClues + 8, "\(difficulty): \(p.clueCount) clues")
            }
        }
    }

    func testGenerationIsFast() {
        measure { _ = PuzzleGenerator.generate(difficulty: .expert) }
    }
}

final class GameTests: XCTestCase {
    private func makeGame() -> Game {
        var rng = SplitMix64(state: 7)
        return Game(puzzle: PuzzleGenerator.generate(difficulty: .medium, using: &rng))
    }

    func testPlacingCorrectAndWrongValues() {
        var game = makeGame()
        let empty = (0..<81).first { !game.isGiven($0) }!
        let right = game.puzzle.solution[empty]
        let wrong = right % 9 + 1

        XCTAssertEqual(game.place(wrong, at: empty), .mistake)
        XCTAssertEqual(game.mistakes, 1)
        XCTAssertTrue(game.isWrong(empty))
        XCTAssertEqual(game.place(right, at: empty), .placed)
        XCTAssertFalse(game.isWrong(empty))
        XCTAssertEqual(game.place(right, at: empty), .ignored)
    }

    func testGivensCannotChange() {
        var game = makeGame()
        let given = (0..<81).first { game.isGiven($0) }!
        XCTAssertEqual(game.place(game.puzzle.solution[given] % 9 + 1, at: given), .ignored)
        XCTAssertFalse(game.erase(at: given))
        XCTAssertFalse(game.toggleNote(1, at: given))
    }

    func testNotesAreClearedFromPeersAndRestoredByUndo() {
        var game = makeGame()
        let empties = (0..<81).filter { !game.isGiven($0) }
        let target = empties[0]
        let value = game.puzzle.solution[target]
        guard let peer = empties.first(where: { $0 != target && Sudoku.areRelated($0, target) }) else {
            return XCTFail("no empty peer")
        }
        XCTAssertTrue(game.toggleNote(value, at: peer))
        XCTAssertTrue(game.hasNote(value, at: peer))
        game.place(value, at: target)
        XCTAssertFalse(game.hasNote(value, at: peer))
        XCTAssertTrue(game.undo())
        XCTAssertTrue(game.hasNote(value, at: peer))
        XCTAssertEqual(game.values[target], 0)
        XCTAssertTrue(game.undo())
        XCTAssertFalse(game.hasNote(value, at: peer))
        XCTAssertFalse(game.undo())
    }

    func testSolvingWithHints() {
        var game = makeGame()
        var steps = 0
        while !game.isSolved, steps < 81 {
            XCTAssertNotNil(game.hint())
            steps += 1
        }
        XCTAssertTrue(game.isSolved)
        XCTAssertEqual(game.hintsUsed, 81 - game.puzzle.clueCount)
        XCTAssertNil(game.hint())
        XCTAssertFalse(game.canUndo)
        XCTAssertTrue((1...9).allSatisfy { game.remaining($0) == 0 })
    }

    func testFinalPlacementReportsSolved() {
        var game = makeGame()
        let empties = (0..<81).filter { !game.isGiven($0) }
        for i in empties.dropLast() { game.place(game.puzzle.solution[i], at: i) }
        let last = empties.last!
        XCTAssertEqual(game.place(game.puzzle.solution[last], at: last), .solved)
    }

    func testCodableRoundTrip() throws {
        var game = makeGame()
        let empty = (0..<81).first { !game.isGiven($0) }!
        game.toggleNote(3, at: empty)
        game.elapsed = 12
        let data = try JSONEncoder().encode(game)
        XCTAssertEqual(try JSONDecoder().decode(Game.self, from: data), game)
    }

    func testStats() {
        var stats = GameStats()
        var game = makeGame()
        stats.recordStart(.medium)
        while !game.isSolved { game.hint() }
        game.elapsed = 100
        stats.recordWin(game)
        XCTAssertEqual(stats[.medium].won, 1)
        XCTAssertEqual(stats[.medium].bestTime, 100)
        XCTAssertEqual(stats[.medium].perfectWins, 0)
        XCTAssertEqual(stats[.easy].started, 0)
        XCTAssertEqual(TimeFormat.clock(3725), "1:02:05")
        XCTAssertEqual(TimeFormat.clock(65), "1:05")
    }
}
