import SwiftUI

struct BoardView: View {
    @EnvironmentObject private var vm: GameViewModel
    @AppStorage(SettingsKey.symbolStyle) private var symbolStyle = SymbolStyle.shapes.rawValue
    @AppStorage(SettingsKey.highlightMistakes) private var highlightMistakes = true
    @AppStorage(SettingsKey.highlightRelated) private var highlightRelated = true
    @AppStorage(SettingsKey.highlightSameColor) private var highlightSameColor = true
    let game: Game

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let cell = side / 9
            let style = SymbolStyle(rawValue: symbolStyle) ?? .shapes
            let selectedValue = vm.selected.map { game.values[$0] } ?? 0

            ZStack(alignment: .topLeading) {
                VStack(spacing: 0) {
                    ForEach(0..<9, id: \.self) { r in
                        HStack(spacing: 0) {
                            ForEach(0..<9, id: \.self) { c in
                                let i = r * 9 + c
                                CellView(
                                    value: game.values[i],
                                    notes: game.notes[i],
                                    isGiven: game.isGiven(i),
                                    isSelected: vm.selected == i,
                                    isRelated: highlightRelated && vm.selected.map { Sudoku.areRelated($0, i) } ?? false,
                                    isSameColor: highlightSameColor && selectedValue != 0 && game.values[i] == selectedValue,
                                    isWrong: highlightMistakes && game.isWrong(i),
                                    symbolStyle: style,
                                    size: cell
                                )
                                .frame(width: cell, height: cell)
                                .contentShape(Rectangle())
                                .onTapGesture { vm.select(i) }
                                .accessibilityElement(children: .ignore)
                                .accessibilityLabel(accessibilityLabel(for: i))
                                .accessibilityAddTraits(vm.selected == i ? [.isButton, .isSelected] : .isButton)
                            }
                        }
                    }
                }
                GridLines(every: 1).stroke(Color.secondary.opacity(0.35), lineWidth: 0.5)
                GridLines(every: 3).stroke(Color.primary.opacity(0.75), lineWidth: 2)
                RoundedRectangle(cornerRadius: 4).stroke(Color.primary.opacity(0.85), lineWidth: 2.5)
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
        .animation(.easeOut(duration: 0.15), value: game.values)
    }

    private func accessibilityLabel(for i: Int) -> String {
        let position = "Row \(Sudoku.row(of: i) + 1), column \(Sudoku.column(of: i) + 1)"
        let value = game.values[i]
        if value == 0 {
            let noted = (1...9).filter { game.hasNote($0, at: i) }.map(Palette.name)
            return noted.isEmpty ? "\(position), empty" : "\(position), empty, notes: \(noted.joined(separator: ", "))"
        }
        var label = "\(position), \(Palette.name(value))"
        if game.isGiven(i) { label += ", given" }
        if highlightMistakes && game.isWrong(i) { label += ", incorrect" }
        return label
    }
}

/// Interior grid lines every `every` cells.
private struct GridLines: Shape {
    let every: Int

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let step = rect.width / 9
        for k in stride(from: every, to: 9, by: every) {
            let offset = CGFloat(k) * step
            path.move(to: CGPoint(x: offset, y: 0))
            path.addLine(to: CGPoint(x: offset, y: rect.height))
            path.move(to: CGPoint(x: 0, y: offset))
            path.addLine(to: CGPoint(x: rect.width, y: offset))
        }
        return path
    }
}

struct CellView: View {
    let value: Int
    let notes: UInt16
    let isGiven: Bool
    let isSelected: Bool
    let isRelated: Bool
    let isSameColor: Bool
    let isWrong: Bool
    let symbolStyle: SymbolStyle
    let size: CGFloat

    var body: some View {
        ZStack {
            background
            if value != 0 {
                tile
            } else if notes != 0 {
                notesGrid
            }
        }
    }

    private var background: Color {
        if isSelected { return Color.accentColor.opacity(0.35) }
        if isSameColor { return Color.accentColor.opacity(0.15) }
        if isRelated { return Color.secondary.opacity(0.12) }
        return Color(.systemBackground)
    }

    /// Givens are rounded squares; colors the player placed are circles, so the two are easy to tell apart.
    @ViewBuilder private var tile: some View {
        let color = Palette.color(value)
        ZStack {
            if isGiven {
                RoundedRectangle(cornerRadius: size * 0.2).fill(color.gradient)
                    .padding(size * 0.08)
            } else {
                Circle().fill(color.gradient)
                    .padding(size * 0.1)
            }
            CellSymbol(value: value, style: symbolStyle, onColor: true)
                .padding(size * 0.3)
            if isWrong {
                Circle().strokeBorder(Color.red, lineWidth: max(2, size * 0.07))
                    .padding(size * 0.02)
                Image(systemName: "xmark")
                    .font(.system(size: size * 0.22, weight: .black))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.5), radius: 1)
                    .offset(x: size * 0.28, y: -size * 0.28)
            }
        }
        .scaleEffect(isSameColor && !isSelected ? 1.04 : 1)
        .transition(.scale.combined(with: .opacity))
    }

    private var notesGrid: some View {
        let dot = size * 0.2
        return VStack(spacing: size * 0.07) {
            ForEach(0..<3, id: \.self) { r in
                HStack(spacing: size * 0.07) {
                    ForEach(1...3, id: \.self) { c in
                        let v = r * 3 + c
                        Circle()
                            .fill(notes & (UInt16(1) << v) != 0 ? Palette.color(v) : Color.clear)
                            .frame(width: dot, height: dot)
                    }
                }
            }
        }
    }
}

/// Optional shape or number drawn on top of a color, for color-blind players.
struct CellSymbol: View {
    let value: Int
    let style: SymbolStyle
    /// True when drawn on top of the color itself (white symbol), false on a plain background.
    let onColor: Bool

    var body: some View {
        let tint: Color = onColor ? .white : Palette.color(value)
        switch style {
        case .none:
            EmptyView()
        case .shapes:
            Image(systemName: Palette.shape(value))
                .resizable()
                .scaledToFit()
                .foregroundStyle(tint)
                .shadow(color: .black.opacity(onColor ? 0.35 : 0), radius: 1)
        case .numbers:
            Text("\(value)")
                .font(.system(size: 100, weight: .heavy, design: .rounded))
                .minimumScaleFactor(0.05)
                .foregroundStyle(tint)
                .shadow(color: .black.opacity(onColor ? 0.35 : 0), radius: 1)
        }
    }
}
