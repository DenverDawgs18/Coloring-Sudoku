// swift-tools-version:5.9
// Lets the pure game logic in ColorSudoku/Core be built and unit-tested with `swift test`
// on any platform (including Linux CI). The iOS app itself is built from ColorSudoku.xcodeproj.
import PackageDescription

let package = Package(
    name: "ColorSudokuCore",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [.library(name: "ColorSudokuCore", targets: ["ColorSudokuCore"])],
    targets: [
        .target(name: "ColorSudokuCore", path: "ColorSudoku/Core"),
        .testTarget(name: "ColorSudokuCoreTests", dependencies: ["ColorSudokuCore"], path: "Tests/ColorSudokuCoreTests"),
    ]
)
