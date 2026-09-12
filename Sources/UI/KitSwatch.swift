import SwiftUI

/// A nation's shirt, drawn as a shape rather than as a rendered figure — at grid size the
/// pattern is the only part that reads, and it stays crisp at any scale.
struct KitSwatch: View {
    let nation: Nation
    var height: CGFloat = 52

    private var shirt: Color { Color(nation.shirt.uiColor) }
    private var trim: Color { Color(nation.trim.uiColor) }

    var body: some View {
        ZStack {
            shirt
            pattern
        }
        .frame(width: height * 0.82, height: height)
        .clipShape(RoundedRectangle(cornerRadius: height * 0.18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: height * 0.18, style: .continuous)
                .stroke(.black.opacity(0.35), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var pattern: some View {
        switch nation.pattern {
        case .solid:
            EmptyView()

        case .stripes:
            HStack(spacing: 0) {
                ForEach(0..<7, id: \.self) { index in
                    (index % 2 == 0 ? shirt : trim)
                }
            }

        case .checks:
            GeometryReader { geometry in
                let columns = 4
                let cell = geometry.size.width / CGFloat(columns)
                let rows = Int((geometry.size.height / cell).rounded(.up))
                ForEach(0..<rows, id: \.self) { row in
                    ForEach(0..<columns, id: \.self) { column in
                        if (row + column) % 2 == 0 {
                            Rectangle()
                                .fill(trim)
                                .frame(width: cell, height: cell)
                                .offset(x: CGFloat(column) * cell, y: CGFloat(row) * cell)
                        }
                    }
                }
            }

        case .sash:
            GeometryReader { geometry in
                Path { path in
                    path.move(to: CGPoint(x: 0, y: geometry.size.height * 0.15))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: geometry.size.height * 0.62))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: geometry.size.height * 0.92))
                    path.addLine(to: CGPoint(x: 0, y: geometry.size.height * 0.45))
                    path.closeSubpath()
                }
                .fill(trim)
            }
        }
    }
}

/// The actual figure that will take the pitch, so the player sees who they are picking rather
/// than only what colour they will be.
struct FigurePreview: View {
    let nation: Nation
    let appearance: Appearance
    var size: CGFloat = 96

    var body: some View {
        Image(uiImage: KitPainter.figure(nation: nation, appearance: appearance, diameter: size))
            .resizable()
            .frame(width: size, height: size)
            // Drawn facing +x; turned to face up the screen, which is how you look at somebody.
            .rotationEffect(.degrees(-90))
    }
}
