import SwiftUI

struct MenuView: View {
    @Bindable var model: AppModel

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text("SVINJARA")
                    .font(.custom("AvenirNextCondensed-Bold", size: 64))
                    .foregroundStyle(Color(Theme.paint))
                Text("Five goals. Four rivals. Let six in and you walk home.")
                    .font(.custom("AvenirNextCondensed-Medium", size: 17))
                    .foregroundStyle(Color(Theme.paint).opacity(0.65))

                Spacer().frame(height: 22)

                Button {
                    model.show(.nationSelect)
                } label: {
                    Text("PLAY")
                        .font(.custom("AvenirNextCondensed-Bold", size: 30))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 44)
                        .padding(.vertical, 12)
                        .background(Color(Theme.paint), in: Capsule())
                }

                if model.stats.played > 0 {
                    Spacer().frame(height: 16)
                    statsLine
                }
            }

            Spacer(minLength: 24)

            VStack(alignment: .leading, spacing: 18) {
                difficultyPicker
                soundToggle
            }
            .frame(maxWidth: 260)
        }
        .padding(.horizontal, 46)
        .padding(.vertical, 28)
    }

    private var statsLine: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("\(model.stats.played) played · \(model.stats.won) won")
                .font(.custom("AvenirNextCondensed-Bold", size: 17))
                .foregroundStyle(Color(Theme.paint).opacity(0.8))
            if model.stats.bestPlace > 0 {
                Text("best finish: \(ordinal(model.stats.bestPlace))")
                    .font(.custom("AvenirNextCondensed-Medium", size: 15))
                    .foregroundStyle(Color(Theme.paint).opacity(0.5))
            }
        }
    }

    private var difficultyPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("RIVALS")
                .font(.custom("AvenirNextCondensed-Bold", size: 14))
                .foregroundStyle(Color(Theme.paint).opacity(0.45))
            HStack(spacing: 8) {
                ForEach(BotDifficulty.all) { tier in
                    Button {
                        model.choose(tier)
                    } label: {
                        Text(tier.title.uppercased())
                            .font(.custom("AvenirNextCondensed-Bold", size: 16))
                            .foregroundStyle(tier == model.difficulty ? .black : Color(Theme.paint))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background {
                                Capsule().fill(tier == model.difficulty
                                               ? Color(Theme.paint)
                                               : Color.white.opacity(0.09))
                            }
                    }
                }
            }
        }
    }

    private var soundToggle: some View {
        Toggle(isOn: $model.soundEnabled) {
            Text("SOUND")
                .font(.custom("AvenirNextCondensed-Bold", size: 14))
                .foregroundStyle(Color(Theme.paint).opacity(0.45))
        }
        .tint(Color(Theme.paint).opacity(0.75))
    }

    private func ordinal(_ place: Int) -> String {
        switch place {
        case 1: return "1st"
        case 2: return "2nd"
        case 3: return "3rd"
        default: return "\(place)th"
        }
    }
}
