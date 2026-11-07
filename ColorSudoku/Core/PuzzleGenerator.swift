import Foundation

enum PuzzleGenerator {
    static func generate(difficulty: Difficulty) -> Puzzle {
        var rng = SystemRandomNumberGenerator()
        return generate(difficulty: difficulty, using: &rng)
    }

    /// Builds a random solved grid, then removes cells while the puzzle keeps exactly one solution.
    static func generate<G: RandomNumberGenerator>(difficulty: Difficulty, using rng: inout G) -> Puzzle {
        let solution = SudokuSolver.randomSolvedGrid(using: &rng)
        var board = solution
        var clues = Sudoku.cellCount
        let target = difficulty.targetClues

        func tryRemoving(_ cells: [Int]) {
            guard clues - cells.count >= target, cells.allSatisfy({ board[$0] != 0 }) else { return }
            let saved = cells.map { board[$0] }
            for i in cells { board[i] = 0 }
            if SudokuSolver.countSolutions(of: board, limit: 2) == 1 {
                clues -= cells.count
            } else {
                for (i, value) in zip(cells, saved) { board[i] = value }
            }
        }

        // First pass: remove cells in rotationally symmetric pairs for a balanced-looking board.
        for i in Array(0...40).shuffled(using: &rng) where clues > target {
            let mirror = Sudoku.cellCount - 1 - i
            tryRemoving(i == mirror ? [i] : [i, mirror])
        }
        // Second pass: single cells, to get closer to the target on harder levels.
        for i in Array(0..<Sudoku.cellCount).shuffled(using: &rng) where clues > target {
            tryRemoving([i])
        }

        return Puzzle(givens: board, solution: solution, difficulty: difficulty)
    }
}
