import SpriteKit
import SwiftUI

/// The entire bridge between SwiftUI and SpriteKit. SwiftUI knows about SpriteKit only here,
/// and the scene knows nothing about SwiftUI at all.
struct GameViewRepresentable: UIViewRepresentable {

    func makeUIView(context: Context) -> SKView {
        let view = SKView(frame: .zero)
        view.ignoresSiblingOrder = true
        view.isMultipleTouchEnabled = true
        view.preferredFramesPerSecond = 120

        // Present immediately rather than waiting for a non-zero bounds in `updateUIView`:
        // SwiftUI does not promise another update pass after layout, so gating on the view's
        // size there can leave the scene un-presented forever. `.resizeFill` means the scene
        // adopts the real size as soon as the view is laid out, and `didChangeSize` rebuilds.
        let scene = GameScene(size: CGSize(width: 402, height: 874))
        scene.scaleMode = .resizeFill
        view.presentScene(scene)
        return view
    }

    func updateUIView(_ view: SKView, context: Context) {}
}
