import SwiftUI

struct ResultsView: View {
    @Bindable var model: AppModel
    let summary: MatchSummary

    var body: some View {
        HStack(spacing: 26) {
            VStack(alignment: .leading, spacing: 4) {
                Text(headline)
                    .font(.custom("AvenirNextCondensed-Bold", size: 40))
                    .foregroundStyle(Color(Theme.paint))
                if let winner = summary.winner {
                    Text("\(winner.nation.name.uppercased()) TAKES IT")
                        .font(.custom("AvenirNextCondensed-Medium", size: 16))
                        .foregroundStyle(Color(Theme.paint).opacity(0.6))
                }

                Spacer().frame(height: 18)

                Button { model.kickOff() } label: {
                    Text("REMATCH")
                        .font(.custom("AvenirNextCondensed-Bold", size: 24))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 30)
                        .padding(.vertical, 10)
                        .background(Color(Theme.paint), in: Capsule())
                }

                Button { model.show(.menu) } label: {
                    Text("MENU")
                        .font(.custom("AvenirNextCondensed-Bold", size: 15))
                        .foregroundStyle(Color(Theme.paint).opacity(0.55))
                }
                .padding(.top, 4)
            }

            VStack(spacing: 6) {
                ForEach(summary.entries, id: \.index) { entry in
                    row(entry)
                }
            }
            .frame(maxWidth: 340)
        }
        .padding(.horizontal, 42)
        .padding(.vertical, 22)
    }

    private var headline: String {
        guard let human = summary.human else { return "FULL TIME" }
        return human.place == 1 ? "YOU WIN" : "\(ordinal(human.place)) OF 5"
    }

    private func row(_ entry: MatchSummary.Entry) -> some View {
        HStack(spacing: 10) {
            Text("\(entry.place)")
                .font(.custom("AvenirNextCondensed-Bold", size: 19))
                .foregroundStyle(Color(Theme.paint).opacity(entry.place == 1 ? 1 : 0.45))
                .frame(width: 18)

            KitSwatch(nation: entry.nation, height: 30)

            Text(entry.nation.name.uppercased())
                .font(.custom("AvenirNextCondensed-Bold", size: 16))
                .foregroundStyle(Color(Theme.paint).opacity(entry.isHuman ? 1 : 0.75))

            if entry.isHuman {
                Text("YOU")
                    .font(.custom("AvenirNextCondensed-Bold", size: 10))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color(Theme.paint), in: Capsule())
            }

            Spacer()

            ConcededPips(conceded: entry.conceded, colour: entry.nation.shirt.uiColor)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(entry.isHuman ? Color.white.opacity(0.12) : Color.white.opacity(0.04))
        }
    }

    private func ordinal(_ place: Int) -> String {
        switch place {
        case 1: return "1ST"
        case 2: return "2ND"
        case 3: return "3RD"
        default: return "\(place)TH"
        }
    }
}

/// Six pips, filling as they let them in. No numbers — the eye reads a row of dots faster than
/// it reads a digit, which matters when this is also the in-match HUD.
struct ConcededPips: View {
    let conceded: Int
    var colour: UIColor = Theme.paint
    var limit: Int = Tuning.default.concedesToElimination
    var size: CGFloat = 7

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<limit, id: \.self) { index in
                Circle()
                    .fill(index < conceded ? Color(colour) : Color(Theme.paint).opacity(0.18))
                    .frame(width: size, height: size)
            }
        }
    }
}
