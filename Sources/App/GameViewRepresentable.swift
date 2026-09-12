import SpriteKit
import SwiftUI

/// The entire bridge between SwiftUI and SpriteKit. SwiftUI knows about SpriteKit only here,
/// and the scene knows nothing about SwiftUI at all — it reports back through one protocol
/// with one method.
struct GameViewRepresentable: UIViewRepresentable {

    let lineup: [Nation]
    let difficulty: BotDifficulty
    let seed: UInt64
    let soundEnabled: Bool
    let onFinish: (MatchSummary) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onFinish: onFinish)
    }

    func makeUIView(context: Context) -> SKView {
        let view = SKView(frame: .zero)
        view.ignoresSiblingOrder = true
        view.isMultipleTouchEnabled = true
        view.preferredFramesPerSecond = 120

        // Present immediately rather than waiting for a non-zero bounds in `updateUIView`:
        // SwiftUI does not promise another update pass after layout, so gating on the view's
        // size there can leave the scene un-presented forever. `.resizeFill` means the scene
        // adopts the real size as soon as the view is laid out.
        let scene = GameScene(size: CGSize(width: 874, height: 402),
                              lineup: lineup,
                              difficulty: difficulty,
                              seed: seed,
                              soundEnabled: soundEnabled)
        scene.matchDelegate = context.coordinator
        scene.scaleMode = .resizeFill
        view.presentScene(scene)
        return view
    }

    func updateUIView(_ view: SKView, context: Context) {}

    final class Coordinator: NSObject, GameSceneDelegate {
        private let onFinish: (MatchSummary) -> Void

        init(onFinish: @escaping (MatchSummary) -> Void) {
            self.onFinish = onFinish
        }

        func gameScene(_ scene: GameScene, didFinishWith summary: MatchSummary) {
            onFinish(summary)
        }
    }
}
