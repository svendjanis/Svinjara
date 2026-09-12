import SpriteKit

/// Told when a match is over, so the SwiftUI layer can show the results. The scene knows
/// nothing about SwiftUI beyond this one method.
protocol GameSceneDelegate: AnyObject {
    func gameScene(_ scene: GameScene, didFinishWith summary: MatchSummary)
}

/// Owns the match: steps the simulation on a fixed clock and draws whatever the resulting
/// state says. It holds no rules of its own — see `docs/ARCHITECTURE.md` §2.
final class GameScene: SKScene {

    weak var matchDelegate: GameSceneDelegate?

    private let tuning: Tuning
    private let lineup: [Nation]
    private let difficulty: BotDifficulty
    private let seed: UInt64

    private var engine: MatchEngine
    private var brains: [BotBrain]

    /// The state before the most recent step, so rendering can interpolate between the two and
    /// stay smooth on a 60 Hz display while the simulation runs at 120.
    private var previous: MatchState
    private var accumulator: Double = 0
    private var lastFrameTime: TimeInterval?
    /// Set after anything that teleports the world, so the next frame snaps instead of sliding.
    private var snapNextFrame = true

    private let art = ArtFactory()
    private var goalNodes: [GoalNode] = []
    private var playerNodes: [Int: PlayerNode] = [:]
    private var ballNode: BallNode?
    private var ballRoll: CGFloat = 0

    private var pointsPerMetre: CGFloat = 1
    private var pitchCentre: CGPoint = .zero

    /// Player 0 is the human. Their input comes from thumbs; everyone else's from a brain.
    private var touch = TouchController()
    private var joystick: JoystickNode?
    private var kickButton: KickButtonNode?
    private var touchIDs: [ObjectIdentifier: Int] = [:]
    private var nextTouchID = 0

    init(size: CGSize,
         lineup: [Nation],
         difficulty: BotDifficulty = .normal,
         seed: UInt64 = 20_260_912,
         tuning: Tuning = .default) {
        self.tuning = tuning
        self.lineup = lineup
        self.difficulty = difficulty
        self.seed = seed
        self.engine = MatchEngine(nations: lineup, tuning: tuning, appearanceSeed: seed)
        self.brains = (0..<lineup.count).map {
            BotBrain(index: $0, difficulty: difficulty, seed: seed)
        }
        self.previous = engine.state
        super.init(size: size)
        scaleMode = .resizeFill
        backgroundColor = Theme.concrete
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not supported") }

    override func didMove(to view: SKView) {
        build()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        guard size.width > 1, size.height > 1 else { return }
        build()
    }

    // MARK: Building

    private func build() {
        removeAllChildren()
        goalNodes.removeAll()
        playerNodes.removeAll()

        pointsPerMetre = Theme.pointsPerMetre(viewSize: size, pitchRadius: tuning.pitchRadius)
        pitchCentre = CGPoint(x: size.width / 2, y: size.height / 2)

        let lineWidth = max(1.5, CGFloat(0.08) * pointsPerMetre)
        addChild(ArenaNode(sceneSize: size,
                           centre: pitchCentre,
                           radius: CGFloat(tuning.pitchRadius) * pointsPerMetre,
                           lineWidth: lineWidth))

        for player in engine.state.players {
            let goal = GoalNode(goal: player.index,
                                arena: engine.state.arena,
                                colour: player.nation.shirt.uiColor,
                                centre: pitchCentre,
                                pointsPerMetre: pointsPerMetre,
                                lineWidth: lineWidth)
            if !engine.state.arena.isOpen[player.index] { goal.seal() }
            goalNodes.append(goal)
            addChild(goal)
        }

        let figureDiameter = CGFloat(tuning.playerRadius * 2) * pointsPerMetre * Theme.figureScale
        for player in engine.state.players where player.isAlive {
            let node = PlayerNode(texture: art.figure(nation: player.nation,
                                                      appearance: player.appearance,
                                                      diameter: figureDiameter),
                                  diameter: figureDiameter,
                                  isHuman: player.index == 0)
            playerNodes[player.index] = node
            addChild(node)
        }

        let ballDiameter = max(6, CGFloat(tuning.ballRadius * 2) * pointsPerMetre * 2.2)
        let ball = BallNode(texture: art.ball(diameter: ballDiameter), diameter: ballDiameter)
        ballNode = ball
        addChild(ball)

        buildControls()

        snapNextFrame = true
        render(blend: 1)
    }

    private func buildControls() {
        // Landscape puts the circle in the middle and leaves a margin each side; the thumbs
        // live in those margins rather than on top of the pitch.
        let stickRadius = min(size.height * 0.16, 56)
        touch.layout.stickRadius = Double(stickRadius)
        touch.layout.doubleTapWindow = tuning.dashDoubleTapWindow

        let stick = JoystickNode(radius: stickRadius)
        joystick = stick
        addChild(stick)

        let button = KickButtonNode(radius: stickRadius * 0.72)
        button.position = CGPoint(x: size.width - stickRadius * 1.4, y: stickRadius * 1.4)
        kickButton = button
        addChild(button)
    }

    // MARK: Loop

    override func update(_ currentTime: TimeInterval) {
        guard let last = lastFrameTime else {
            lastFrameTime = currentTime
            return
        }
        lastFrameTime = currentTime
        guard !engine.state.isOver else { return }

        // Clamped: coming back from the background must not spiral into thousands of catch-up
        // steps, which would look like the match fast-forwarding without you.
        accumulator += min(0.25, currentTime - last)

        while accumulator >= tuning.fixedStep {
            previous = engine.state
            var inputs = (0..<lineup.count).map {
                brains[$0].decide(state: engine.state, tuning: tuning)
            }
            // One consume per simulation step, so a release or a lunge lands on exactly one
            // step however many frames the finger was down for.
            inputs[0] = touch.consume()
            handle(engine.step(inputs: inputs))
            accumulator -= tuning.fixedStep
            if engine.state.isOver { break }
        }

        render(blend: snapNextFrame ? 1 : CGFloat(accumulator / tuning.fixedStep))
        renderControls()
        snapNextFrame = false
    }

    private func renderControls() {
        if let origin = touch.stickOrigin {
            let offset = touch.stickOffset
            joystick?.show(origin: CGPoint(x: CGFloat(origin.x), y: CGFloat(origin.y)),
                           offset: CGPoint(x: CGFloat(offset.x), y: CGFloat(offset.y)))
        } else {
            joystick?.hide()
        }

        let human = engine.state.players[0]
        kickButton?.render(charge: CGFloat(human.chargeFraction(tuning: tuning)),
                           pressed: touch.isKickDown)
    }

    // MARK: Touches

    private func identify(_ uiTouch: UITouch) -> Int {
        let key = ObjectIdentifier(uiTouch)
        if let existing = touchIDs[key] { return existing }
        nextTouchID += 1
        touchIDs[key] = nextTouchID
        return nextTouchID
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for uiTouch in touches {
            let point = uiTouch.location(in: self)
            touch.touchDown(id: identify(uiTouch),
                            at: Vec2(x: Double(point.x), y: Double(point.y)),
                            onKickSide: point.x > size.width / 2,
                            now: uiTouch.timestamp)
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for uiTouch in touches {
            let point = uiTouch.location(in: self)
            touch.touchMoved(id: identify(uiTouch), to: Vec2(x: Double(point.x), y: Double(point.y)))
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for uiTouch in touches {
            touch.touchUp(id: identify(uiTouch), now: uiTouch.timestamp)
            touchIDs.removeValue(forKey: ObjectIdentifier(uiTouch))
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesEnded(touches, with: event)
    }

    private func handle(_ events: [MatchEvent]) {
        for event in events {
            switch event {
            case .eliminated(let player, _):
                goalNodes[player].seal()
                playerNodes[player]?.fadeOutEliminated()
                playerNodes[player] = nil

            case .resumed, .ballReset:
                snapNextFrame = true

            case .finished:
                // A short beat before the results appear, so the last goal is seen rather
                // than swallowed by a screen change.
                let summary = MatchSummary(state: engine.state)
                run(.sequence([
                    .wait(forDuration: 1.4),
                    .run { [weak self] in
                        guard let self else { return }
                        self.matchDelegate?.gameScene(self, didFinishWith: summary)
                    },
                ]))

            default:
                break
            }
        }
    }

    // MARK: Drawing

    private func render(blend: CGFloat) {
        let state = engine.state

        for player in state.players where player.isAlive {
            guard let node = playerNodes[player.index] else { continue }
            let before = previous.players[player.index].body
            let now = player.body

            node.render(position: screen(lerp(before.position, now.position, blend)),
                        facing: CGFloat(lerpAngle(before.facing, now.facing, blend)),
                        staggered: player.isStaggered,
                        dashing: player.isDashing)
        }

        let ballBefore = previous.ball.position
        let ballNow = state.ball.position
        let drawn = lerp(ballBefore, ballNow, blend)

        // Roll the ball by how far it actually travelled, so it never spins on the spot.
        if !snapNextFrame {
            ballRoll -= CGFloat(ballNow.distance(to: ballBefore) / tuning.ballRadius) * 0.35
        }
        ballNode?.render(position: screen(drawn), roll: ballRoll)
    }

    private func screen(_ point: Vec2) -> CGPoint {
        CGPoint(x: pitchCentre.x + CGFloat(point.x) * pointsPerMetre,
                y: pitchCentre.y + CGFloat(point.y) * pointsPerMetre)
    }

    private func lerp(_ a: Vec2, _ b: Vec2, _ t: CGFloat) -> Vec2 {
        a + (b - a) * Double(t)
    }

    /// Interpolating a bearing has to go the short way round, or a figure crossing ±π spins
    /// the long way once per lap.
    private func lerpAngle(_ a: Double, _ b: Double, _ t: CGFloat) -> Double {
        Angles.normalize(a + Angles.delta(from: a, to: b) * Double(t))
    }
}
