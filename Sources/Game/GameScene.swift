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

    /// Player 0 is always the human.
    static let humanIndex = 0

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
    /// The match is over as far as the player is concerned — either somebody won, or the human
    /// was knocked out. Nobody wants to sit and watch four bots finish without them.
    private var presentationOver = false

    private let art = ArtFactory()
    /// Everything on the pitch lives in here, so a goal can shake the world without shaking
    /// the HUD along with it.
    private let world = SKNode()
    private var hud: HUDNode?
    private let sfx: SFX
    private var goalNodes: [GoalNode] = []
    private var playerNodes: [Int: PlayerNode] = [:]
    private var ballNode: BallNode?
    private var ballRoll: CGFloat = 0
    private var scuffCountdown = 0

    private var projection = Projection(centre: .zero, pointsPerMetre: 1, tilt: Theme.tilt)

    /// Player 0 is the human. Their input comes from thumbs; everyone else's from a brain.
    private var touch = TouchController()
    private var joystick: JoystickNode?
    private var shootButton: ActionButtonNode?
    private var tackleButton: ActionButtonNode?
    private var touchIDs: [ObjectIdentifier: Int] = [:]
    private var nextTouchID = 0

    init(size: CGSize,
         lineup: [Nation],
         difficulty: BotDifficulty = .normal,
         seed: UInt64 = 20_260_912,
         soundEnabled: Bool = true,
         tuning: Tuning = .default) {
        self.tuning = tuning
        self.sfx = SFX(enabled: soundEnabled)
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
        // A scene that has just been presented is holding nobody's thumb. Without this, a
        // touch that began before the scene existed — during the transition out of the menu,
        // say — can leave the stick engaged with no finger on it, and the player walks off on
        // their own.
        touch.cancelAll()
        build()
    }

    override func willMove(from view: SKView) {
        touch.cancelAll()
        sfx.stop()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        guard size.width > 1, size.height > 1 else { return }
        build()
    }

    // MARK: Building

    private func build() {
        removeAllChildren()
        world.removeAllChildren()
        world.position = .zero
        addChild(world)
        goalNodes.removeAll()
        playerNodes.removeAll()

        let pointsPerMetre = Theme.pointsPerMetre(viewSize: size, pitchRadius: tuning.pitchRadius)
        // Nudged down a little: the tilt spends the top of the screen on figures standing up
        // and on the HUD, so the pitch itself wants to sit lower than dead centre.
        projection = Projection(centre: CGPoint(x: size.width / 2, y: size.height * 0.46),
                                pointsPerMetre: pointsPerMetre,
                                tilt: Theme.tilt)

        let lineWidth = max(1.5, CGFloat(0.08) * pointsPerMetre)
        world.addChild(ArenaNode(sceneSize: size,
                                 projection: projection,
                                 radius: tuning.pitchRadius,
                                 lineWidth: lineWidth))

        for player in engine.state.players {
            let goal = GoalNode(goal: player.index,
                                arena: engine.state.arena,
                                colour: player.nation.shirt.uiColor,
                                projection: projection,
                                lineWidth: lineWidth)
            if !engine.state.arena.isOpen[player.index] { goal.seal() }
            goalNodes.append(goal)
            world.addChild(goal)
        }

        let figureDiameter = projection.length(tuning.playerRadius * 2) * Theme.figureScale
        for player in engine.state.players where player.isAlive {
            let node = PlayerNode(texture: art.figure(nation: player.nation,
                                                      appearance: player.appearance,
                                                      diameter: figureDiameter),
                                  diameter: figureDiameter,
                                  footprint: projection.footprint(radius: tuning.playerRadius),
                                  lift: projection.rise(Theme.figureLift),
                                  isHuman: player.index == GameScene.humanIndex)
            playerNodes[player.index] = node
            world.addChild(node)
        }

        let ballDiameter = max(6, projection.length(tuning.ballRadius * 2) * 2.2)
        let ball = BallNode(texture: art.ball(diameter: ballDiameter),
                            diameter: ballDiameter,
                            footprint: projection.footprint(radius: tuning.ballRadius * 1.7),
                            lift: projection.rise(tuning.ballRadius * 1.6))
        ballNode = ball
        world.addChild(ball)

        let panel = HUDNode(players: engine.state.players, sceneSize: size,
                            limit: tuning.concedesToElimination)
        panel.update(players: engine.state.players)
        hud = panel
        addChild(panel)

        buildControls()

        snapNextFrame = true
        render(blend: 1)
    }

    private func buildControls() {
        // Landscape puts the circle in the middle and leaves a margin each side; the thumbs
        // live in those margins rather than on top of the pitch.
        let stickRadius = min(size.height * 0.16, 56)
        let shootRadius = min(size.height * 0.13, 46)
        let tackleRadius = shootRadius * 0.74

        let shootCentre = CGPoint(x: size.width - shootRadius * 1.5, y: shootRadius * 1.5)
        // Up and to the left of shoot: reachable with the same thumb without ever being on the
        // way to it, since hitting tackle when you meant to shoot is the worse mistake.
        let tackleCentre = CGPoint(x: shootCentre.x - shootRadius * 1.85,
                                   y: shootCentre.y + shootRadius * 0.85)

        touch.layout.stickRadius = Double(stickRadius)
        touch.layout.shootCentre = Vec2(x: Double(shootCentre.x), y: Double(shootCentre.y))
        touch.layout.shootRadius = Double(shootRadius)
        touch.layout.tackleCentre = Vec2(x: Double(tackleCentre.x), y: Double(tackleCentre.y))
        touch.layout.tackleRadius = Double(tackleRadius)

        let stick = JoystickNode(radius: stickRadius)
        joystick = stick
        addChild(stick)

        let shoot = ActionButtonNode(radius: shootRadius, title: "SHOOT",
                                     tint: UIColor(red: 1, green: 0.82, blue: 0.25, alpha: 0.95))
        shoot.position = shootCentre
        shootButton = shoot
        addChild(shoot)

        let tackle = ActionButtonNode(radius: tackleRadius, title: "TACKLE",
                                      tint: UIColor(red: 0.45, green: 0.78, blue: 1, alpha: 0.95))
        tackle.position = tackleCentre
        tackleButton = tackle
        addChild(tackle)
    }

    // MARK: Loop

    override func update(_ currentTime: TimeInterval) {
        guard let last = lastFrameTime else {
            lastFrameTime = currentTime
            return
        }
        lastFrameTime = currentTime
        guard !engine.state.isOver, !presentationOver else { return }

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
            if engine.state.isOver || presentationOver { break }
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

        let human = engine.state.players[GameScene.humanIndex]
        // The button says whether a shot is actually on, which is the answer to "why didn't
        // it do anything?" — far more use than a charge meter now that shooting is a tap.
        let canShoot = human.isAlive
            && !human.isStaggered
            && KickResolver.canStrike(body: human.body, ball: engine.state.ball, tuning: tuning)
        shootButton?.render(charge: 0, pressed: touch.isShootDown, ready: canShoot)
        tackleButton?.render(charge: 0,
                             pressed: touch.isTackleDown,
                             ready: human.dashCooldown <= 0 && !human.isStaggered)
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
                            at: Vec2(x: Double(point.x), y: Double(point.y)))
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
            touch.touchUp(id: identify(uiTouch))
            touchIDs.removeValue(forKey: ObjectIdentifier(uiTouch))
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesEnded(touches, with: event)
    }

    private func handle(_ events: [MatchEvent]) {
        for event in events {
            switch event {
            case .kicked(_, let power):
                sfx.play(.kick, volume: Float(0.45 + 0.55 * power))

            case .tackled:
                sfx.play(.touch, volume: 1)

            case .dashed:
                sfx.play(.dash, volume: 0.8)

            case .shoved:
                sfx.play(.touch, volume: 0.9)

            case .ballHitPost(let speed):
                sfx.play(.post, volume: Float(min(1, 0.35 + speed / 18)))

            case .ballHitWall(let speed):
                // Only the ones you would actually hear; a ball trickling into the paint
                // should not click.
                if speed > 3 { sfx.play(.wall, volume: Float(min(0.8, speed / 22))) }

            case .conceded(let goal, let scorer, let ownGoal):
                sfx.play(.goal)
                hud?.update(players: engine.state.players)
                hud?.announce(conceded: engine.state.players[goal],
                              ownGoal: ownGoal,
                              duration: tuning.celebrationDuration)
                shake(strength: ownGoal ? 7 : 5)
                _ = scorer

            case .redeemed(let player):
                hud?.update(players: engine.state.players)
                sfx.play(.touch, volume: 0.9)
                if player == GameScene.humanIndex {
                    hud?.announce(text: "ONE BACK", colour: engine.state.players[player].nation.shirt.uiColor)
                    hud?.dismissAfter(1.1)
                }

            case .eliminated(let player, let place):
                goalNodes[player].seal()
                playerNodes[player]?.fadeOutEliminated()
                playerNodes[player] = nil
                hud?.update(players: engine.state.players)
                hud?.announce(eliminated: engine.state.players[player])
                sfx.play(.eliminated)

                // The human going out ends the match. Watching four bots play on without you
                // is not a reward for losing.
                if player == GameScene.humanIndex, engine.state.aliveCount > 1 {
                    finishPresentation(headline: "YOU ARE OUT", place: place)
                }

            case .resumed, .ballReset:
                snapNextFrame = true
                guard case .resumed = event else { break }
                sfx.play(.whistle, volume: 0.5)

                // Say so when the restart is yours. It already was — the ball is at your feet
                // at the whistle and the rivals stand off — but a player who has just watched
                // a goal go in has no way of knowing that, and a possession nobody tells you
                // about is one you spend watching somebody else take it.
                if engine.state.restartTaker == GameScene.humanIndex {
                    let human = engine.state.players[GameScene.humanIndex]
                    hud?.announce(text: "YOUR BALL", colour: human.nation.shirt.uiColor)
                    hud?.dismissAfter(1.1)
                }

            case .finished:
                if let winner = engine.state.winner {
                    hud?.announce(winner: engine.state.players[winner])
                }
                sfx.play(.whistle)
                finishPresentation(headline: nil, place: nil)

            default:
                break
            }
        }
    }

    /// Hands the result to the app and stops simulating, after a beat so the last goal is
    /// seen rather than swallowed by a screen change.
    ///
    /// `place` is supplied when the human was knocked out, because the standings alone cannot
    /// say where they finished while several players are still in.
    private func finishPresentation(headline: String?, place: Int?) {
        guard !presentationOver else { return }
        presentationOver = true

        if let headline {
            hud?.announce(text: headline, colour: Theme.sealed)
        }

        let summary = MatchSummary(state: engine.state, humanPlace: place)
        run(.sequence([
            .wait(forDuration: 1.6),
            .run { [weak self] in
                guard let self else { return }
                self.matchDelegate?.gameScene(self, didFinishWith: summary)
            },
        ]))
    }

    // MARK: Drawing

    private func render(blend: CGFloat) {
        let state = engine.state

        for player in state.players where player.isAlive {
            guard let node = playerNodes[player.index] else { continue }
            let before = previous.players[player.index].body
            let now = player.body

            let ground = lerp(before.position, now.position, blend)
            node.render(position: projection.point(ground),
                        facing: CGFloat(lerpAngle(before.facing, now.facing, blend)),
                        staggered: player.isStaggered,
                        dashing: player.isDashing,
                        depth: projection.depth(ground, within: tuning.pitchRadius))
        }

        let ballBefore = previous.ball.position
        let ballNow = state.ball.position
        let drawn = lerp(ballBefore, ballNow, blend)

        // Roll the ball by how far it actually travelled, so it never spins on the spot.
        if !snapNextFrame {
            ballRoll -= CGFloat(ballNow.distance(to: ballBefore) / tuning.ballRadius) * 0.35
        }
        ballNode?.render(position: projection.point(drawn), roll: ballRoll,
                         depth: projection.depth(drawn, within: tuning.pitchRadius))

        scuffCountdown -= 1
        if !snapNextFrame, scuffCountdown <= 0, state.ball.velocity.length > 7 {
            scuffCountdown = 3
            leaveScuff(at: drawn)
        }
    }

    /// A short, decaying nudge of the pitch. Deliberately small — anything bigger loses the
    /// ball for a moment, which is the one thing the player cannot afford.
    private func shake(strength: CGFloat) {
        world.removeAction(forKey: "shake")
        var steps: [SKAction] = []
        var amount = strength
        var rng = SeededRandom(seed: UInt64(engine.state.elapsed * 1000))
        while amount > 0.4 {
            steps.append(.move(to: CGPoint(x: CGFloat(rng.double(in: -1...1)) * amount,
                                           y: CGFloat(rng.double(in: -1...1)) * amount),
                               duration: 0.035))
            amount *= 0.62
        }
        steps.append(.move(to: .zero, duration: 0.05))
        world.run(.sequence(steps), withKey: "shake")
    }

    /// A scuff of the ball on concrete, left behind when it is really moving. It lies in the
    /// ground plane, so it is squashed by the tilt like every other footprint.
    private func leaveScuff(at ground: Vec2) {
        let scuff = SKShapeNode(ellipseOf: projection.footprint(radius: tuning.ballRadius * 1.1))
        scuff.position = projection.point(ground)
        scuff.fillColor = UIColor(white: 1, alpha: 0.14)
        scuff.strokeColor = .clear
        scuff.zPosition = Theme.Layer.paintwork.rawValue + 2
        world.addChild(scuff)
        scuff.run(.sequence([
            .group([.fadeOut(withDuration: 0.32), .scale(to: 0.4, duration: 0.32)]),
            .removeFromParent(),
        ]))
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
