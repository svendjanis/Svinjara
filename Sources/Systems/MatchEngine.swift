import Foundation

/// The whole game. The only thing permitted to mutate `MatchState`, and a pure function of
/// `(state, inputs)` — it reads no clock, draws no random numbers and knows nothing about
/// frames. See `docs/ARCHITECTURE.md` §4 for the step order, which is load-bearing.
struct MatchEngine {

    private(set) var state: MatchState
    let tuning: Tuning

    init(nations: [Nation], tuning: Tuning = .default, appearanceSeed: UInt64 = 0) {
        precondition(nations.count == tuning.goalCount,
                     "svinjara is played by exactly \(tuning.goalCount)")
        self.tuning = tuning

        let arena = ArenaGeometry(tuning: tuning)
        let players = nations.enumerated().map { index, nation in
            PlayerState(index: index,
                        nation: nation,
                        appearance: AppearanceFactory.make(seed: appearanceSeed &+ UInt64(index) &* 0x9E37_79B9),
                        body: MatchEngine.homeBody(goal: index, arena: arena, tuning: tuning))
        }
        self.state = MatchState(arena: arena, players: players)
    }

    /// Advances the match by exactly one fixed slice.
    ///
    /// There is deliberately no `dt` parameter. The renderer accumulates real frame time and
    /// calls this a whole number of times; letting a caller pass a frame duration in is
    /// precisely how a simulation stops being reproducible.
    @discardableResult
    mutating func step(inputs: [PlayerInput]) -> [MatchEvent] {
        precondition(inputs.count == state.players.count)
        let dt = tuning.fixedStep
        var events: [MatchEvent] = []

        // 1. Phase clock. Nothing else happens while the goal is being celebrated.
        switch state.phase {
        case .finished:
            return events
        case .celebrating(let remaining):
            let left = remaining - dt
            if left <= 0 {
                resetForKickoff()
                state.phase = .playing
                events.append(.resumed)
            } else {
                state.phase = .celebrating(remaining: left)
            }
            return events
        case .playing:
            break
        }

        state.elapsed += dt

        // 2. Intent. Releases are collected now, while the charge is still known, but applied
        //    at the end so the ball's own motion cannot overwrite the result of a kick.
        var releases: [(player: Int, charge: Double, assisted: Bool)] = []
        for index in state.players.indices where state.players[index].isAlive {
            applyIntent(index: index, input: inputs[index], dt: dt,
                        releases: &releases, events: &events)
        }

        // 3. Integrate players.
        for index in state.players.indices where state.players[index].isAlive {
            let player = state.players[index]
            PlayerPhysics.integrate(&state.players[index].body,
                                    move: inputs[index].move,
                                    dash: player.isDashing ? player.dashDirection : nil,
                                    control: player.isStaggered ? tuning.staggerControl : 1,
                                    dt: dt,
                                    tuning: tuning)
        }

        // 4. Resolve players against each other and the posts, then contain them.
        //    Containment goes last because it is the only hard constraint: a shove or a post
        //    push-out can otherwise deposit someone a few centimetres outside the line, and
        //    "nobody leaves the circle" has to win over "nobody overlaps a post".
        resolvePlayerContacts(events: &events)
        resolvePlayersAgainstPosts()
        containPlayers()

        // 5-7. Advance the ball: posts, then the line, then the goal test.
        let outcome = GoalDetector.advance(ball: &state.ball, arena: state.arena,
                                           dt: dt, tuning: tuning)
        switch outcome {
        case .scored(let goal):
            // Rules. A goal ends the step — there is nothing left to simulate.
            concede(goal: goal, events: &events)
            return events
        case .bounced:
            events.append(.ballHitWall(speed: state.ball.velocity.length))
        case .hitPost:
            events.append(.ballHitPost(speed: state.ball.velocity.length))
        case .none:
            break
        }

        // 8. Stagnation. See `docs/RULES.md` §10 — this is what stops a ball pinned against
        //    the line from holding the whole match up.
        if enforceProgress(dt: dt) { events.append(.ballReset) }

        // 9. Bodies against the ball, then kicks.
        //
        // Order matters, and index order is not neutral: each contact repositions the ball and
        // overwrites the last one's velocity, so whoever is processed last gets the final say.
        // Running 0…4 quietly handed that to player 4 every single step, and over a few hundred
        // matches it showed up as slot 4 winning far more than its share and slot 0 — the
        // human's slot — winning least.
        //
        // Furthest first, so the player actually nearest the ball has the last word. That is
        // both index-neutral and the physically sensible reading of a contested ball.
        let byDistance = state.players.indices
            .filter { state.players[$0].isAlive }
            .sorted { state.players[$0].body.position.distanceSquared(to: state.ball.position)
                    > state.players[$1].body.position.distanceSquared(to: state.ball.position) }

        for index in byDistance {
            let touched = KickResolver.resolveBodyContact(player: index,
                                                          body: state.players[index].body,
                                                          ball: &state.ball,
                                                          tuning: tuning)
            // A lunge that gets to the ball knocks it loose — which is what a tackle is here.
            if touched, state.players[index].isDashing {
                events.append(.tackled(player: index))
            }
        }

        // Two players releasing on the same 1/120 s slice is rare, but when it happens the
        // nearest one is the one who actually got a foot to it — not the one with the higher
        // index.
        if let release = releases.min(by: {
            state.players[$0.player].body.position.distanceSquared(to: state.ball.position)
                < state.players[$1.player].body.position.distanceSquared(to: state.ball.position)
        }) {
            if let event = KickResolver.strike(player: release.player,
                                               body: state.players[release.player].body,
                                               charge: release.charge,
                                               assisted: release.assisted,
                                               ball: &state.ball,
                                               arena: state.arena,
                                               tuning: tuning) {
                events.append(event)
            }
        }

        return events
    }

    // MARK: Intent

    private mutating func applyIntent(index: Int,
                                      input: PlayerInput,
                                      dt: Double,
                                      releases: inout [(player: Int, charge: Double, assisted: Bool)],
                                      events: inout [MatchEvent]) {
        var player = state.players[index]

        player.staggerRemaining = max(0, player.staggerRemaining - dt)

        if player.isDashing {
            player.dashRemaining -= dt
            if player.dashRemaining <= 0 {
                player.dashRemaining = 0
                player.dashCooldown = tuning.dashCooldown
            }
        } else {
            player.dashCooldown = max(0, player.dashCooldown - dt)
        }

        // A staggered player can neither kick nor lunge, and loses whatever they had charged.
        if player.isStaggered {
            player.charge = 0
            player.isCharging = false
            state.players[index] = player
            return
        }

        if input.dashRequested, !player.isDashing, player.dashCooldown <= 0 {
            let heading = input.move.lengthSquared > 1e-9 ? input.move.normalized
                                                          : Vec2(angle: player.body.facing)
            player.dashRemaining = tuning.dashDuration
            player.dashDirection = heading
            events.append(.dashed(player: index))
        }

        if input.kickHeld {
            player.charge = min(tuning.kickChargeTime, player.charge + dt)
            player.isCharging = true
        }
        if input.kickReleased {
            releases.append((player: index, charge: player.charge, assisted: input.aimAssist))
            player.charge = 0
            player.isCharging = false
        }

        state.players[index] = player
    }

    // MARK: Contacts

    private mutating func containPlayers() {
        for index in state.players.indices where state.players[index].isAlive {
            var body = state.players[index].body
            CollisionSolver.slideInsideBoundary(position: &body.position,
                                                velocity: &body.velocity,
                                                boundaryRadius: state.arena.radius,
                                                bodyRadius: tuning.playerRadius)
            state.players[index].body = body
        }
    }

    private mutating func resolvePlayerContacts(events: inout [MatchEvent]) {
        let indices = state.players.indices.filter { state.players[$0].isAlive }
        for a in 0..<indices.count {
            for b in (a + 1)..<indices.count {
                let i = indices[a], j = indices[b]

                // Swift will not allow two inout paths into the same array at once, so the
                // two bodies are lifted out, resolved, and put back.
                var first = state.players[i].body
                var second = state.players[j].body
                let normal = (second.position - first.position).normalized

                let touched = CollisionSolver.resolveEqualMass(
                    positionA: &first.position,
                    velocityA: &first.velocity,
                    positionB: &second.position,
                    velocityB: &second.velocity,
                    radiusA: tuning.playerRadius,
                    radiusB: tuning.playerRadius,
                    restitution: tuning.playerRestitution)
                state.players[i].body = first
                state.players[j].body = second
                guard touched else { continue }

                // A lunge into someone else is a shoulder charge. Two players dashing into
                // each other simply bounce — neither gets to bully the other.
                let iDashing = state.players[i].isDashing
                let jDashing = state.players[j].isDashing
                if iDashing, !jDashing {
                    shove(victim: j, by: i, normal: normal, events: &events)
                } else if jDashing, !iDashing {
                    shove(victim: i, by: j, normal: -normal, events: &events)
                }
            }
        }
    }

    private mutating func shove(victim: Int, by aggressor: Int, normal: Vec2, events: inout [MatchEvent]) {
        state.players[victim].body.velocity += normal * tuning.dashShoveImpulse
        state.players[victim].staggerRemaining = tuning.staggerDuration
        state.players[victim].charge = 0
        state.players[victim].isCharging = false

        // A charge that connects is spent. Without this the aggressor stays in the dash state
        // while still touching the victim, re-shoving and re-staggering them every step for
        // the rest of the lunge — one barge would pin someone for far longer than the stagger
        // is meant to last.
        state.players[aggressor].dashRemaining = 0
        state.players[aggressor].dashCooldown = tuning.dashCooldown

        events.append(.shoved(by: aggressor, victim: victim))
    }

    private mutating func resolvePlayersAgainstPosts() {
        let posts = state.arena.activePosts
        for index in state.players.indices where state.players[index].isAlive {
            var body = state.players[index].body
            for post in posts {
                CollisionSolver.slideAroundStatic(position: &body.position,
                                                  velocity: &body.velocity,
                                                  bodyRadius: tuning.playerRadius,
                                                  centre: post,
                                                  staticRadius: state.arena.postRadius)
            }
            state.players[index].body = body
        }
    }

    // MARK: Rules

    /// Returns the ball to the centre if it has gone nowhere for too long.
    ///
    /// A ball resting against the paint cannot be struck along the wall at all — the widest
    /// kick available is 53° from the outward radial, because standing further round than that
    /// would put you outside the pitch. Two players leaning on such a ball can hold it there
    /// indefinitely, and in measured bot-only play roughly one match in six never reached a
    /// winner because of it. A human can do exactly the same thing, deliberately or not.
    ///
    /// So progress is a rule rather than something the AI is asked to be clever enough to
    /// avoid. It fires on the ball having travelled nowhere, not on nobody touching it, which
    /// is the case that actually occurs: the ball in a stalemate is touched constantly.
    private mutating func enforceProgress(dt: Double) -> Bool {
        if state.ball.position.distance(to: state.stagnationAnchor) > tuning.stagnationRadius {
            state.stagnationAnchor = state.ball.position
            state.stagnationTimer = 0
            return false
        }

        state.stagnationTimer += dt
        guard state.stagnationTimer >= tuning.stagnationTimeout else { return false }

        // Only the ball moves. Play is not stopped and nobody is repositioned — this is a
        // nudge to get the game going again, not a restart.
        state.ball = BallState()
        state.stagnationAnchor = .zero
        state.stagnationTimer = 0
        return true
    }

    private mutating func concede(goal: Int, events: inout [MatchEvent]) {
        let scorer = state.ball.lastTouchedBy
        state.players[goal].conceded += 1
        events.append(.conceded(goal: goal, scorer: scorer, ownGoal: scorer == goal))

        if state.players[goal].conceded >= tuning.concedesToElimination {
            state.players[goal].isAlive = false
            state.arena.seal(goal)
            state.eliminationOrder.append(goal)
            events.append(.eliminated(player: goal,
                                      place: state.players.count - state.eliminationOrder.count + 1))
        }

        // The concede that knocks out the fourth player ends the match in the same step —
        // there is no celebration to sit through when there is nobody left to play.
        if state.aliveCount <= 1 {
            let winner = state.players.first(where: \.isAlive)?.index ?? goal
            state.phase = .finished(winner: winner)
            events.append(.finished(winner: winner))
            return
        }

        state.phase = .celebrating(remaining: tuning.celebrationDuration)
    }

    /// Puts everything back exactly where a kickoff starts, whatever happened before it.
    private mutating func resetForKickoff() {
        state.ball = BallState()
        state.stagnationAnchor = .zero
        state.stagnationTimer = 0
        for index in state.players.indices {
            state.players[index].charge = 0
            state.players[index].isCharging = false
            state.players[index].dashRemaining = 0
            state.players[index].dashCooldown = 0
            state.players[index].dashDirection = .zero
            state.players[index].staggerRemaining = 0
            guard state.players[index].isAlive else { continue }
            state.players[index].body = MatchEngine.homeBody(goal: index,
                                                             arena: state.arena,
                                                             tuning: tuning)
        }
    }

    private static func homeBody(goal: Int, arena: ArenaGeometry, tuning: Tuning) -> PlayerBody {
        let home = arena.homeSpot(of: goal, fraction: tuning.homeSpotFraction)
        return PlayerBody(position: home,
                          velocity: .zero,
                          facing: Angles.normalize(home.angle + .pi))
    }
}
