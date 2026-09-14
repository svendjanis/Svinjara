import XCTest
@testable import Svinjara

final class TouchControllerTests: XCTestCase {

    private let shoot = Vec2(x: 800, y: 70)
    private let tackle = Vec2(x: 715, y: 105)

    private func controller() -> TouchController {
        var controller = TouchController()
        controller.layout = TouchController.Layout(stickRadius: 50, deadZone: 7,
                                                   shootCentre: Vec2(x: 800, y: 70),
                                                   shootRadius: 44,
                                                   tackleCentre: Vec2(x: 715, y: 105),
                                                   tackleRadius: 32,
                                                   touchSlop: 1.35)
        return controller
    }

    // MARK: The stick

    func testTheStickAppearsWhereTheThumbLands() {
        var touch = controller()
        touch.touchDown(id: 1, at: Vec2(x: 90, y: 120))

        XCTAssertEqual(touch.stickOrigin, Vec2(x: 90, y: 120))
        XCTAssertEqual(touch.consume().move, .zero, "no movement until the thumb moves")
    }

    func testDraggingSteersInThatDirection() {
        var touch = controller()
        touch.touchDown(id: 1, at: Vec2(x: 100, y: 100))
        touch.touchMoved(id: 1, to: Vec2(x: 150, y: 100))

        let move = touch.consume().move
        XCTAssertEqual(move.length, 1, accuracy: 1e-9, "a full push is full tilt")
        XCTAssertEqual(move.angle, 0, accuracy: 1e-9)
    }

    func testAHalfPushIsHalfSpeed() {
        var touch = controller()
        touch.touchDown(id: 1, at: Vec2(x: 100, y: 100))
        touch.touchMoved(id: 1, to: Vec2(x: 125, y: 100))
        XCTAssertEqual(touch.consume().move.length, 0.5, accuracy: 1e-9)
    }

    func testPushingBeyondTheRadiusIsStillFullTilt() {
        var touch = controller()
        touch.touchDown(id: 1, at: Vec2(x: 100, y: 100))
        touch.touchMoved(id: 1, to: Vec2(x: 400, y: 100))
        XCTAssertEqual(touch.consume().move.length, 1, accuracy: 1e-9)
    }

    /// The stick follows the thumb once the thumb leaves the ring.
    ///
    /// Without this the origin stays where the thumb first landed and the heading is measured
    /// from there for as long as the finger is down — so a thumb dragged well past the rim has
    /// to be dragged all the way back before it can point anywhere else. You ask for left, and
    /// keep running right.
    func testTheStickFollowsAThumbThatLeavesTheRing() {
        var touch = controller()
        touch.touchDown(id: 1, at: .zero)
        touch.touchMoved(id: 1, to: Vec2(x: 300, y: 0))

        XCTAssertEqual(touch.stickOrigin?.x ?? 0, 250, accuracy: 1e-9,
                       "the origin is dragged up to one radius behind the thumb")
        XCTAssertEqual(touch.consume().move.angle, 0, accuracy: 1e-9)
    }

    func testAFlickBackAfterALongDragTurnsImmediately() {
        var touch = controller()
        touch.touchDown(id: 1, at: .zero)
        touch.touchMoved(id: 1, to: Vec2(x: 300, y: 0))
        // A thumb that has run a long way right, now asked for hard left.
        touch.touchMoved(id: 1, to: Vec2(x: 200, y: 0))

        let move = touch.consume().move
        XCTAssertEqual(Angles.separation(move.angle, .pi), 0, accuracy: 1e-9,
                       "a 100 pt flick back must mean left, not a slightly slower right")
        XCTAssertEqual(move.length, 1, accuracy: 1e-9)
    }

    /// The stick never drifts while the thumb is inside the ring, or a slow circling thumb
    /// would tow the origin around with it and lose the centre.
    func testTheStickDoesNotMoveWhileTheThumbIsInsideTheRing() {
        var touch = controller()
        touch.touchDown(id: 1, at: Vec2(x: 100, y: 100))
        for point in [Vec2(x: 130, y: 100), Vec2(x: 100, y: 140), Vec2(x: 70, y: 90)] {
            touch.touchMoved(id: 1, to: point)
            XCTAssertEqual(touch.stickOrigin, Vec2(x: 100, y: 100))
        }
    }

    func testTinyMovementsAreHoldingStillNotWalking() {
        var touch = controller()
        touch.touchDown(id: 1, at: Vec2(x: 100, y: 100))
        touch.touchMoved(id: 1, to: Vec2(x: 104, y: 102))
        XCTAssertEqual(touch.consume().move, .zero)
    }

    func testEveryDirectionIsReachable() {
        for bearing in stride(from: -Double.pi, to: Double.pi, by: 0.3) {
            var touch = controller()
            touch.touchDown(id: 1, at: .zero)
            touch.touchMoved(id: 1, to: Vec2(angle: bearing, length: 50))
            XCTAssertEqual(Angles.separation(touch.consume().move.angle, bearing), 0, accuracy: 1e-9)
        }
    }

    func testReleasingTheStickStopsTheRun() {
        var touch = controller()
        touch.touchDown(id: 1, at: .zero)
        touch.touchMoved(id: 1, to: Vec2(x: 50, y: 0))
        touch.touchUp(id: 1)

        XCTAssertNil(touch.stickOrigin)
        XCTAssertEqual(touch.consume().move, .zero)
    }

    // MARK: Two thumbs

    /// The whole reason this logic is a separate, testable type.
    func testTheKickThumbDoesNotDisturbTheStick() {
        var touch = controller()
        touch.touchDown(id: 1, at: Vec2(x: 60, y: 60))
        touch.touchMoved(id: 1, to: Vec2(x: 110, y: 60))

        touch.touchDown(id: 2, at: shoot)
        touch.touchMoved(id: 2, to: Vec2(x: 720, y: 90))

        let input = touch.consume()
        XCTAssertEqual(input.move.length, 1, accuracy: 1e-9, "the stick is still fully pushed")
        XCTAssertEqual(input.move.angle, 0, accuracy: 1e-9, "and still pointing the same way")
        XCTAssertTrue(input.kickReleased, "and the shot still went")
    }

    func testLiftingTheKickThumbLeavesTheStickAlone() {
        var touch = controller()
        touch.touchDown(id: 1, at: .zero)
        touch.touchMoved(id: 1, to: Vec2(x: 0, y: 50))
        touch.touchDown(id: 2, at: shoot)
        touch.touchUp(id: 2)

        XCTAssertNotNil(touch.stickOrigin)
        XCTAssertEqual(touch.consume().move.length, 1, accuracy: 1e-9)
    }

    func testASecondThumbOnTheStickSideIsIgnored() {
        var touch = controller()
        touch.touchDown(id: 1, at: Vec2(x: 100, y: 100))
        touch.touchDown(id: 2, at: Vec2(x: 20, y: 300))
        XCTAssertEqual(touch.stickOrigin, Vec2(x: 100, y: 100), "the first thumb keeps the stick")
    }

    // MARK: Kicking

    /// Shooting fires on the way *down*, like tackle. It used to be hold-to-charge, which meant
    /// the button did nothing at the moment you pressed it — and a game where four people are
    /// barging you is no place to be holding a meter.
    func testShootingFiresOnTheTapNotOnTheRelease() {
        var touch = controller()
        touch.touchDown(id: 2, at: shoot)

        let input = touch.consume()
        XCTAssertTrue(input.kickReleased, "the shot goes the instant the thumb lands")
        XCTAssertEqual(input.kickPower, 1, "and at full power, since there is nothing to charge")
        XCTAssertFalse(input.kickHeld)
    }

    func testAShotIsDeliveredToExactlyOneStep() {
        var touch = controller()
        touch.touchDown(id: 2, at: shoot)
        XCTAssertTrue(touch.consume().kickReleased)
        XCTAssertFalse(touch.consume().kickReleased, "a shot lands on exactly one step")
        XCTAssertNil(touch.consume().kickPower)
    }

    func testLiftingTheShootThumbDoesNotFireASecondShot() {
        var touch = controller()
        touch.touchDown(id: 2, at: shoot)
        _ = touch.consume()
        touch.touchUp(id: 2)
        XCTAssertFalse(touch.consume().kickReleased)
    }

    func testHoldingTheButtonDownDoesNotRepeat() {
        var touch = controller()
        touch.touchDown(id: 2, at: shoot)
        XCTAssertTrue(touch.consume().kickReleased)
        for _ in 0..<60 {
            XCTAssertFalse(touch.consume().kickReleased, "a held thumb is one shot, not a stream")
        }
    }

    func testTheTackleButtonAsksForALunge() {
        var touch = controller()
        touch.touchDown(id: 2, at: tackle)

        let input = touch.consume()
        XCTAssertTrue(input.dashRequested)
        XCTAssertFalse(input.kickHeld, "tackling must not also charge a shot")
    }

    func testATackleIsDeliveredToExactlyOneStep() {
        var touch = controller()
        touch.touchDown(id: 2, at: tackle)
        XCTAssertTrue(touch.consume().dashRequested)
        XCTAssertFalse(touch.consume().dashRequested)
    }

    /// Tackle used to be a double-tap of the shoot button, which meant the second tap of every
    /// dive also fired a shot. Separate buttons make that impossible by construction.
    func testShootingAndTacklingAreIndependent() {
        var touch = controller()
        touch.touchDown(id: 2, at: shoot)
        touch.touchDown(id: 3, at: tackle)

        let both = touch.consume()
        XCTAssertTrue(both.kickReleased, "shot away")
        XCTAssertTrue(both.dashRequested, "and tackling")
    }

    /// A thumb that lands slightly off a button should still hit it, and a thumb that slides
    /// off one mid-press is still pressing it.
    func testButtonsAreForgiving() {
        var touch = controller()
        touch.touchDown(id: 2, at: shoot + Vec2(x: 50, y: 0))
        XCTAssertTrue(touch.consume().kickReleased, "just outside the drawn edge still counts")

        touch.touchMoved(id: 2, to: Vec2(x: 200, y: 300))
        XCTAssertNil(touch.stickOrigin, "and sliding off does not turn into a stick")
    }

    func testAThumbFarFromEitherButtonIsTheStick() {
        var touch = controller()
        touch.touchDown(id: 1, at: Vec2(x: 120, y: 120))
        XCTAssertEqual(touch.stickOrigin, Vec2(x: 120, y: 120))
        XCTAssertFalse(touch.consume().kickReleased)
    }

    /// Thumbs are aimed at the pitch, not at the buttons, so the assist is always requested.
    func testTheHumanAlwaysAsksForAimAssist() {
        var touch = controller()
        XCTAssertTrue(touch.consume().aimAssist)
    }

    func testCancellingClearsEverything() {
        var touch = controller()
        touch.touchDown(id: 1, at: .zero)
        touch.touchMoved(id: 1, to: Vec2(x: 50, y: 0))
        touch.touchDown(id: 2, at: shoot)

        touch.cancelAll()

        let input = touch.consume()
        XCTAssertEqual(input.move, .zero)
        XCTAssertFalse(input.kickHeld)
        XCTAssertFalse(input.kickReleased)
        XCTAssertFalse(input.dashRequested)
        XCTAssertNil(touch.stickOrigin)
    }

    // MARK: End to end

    /// A thumb-driven player must be able to score, using only the same input a bot gets.
    func testAHumanCanRunToTheBallAndScore() {
        let tuning = Tuning.default
        var engine = MatchFixture.engine(tuning: tuning)
        var brains = (1..<5).map { BotBrain(index: $0, difficulty: .easy, seed: 5) }
        var touch = controller()

        var scored = false
        var holding = false
        var stickDown = false

        for step in 0..<MatchFixture.steps(forSeconds: 120) {
            let me = engine.state.players[0]
            let target = engine.state.arena.mouthCentre(of: 2)
            let aim = (target - engine.state.ball.position).normalized
            let behind = engine.state.ball.position - aim * (tuning.playerRadius + tuning.ballRadius)
            let goal = me.body.position.distance(to: behind) > 0.4 ? behind - me.body.position : aim

            // Drive the stick as a thumb would: plant it, then drag in the direction wanted.
            if !stickDown {
                touch.touchDown(id: 1, at: .zero)
                stickDown = true
            }
            touch.touchMoved(id: 1, to: goal.normalized * 50)

            let canKick = KickResolver.canStrike(body: me.body, ball: engine.state.ball, tuning: tuning)
            let lined = Angles.separation(me.body.facing, aim.angle) < 0.2

            // One tap, the way a person would do it.
            if canKick, lined, !holding {
                touch.touchDown(id: 2, at: shoot)
                holding = true
            } else if holding {
                touch.touchUp(id: 2)
                holding = false
            }

            var inputs = (0..<5).map { index -> PlayerInput in
                index == 0 ? .idle : brains[index - 1].decide(state: engine.state, tuning: tuning)
            }
            inputs[0] = touch.consume()

            for event in engine.step(inputs: inputs) {
                if case .conceded(let goal, let scorer, _) = event, scorer == 0, goal != 0 {
                    scored = true
                }
            }
            if scored || engine.state.isOver { break }
        }
        XCTAssertTrue(scored, "a thumb-driven player never managed to score")
    }
}
