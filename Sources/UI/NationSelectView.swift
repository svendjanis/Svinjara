import SwiftUI

struct NationSelectView: View {
    @Bindable var model: AppModel

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 7)

    /// Fixed so the preview figure does not change face every time the grid redraws.
    private var previewAppearance: Appearance {
        AppearanceFactory.make(seed: UInt64(abs(model.chosenNation.id.hashValue % 100_000)))
    }

    var body: some View {
        HStack(spacing: 22) {
            VStack(alignment: .leading, spacing: 10) {
                Text("WHO ARE YOU?")
                    .font(.custom("AvenirNextCondensed-Bold", size: 26))
                    .foregroundStyle(Color(Theme.paint))

                ScrollView {
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(NationCatalog.all) { nation in
                            Button { model.choose(nation) } label: {
                                VStack(spacing: 3) {
                                    KitSwatch(nation: nation, height: 40)
                                    Text(nation.name.uppercased())
                                        .font(.custom("AvenirNextCondensed-Bold", size: 9))
                                        .foregroundStyle(Color(Theme.paint).opacity(0.8))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.6)
                                }
                                .padding(5)
                                .background {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(nation == model.chosenNation
                                              ? Color.white.opacity(0.18) : .clear)
                                }
                            }
                        }
                    }
                    .padding(.bottom, 6)
                }
            }

            VStack(spacing: 12) {
                FigurePreview(nation: model.chosenNation, appearance: previewAppearance, size: 104)
                Text(model.chosenNation.name.uppercased())
                    .font(.custom("AvenirNextCondensed-Bold", size: 22))
                    .foregroundStyle(Color(Theme.paint))

                Button {
                    model.kickOff()
                } label: {
                    Text("KICK OFF")
                        .font(.custom("AvenirNextCondensed-Bold", size: 24))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 26)
                        .padding(.vertical, 10)
                        .background(Color(Theme.paint), in: Capsule())
                }

                Button { model.show(.menu) } label: {
                    Text("BACK")
                        .font(.custom("AvenirNextCondensed-Bold", size: 15))
                        .foregroundStyle(Color(Theme.paint).opacity(0.55))
                }
            }
            .frame(width: 168)
        }
        .padding(.horizontal, 34)
        .padding(.vertical, 20)
    }
}
