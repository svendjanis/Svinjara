import XCTest
@testable import Svinjara

final class TouchControllerTests: XCTestCase {

    private func controller() -> TouchController {
        var controller = TouchController()
        controller.layout = TouchController.Layout(stickRadius: 50, deadZone: 7, doubleTapWindow: 0.26)
        return controller
    }

    // MARK: The stick

    func testTheStickAppearsWhereTheThumbLands() {
        var touch = controller()
        touch.touchDown(id: 1, at: Vec2(x: 90, y: 120), onKickSide: false, now: 0)

        XCTAssertEqual(touch.stickOrigin, Vec2(x: 90, y: 120))
        XCTAssertEqual(touch.consume().move, .zero, "no movement until the thumb moves")
    }

    func testDraggingSteersInThatDirection() {
        var touch = controller()
        touch.touchDown(id: 1, at: Vec2(x: 100, y: 100), onKickSide: false, now: 0)
        touch.touchMoved(id: 1, to: Vec2(x: 150, y: 100))

        let move = touch.consume().move
        XCTAssertEqual(move.length, 1, accuracy: 1e-9, "a full push is full tilt")
        XCTAssertEqual(move.angle, 0, accuracy: 1e-9)
    }

    func testAHalfPushIsHalfSpeed() {
        var touch = controller()
        touch.touchDown(id: 1, at: Vec2(x: 100, y: 100), onKickSide: false, now: 0)
        touch.touchMoved(id: 1, to: Vec2(x: 125, y: 100))
        XCTAssertEqual(touch.consume().move.length, 0.5, accuracy: 1e-9)
    }

    func testPushingBeyondTheRadiusIsStillFullTilt() {
        var touch = controller()
        touch.touchDown(id: 1, at: Vec2(x: 100, y: 100), onKickSide: false, now: 0)
        touch.touchMoved(id: 1, to: Vec2(x: 400, y: 100))
        XCTAssertEqual(touch.consume().move.length, 1, accuracy: 1e-9)
    }

    func testTinyMovementsAreHoldingStillNotWalking() {
        var touch = controller()
        touch.touchDown(id: 1, at: Vec2(x: 100, y: 100), onKickSide: false, now: 0)
        touch.touchMoved(id: 1, to: Vec2(x: 104, y: 102))
        XCTAssertEqual(touch.consume().move, .zero)
    }

    func testEveryDirectionIsReachable() {
        for bearing in stride(from: -Double.pi, to: Double.pi, by: 0.3) {
            var touch = controller()
            touch.touchDown(id: 1, at: .zero, onKickSide: false, now: 0)
            touch.touchMoved(id: 1, to: Vec2(angle: bearing, length: 50))
            XCTAssertEqual(Angles.separation(touch.consume().move.angle, bearing), 0, accuracy: 1e-9)
        }
    }

    func testReleasingTheStickStopsTheRun() {
        var touch = controller()
        touch.touchDown(id: 1, at: .zero, onKickSide: false, now: 0)
        touch.touchMoved(id: 1, to: Vec2(x: 50, y: 0))
        touch.touchUp(id: 1, now: 0.4)

        XCTAssertNil(touch.stickOrigin)
        XCTAssertEqual(touch.consume().move, .zero)
    }

    // MARK: Two thumbs

    /// The whole reason this logic is a separate, testable type.
    func testTheKickThumbDoesNotDisturbTheStick() {
        var touch = controller()
        touch.touchDown(id: 1, at: Vec2(x: 60, y: 60), onKickSide: false, now: 0)
        touch.touchMoved(id: 1, to: Vec2(x: 110, y: 60))

        touch.touchDown(id: 2, at: Vec2(x: 700, y: 60), onKickSide: true, now: 0.1)
        touch.touchMoved(id: 2, to: Vec2(x: 720, y: 90))

        let input = touch.consume()
        XCTAssertEqual(input.move.length, 1, accuracy: 1e-9, "the stick is still fully pushed")
        XCTAssertEqual(input.move.angle, 0, accuracy: 1e-9, "and still pointing the same way")
        XCTAssertTrue(input.kickHeld)
    }

    func testLiftingTheKickThumbLeavesTheStickAlone() {
        var touch = controller()
        touch.touchDown(id: 1, at: .zero, onKickSide: false, now: 0)
        touch.touchMoved(id: 1, to: Vec2(x: 0, y: 50))
        touch.touchDown(id: 2, at: Vec2(x: 700, y: 60), onKickSide: true, now: 0.1)
        touch.touchUp(id: 2, now: 0.3)

        XCTAssertNotNil(touch.stickOrigin)
        XCTAssertEqual(touch.consume().move.length, 1, accuracy: 1e-9)
    }

    func testASecondThumbOnTheStickSideIsIgnored() {
        var touch = controller()
        touch.touchDown(id: 1, at: Vec2(x: 100, y: 100), onKickSide: false, now: 0)
        touch.touchDown(id: 2, at: Vec2(x: 20, y: 300), onKickSide: false, now: 0.05)
        XCTAssertEqual(touch.stickOrigin, Vec2(x: 100, y: 100), "the first thumb keeps the stick")
    }

    // MARK: Kicking

    func testHoldingAndReleasingProducesExactlyOneRelease() {
        var touch = controller()
        touch.touchDown(id: 2, at: Vec2(x: 700, y: 60), onKickSide: true, now: 0)
        XCTAssertTrue(touch.consume().kickHeld)
        XCTAssertTrue(touch.consume().kickHeld, "still held on later steps")

        touch.touchUp(id: 2, now: 0.5)
        XCTAssertTrue(touch.consume().kickReleased)
        XCTAssertFalse(touch.consume().kickReleased, "a release lands on exactly one step")
    }

    func testDoubleTappingLunges() {
        var touch = controller()
        touch.touchDown(id: 2, at: Vec2(x: 700, y: 60), onKickSide: true, now: 0)
        touch.touchUp(id: 2, now: 0.06)
        _ = touch.consume()

        touch.touchDown(id: 3, at: Vec2(x: 700, y: 60), onKickSide: true, now: 0.14)
        let input = touch.consume()
        XCTAssertTrue(input.dashRequested)
        XCTAssertFalse(input.kickHeld, "the lunge press must not also charge a shot")
    }

    /// Without this the second tap of every dive also fires a shot nobody asked for.
    func testTheLungePressDoesNotAlsoKick() {
        var touch = controller()
        touch.touchDown(id: 2, at: Vec2(x: 700, y: 60), onKickSide: true, now: 0)
        touch.touchUp(id: 2, now: 0.06)
        _ = touch.consume()

        touch.touchDown(id: 3, at: Vec2(x: 700, y: 60), onKickSide: true, now: 0.14)
        _ = touch.consume()
        touch.touchUp(id: 3, now: 0.22)
        XCTAssertFalse(touch.consume().kickReleased)
    }

    func testTwoSlowTapsAreTwoKicksNotALunge() {
        var touch = controller()
        touch.touchDown(id: 2, at: Vec2(x: 700, y: 60), onKickSide: true, now: 0)
        touch.touchUp(id: 2, now: 0.1)
        XCTAssertTrue(touch.consume().kickReleased)

        touch.touchDown(id: 3, at: Vec2(x: 700, y: 60), onKickSide: true, now: 0.9)
        let second = touch.consume()
        XCTAssertFalse(second.dashRequested)
        XCTAssertTrue(second.kickHeld)
    }

    func testALungeIsDeliveredToExactlyOneStep() {
        var touch = controller()
        touch.touchDown(id: 2, at: Vec2(x: 700, y: 60), onKickSide: true, now: 0)
        touch.touchUp(id: 2, now: 0.06)
        _ = touch.consume()
        touch.touchDown(id: 3, at: Vec2(x: 700, y: 60), onKickSide: true, now: 0.14)

        XCTAssertTrue(touch.consume().dashRequested)
        XCTAssertFalse(touch.consume().dashRequested)
    }

    func testCancellingClearsEverything() {
        var touch = controller()
        touch.touchDown(id: 1, at: .zero, onKickSide: false, now: 0)
        touch.touchMoved(id: 1, to: Vec2(x: 50, y: 0))
        touch.touchDown(id: 2, at: Vec2(x: 700, y: 60), onKickSide: true, now: 0.1)

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
                touch.touchDown(id: 1, at: .zero, onKickSide: false, now: Double(step) * tuning.fixedStep)
                stickDown = true
            }
            touch.touchMoved(id: 1, to: goal.normalized * 50)

            let canKick = KickResolver.canStrike(body: me.body, ball: engine.state.ball, tuning: tuning)
            let lined = Angles.separation(me.body.facing, aim.angle) < 0.2
            let now = Double(step) * tuning.fixedStep

            if canKick, lined, holding, me.chargeFraction(tuning: tuning) > 0.7 {
                touch.touchUp(id: 2, now: now)
                holding = false
            } else if !holding {
                touch.touchDown(id: 2, at: Vec2(x: 700, y: 60), onKickSide: true, now: now)
                holding = true
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
