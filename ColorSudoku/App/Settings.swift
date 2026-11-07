import SwiftUI

enum SymbolStyle: String, CaseIterable, Identifiable {
    case none, shapes, numbers
    var id: String { rawValue }
    var label: String {
        switch self {
        case .none: return "Colors only"
        case .shapes: return "Colors + shapes"
        case .numbers: return "Colors + numbers"
        }
    }
}

/// UserDefaults keys shared by `@AppStorage` properties.
enum SettingsKey {
    static let symbolStyle = "symbolStyle"
    static let highlightMistakes = "highlightMistakes"
    static let highlightRelated = "highlightRelated"
    static let highlightSameColor = "highlightSameColor"
    static let haptics = "hapticsEnabled"
}

enum Palette {
    /// Nine colors chosen to be distinguishable from each other in light and dark mode.
    static let colors: [Color] = [
        Color(red: 0.93, green: 0.26, blue: 0.27), // 1 red
        Color(red: 0.98, green: 0.58, blue: 0.13), // 2 orange
        Color(red: 0.98, green: 0.82, blue: 0.16), // 3 yellow
        Color(red: 0.30, green: 0.75, blue: 0.33), // 4 green
        Color(red: 0.13, green: 0.74, blue: 0.80), // 5 teal
        Color(red: 0.20, green: 0.42, blue: 0.92), // 6 blue
        Color(red: 0.55, green: 0.32, blue: 0.86), // 7 purple
        Color(red: 0.96, green: 0.43, blue: 0.72), // 8 pink
        Color(red: 0.55, green: 0.38, blue: 0.24), // 9 brown
    ]
    static let names = ["Red", "Orange", "Yellow", "Green", "Teal", "Blue", "Purple", "Pink", "Brown"]
    static let shapes = [
        "circle.fill", "triangle.fill", "square.fill", "star.fill", "heart.fill",
        "diamond.fill", "hexagon.fill", "moon.fill", "bolt.fill",
    ]

    static func color(_ value: Int) -> Color { colors[value - 1] }

    /// Symbol color drawn on top of a color tile: dark on the light yellow, white elsewhere.
    /// Gives good contrast without a per-cell drop shadow.
    static func symbolColor(_ value: Int) -> Color { value == 3 ? Color.black.opacity(0.6) : .white }
    static func name(_ value: Int) -> String { names[value - 1] }
    static func shape(_ value: Int) -> String { shapes[value - 1] }
}

@MainActor
enum Haptics {
    // Reused and kept "prepared" so feedback fires with no delay; creating a generator per tap adds latency.
    private static let impact = UIImpactFeedbackGenerator(style: .light)
    private static let notification = UINotificationFeedbackGenerator()

    static var enabled: Bool { UserDefaults.standard.object(forKey: SettingsKey.haptics) as? Bool ?? true }

    static func tap() {
        guard enabled else { return }
        impact.impactOccurred()
        impact.prepare()
    }

    static func notify(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        guard enabled else { return }
        notification.notificationOccurred(type)
        notification.prepare()
    }
}
