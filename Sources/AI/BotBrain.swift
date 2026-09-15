import Foundation

/// What a bot has decided to be doing at the moment.
enum BotMode: Equatable {
    /// Shoved, and can do nothing about it until it wears off.
    case stagger
    /// The ball threatens my own goal; get between it and the mouth.
    case defend
    /// I am nearest, or near enough; go and hit it at somebody.
    case attack
    /// Somebody else got there first and I am next nearest; go and take it off them.
    case press
    /// Somebody else has it covered; hold a useful position rather than crowding the ball.
    case recover
}

/// One bot. Its only output is a `PlayerInput`, the same struct a human's thumbs fill in — so
/// it cannot move faster, kick harder or see further than a person can. See
/// `docs/ARCHITECTURE.md` §5.
struct BotBrain {

    let index: Int
    let difficulty: BotDifficulty

    private var rng: SeededRandom
    /// Recent ball states, so the bot can be made to see the ball as it was a moment ago.
    private var seenRecently: [BallState] = []
    private var mode: BotMode = .recover
    private var shot: ShotEvaluator.Shot?
    private var aimJitter: Double = 0
    private var holdingKick = false
    /// How long we have been stood over the ball without getting a shot away.
    private var dithering: Double = 0
    /// How long I have been getting nowhere with the ball, how long I am prepared to keep
    /// getting nowhere before taking whatever shot is on, and where the carry last got to.
    private var possession: Double = 0
    private var patience: Double = 0
    private var carryAnchor: Vec2 = .zero
    /// How long the current shot has been committed to.
    private var shotAge: Double = 0
    /// How long the current mode has been held.
    private var modeAge: Double = 0
    /// How long since play resumed, for the goal-kick stand-off.
    private var sinceWhistle: Double = 0

    /// The shortest time any bot may hold a mode.
    ///
    /// Stops the attack/defend decision chattering when a distance wobbles on the boundary.
    private static let minimumDwell: Double = 0.30

    /// How far away a ball may be and still be worth closing down, as a fraction of the way
    /// across the pitch. Beyond it, the second nearest player is not pressing — they are just
    /// leaving their goal to chase something at the far side of the circle.
    private static let pressRange: Double = 0.70

    /// How long the bots leave the taker of a goal kick alone.
    ///
    /// The restart already gives them the ball — it is at their feet at the whistle and the
    /// nearest rival is eight metres away. Measured, that bought the taker a median of 1.75 s
    /// of uncontested possession, and only a third of restarts still had it after two. A bot
    /// takes its first touch 0.01 s after the whistle and that is plenty. A person who has
    /// just watched a goal go in, heard the whistle and had the pitch snap to new positions
    /// has not got their thumb back on the stick yet, so what a restart *felt* like was the
    /// ball being put near your goal and immediately taken off you.
    ///
    /// So the bots stand off, the way players do at a goal kick. This is honoured by the bots
    /// rather than enforced by the engine, which is the honest place for it: it is not a rule
    /// that anything prevents you breaking, it is opponents giving you room.
    private static let restartStandOff: Double = 1.3

    private(set) var currentMode: BotMode = .recover

    init(index: Int, difficulty: BotDifficulty, seed: UInt64) {
        self.index = index
        self.difficulty = difficulty
        self.rng = SeededRandom(seed: seed &+ UInt64(index) &* 0x2545_F491)
    }

    mutating func decide(state: MatchState, tuning: Tuning) -> PlayerInput {
        let me = state.players[index]
        guard me.isAlive, state.phase.isPlaying else {
            holdingKick = false
            forgetEverythingBeforeTheWhistle()
            return .idle
        }
        if me.isStaggered {
            holdingKick = false
            currentMode = .stagger
            return .idle
        }

        shotAge += tuning.fixedStep
        modeAge += tuning.fixedStep
        sinceWhistle += tuning.fixedStep

        // Reaction latency is modelled as *perception* lag, not as thinking frequency.
        //
        // It used to gate how often the bot reconsidered, and that turned out to be a
        // different — and inverted — knob entirely. Reconsidering more often catches more of
        // the brief windows in which you happen to be nearest the ball, so a fast bot attacked
        // 37% of the time against a slow bot's 21%. And in this game attacking is what loses
        // you matches: time spent up the other end is time your own mouth is unguarded, while
        // the goal you score counts against somebody else and helps every survivor equally.
        // Measured over 150 matches the fast tier finished 3.42nd on average and the slow tier
        // 2.63rd. Higher difficulty was making bots more generous, not better.
        //
        // Seeing the ball a fraction of a second late is the honest model: it degrades
        // defending and attacking alike, without touching how eager a bot is to commit.
        let seen = perceived(state: state, tuning: tuning)

        reconsider(state: seen, tuning: tuning)
        currentMode = mode

        keepPossession(me: me, live: state, tuning: tuning)

        let input: PlayerInput
        switch mode {
        case .stagger, .recover:
            input = recovering(me: me, state: seen, tuning: tuning)
        case .defend:
            input = defending(me: me, state: seen, live: state, tuning: tuning)
        case .press:
            input = pressing(me: me, state: seen, tuning: tuning)
        case .attack:
            input = attacking(me: me, state: seen, live: state, tuning: tuning)
        }
        // Every tier holds the stick a little short of the rim. See `BotDifficulty.pace`.
        return input.paced(by: difficulty.pace)
    }

    /// Whatever I was in the middle of, a restart is a new situation.
    ///
    /// Two separate things used to survive the whistle and both of them misfired.
    ///
    /// The perception buffer is the worse one: what it holds while a goal is being celebrated
    /// is the ball crossing a line, so every bot spent the first fraction of a second after
    /// the restart believing the ball was still in the net — long enough to commit to a shot
    /// from a position the ball was nowhere near, and `commitShot` then held that plan for
    /// six tenths of a second more. Measured, it alone accounted for 8.6% of every goal in
    /// the game arriving within two seconds of a restart, nearly half of them own goals off a
    /// defender who was in the way of a ball nobody had meant to hit there. Clearing it took
    /// that to 2.0%.
    ///
    /// The commitment is the milder one: a mode is held for `minimumDwell` before it may be
    /// reconsidered, and since the clock does not run during a celebration, a decision taken
    /// a tenth of a second before the goal was still binding a tenth of a second after it.
    private mutating func forgetEverythingBeforeTheWhistle() {
        seenRecently.removeAll(keepingCapacity: true)
        possession = 0
        dithering = 0
        shot = nil
        mode = .recover
        // Free to decide again on the very first step of the restart, rather than being held
        // to whatever was true while the ball was in somebody's net.
        modeAge = Self.minimumDwell
        sinceWhistle = 0
    }

    /// Tracks how long I have been getting nowhere with the ball at my feet.
    ///
    /// Asked of the real ball rather than the remembered one: perception lag is about seeing
    /// across the pitch, and the ball against your own foot is not something you see late.
    ///
    /// The clock measures *lack of progress*, not time in possession, and the difference is
    /// the whole point. A first version simply counted seconds on the ball, and a bot taking
    /// a goal kick therefore hoofed it the instant the count expired — from ten metres inside
    /// its own half, at a mouth it had no business shooting at. Measured, that alone put 8.5%
    /// of every goal in the game within two seconds of a restart. Running up the pitch with
    /// the ball is not dithering on it, so getting somewhere restarts the clock; only a
    /// carrier who has actually stopped making ground runs out of patience.
    ///
    /// Progress is the same distance the rules already call progress, and for the same
    /// reason. A bot that dribbles in circles resets its own clock for ever, which is exactly
    /// the case `MatchEngine.enforceProgress` exists to end.
    ///
    /// The patience itself is jittered because a fixed one only moves the problem: bots that
    /// all hold the ball for exactly 1.8 s produce a restart that ends at exactly 1.8 s,
    /// which is the same scripted goal with a different timestamp on it.
    private mutating func keepPossession(me: PlayerState, live: MatchState, tuning: Tuning) {
        // A little wider than kicking range, so a touch that runs the ball a step ahead of you
        // does not read as having lost it.
        let mine = me.body.position.distance(to: live.ball.position) <= tuning.kickReach * 1.5
        guard mine else {
            possession = 0
            return
        }

        let gotSomewhere = live.ball.position.distance(to: carryAnchor) > tuning.stagnationRadius
        if possession == 0 || gotSomewhere {
            patience = difficulty.carryPatience * rng.double(in: 0.7...1.4)
            carryAnchor = live.ball.position
            possession = 0
        }
        possession += tuning.fixedStep
    }

    /// The match as this bot currently sees it: everything present, but the ball where it was
    /// `reactionLatency` ago.
    private mutating func perceived(state: MatchState, tuning: Tuning) -> MatchState {
        seenRecently.append(state.ball)
        let depth = max(1, Int((difficulty.reactionLatency / tuning.fixedStep).rounded()) + 1)
        if seenRecently.count > depth { seenRecently.removeFirst(seenRecently.count - depth) }

        var lagged = state
        lagged.ball = seenRecently[0]
        return lagged
    }

    // MARK: Deciding

    /// Order matters here, and getting it wrong produces a stalemate.
    ///
    /// The obvious ordering — check the threat to your own goal first, then decide whether to
    /// go for the ball — deadlocks the whole match: the player nearest a loose ball is almost
    /// always the owner of the goal nearest that ball, so the threat check captures exactly
    /// the player who would otherwise have gone and got it. Everyone else is further away and
    /// stands off. The ball sits still and nobody moves.
    ///
    /// So contesting the ball comes first, and only a genuine emergency — the ball actually
    /// arriving, not merely sitting nearby — outranks it. When the ball *is* near your own
    /// goal, going to get it and hitting it at somebody else is what defending looks like.
    private mutating func reconsider(state: MatchState, tuning: Tuning) {
        // Somebody else's goal kick: give them a moment. Holding your line is the whole of it
        // — the ball is at their feet and nine metres from anything of mine, so there is
        // nothing to defend against yet either. See `restartStandOff`.
        if let taker = state.restartTaker,
           taker != index,
           sinceWhistle < Self.restartStandOff {
            adopt(.recover)
            return
        }

        let threat = ThreatModel.threat(to: index, state: state, tuning: tuning)

        // A genuine emergency — the ball actually arriving, not merely sitting nearby —
        // interrupts any commitment. The pair of thresholds is hysteresis: one to enter, a
        // lower one to stay, so the decision cannot chatter on the boundary.
        if threat > (mode == .defend ? 0.65 : 0.80) {
            adopt(.defend)
            return
        }

        if mode == .attack { commitShot(state: state, tuning: tuning) }

        guard modeAge >= Self.minimumDwell else { return }

        let me = state.players[index]
        let myDistance = me.body.position.distance(to: state.ball.position)
        let rivals = state.players
            .filter { $0.isAlive && $0.index != index }
            .map { $0.body.position.distance(to: state.ball.position) }
            .sorted()
        let closestRival = rivals.first ?? .infinity

        // In the race for it. The margin is small on purpose: at 1.5 m two bots would both
        // commit to the same ball, end up inside kicking range of each other, and each block
        // the other's shot — 419 kicks and no goal in 80 seconds of measured play. Contesting
        // is for whoever is actually nearest; the wider margin while already attacking is
        // hysteresis, so the decision does not flap when two are near enough to swap places.
        if myDistance <= closestRival + (mode == .attack ? 0.45 : 0.15) {
            adopt(.attack)
            commitShot(state: state, tuning: tuning)
            return
        }

        // Somebody else will get there first. If it is pointed at my goal, go home; otherwise,
        // if I am the next nearest, go and close them down.
        //
        // Pressing was missing entirely, and its absence is why a carried ball used to cross
        // the whole pitch unopposed: the only player who ever chased it was the one already
        // nearest, and the other four stood on their own line waiting to be shot at. That is a
        // queue, not a five-way scrap.
        //
        // Exactly one presses, and only within range. Sending everybody leaves five goals
        // empty, which is the failure this game started with — an earlier `<=` here made every
        // one of four equidistant players the second nearest and sent all of them at once. And
        // a press from your own line at a ball on the far side of the circle is not a press,
        // it is leaving.
        let secondNearest = rivals.count > 1 && myDistance < rivals[1]
        if threat > (mode == .defend ? 0.30 : 0.45) {
            adopt(.defend)
        } else if secondNearest && myDistance <= state.arena.radius * 2 * Self.pressRange {
            adopt(.press)
        } else {
            adopt(.recover)
        }
    }

    private mutating func adopt(_ next: BotMode) {
        guard next != mode else { return }
        mode = next
        modeAge = 0
        dithering = 0
        if next != .attack { shot = nil }
    }

    /// Picks a goal to attack, and then *sticks with it*.
    ///
    /// Re-picking on every think tick is what made the hard tier worse than the easy one.
    /// A hard bot reconsiders 22 times a second, and re-rolling the target and the aim error
    /// that often means the point it is walking behind the ball to reach keeps jumping — so
    /// it never settles, never shoots, and spends the match shuffling. Easy bots, thinking
    /// only 6 times a second, thrashed less and won more. Measured over 240 matches the easy
    /// tier took 54% of the wins against a fair share of 40%.
    ///
    /// Commitment is held until the shot is taken, the target is knocked out, or the ball has
    /// moved far enough that the plan is stale.
    private mutating func commitShot(state: MatchState, tuning: Tuning) {
        if let current = shot,
           state.players[current.goal].isAlive,
           shotAge < 0.6 {
            return
        }
        shot = ShotEvaluator.best(for: index, state: state, tuning: tuning, noise: &rng)
        aimJitter = rng.gaussian(sigma: difficulty.aimSigma)
        shotAge = 0
    }

    // MARK: Acting

    private mutating func attacking(me: PlayerState, state: MatchState, live: MatchState,
                                    tuning: Tuning) -> PlayerInput {
        guard let shot = shot ?? ShotEvaluator.best(for: index, state: state, tuning: tuning, noise: &rng) else {
            return recovering(me: me, state: state, tuning: tuning)
        }
        let wasHolding = holdingKick

        // Stand behind the ball relative to the target, so that facing the goal is also facing
        // the ball. `approach` settles for a worse angle when the ideal spot is off the pitch,
        // which is what a ball parked against the line demands.
        let ideal = (shot.target - state.ball.position).normalized.rotated(by: aimJitter)
        let (aim, behind) = Steering.approach(ball: state.ball.position,
                                              aim: ideal,
                                              arena: state.arena,
                                              bodyRadius: tuning.playerRadius,
                                              ballRadius: tuning.ballRadius)

        // "Am I behind the ball?" is asked of the ball's bearing, not of where the figure
        // happens to be looking. Asking it of the facing makes the bot chase its own tail:
        // turning onto the aim swings the ball out of the kicking arc, which flips the answer
        // straight back again. The 0.9 rad threshold sits inside the 1.05 rad kicking arc, so
        // once the turn completes the ball is guaranteed to be strikeable.
        let toBall = state.ball.position - me.body.position
        let placed = toBall.length <= tuning.kickReach
            && Angles.separation(toBall.angle, aim.angle) < 0.9

        guard placed else {
            dithering = 0
            holdingKick = true
            return PlayerInput(move: Steering.seek(from: me.body.position, to: behind),
                               kickHeld: true)
        }

        dithering += tuning.fixedStep

        // Long shots want full power; a tap-in does not, and over-hitting from close range is
        // how a bot puts it through its own half of the pitch.
        let range = state.ball.position.distance(to: shot.target)
        let wanted = min(1, max(0.45, range / 13))

        // A shot has to be worth taking, and when it is not, the thing to do is carry the ball
        // until it is.
        //
        // Without this a bot hit the best shot available even when the best available was
        // dreadful, and a restart is precisely the moment when they all are: the ball is on the
        // centre spot, every mouth is nine metres away, and the first player to arrive booted
        // it at whichever one was least badly covered. Measured, 26% of every goal in the game
        // arrived 2.25–2.50 s after a restart — the same race, won by the same run, ending the
        // same way. Refusing the bad shot turns that into a carry out of the middle, which is
        // both a better goal when it lands and a savable one when it does not.
        //
        // `possession` is the escape valve: hold out for a look that never comes and you end
        // up leaning on the ball until the stagnation rule fires, which is worse than a bad
        // shot. See `BotDifficulty.shotBar` and `carryPatience`.
        let worthTaking = shot.score >= difficulty.shotBar || possession >= patience

        // Holding out for a clean look is right, but only up to a point. Against the line a
        // perfect angle may not exist at all, and two bots waiting for one will lean on the
        // ball until the match runs out — which is exactly what they did.
        let lined = Angles.separation(me.body.facing, aim.angle) < 0.22
        // Whether a kick is legal is asked of the *real* ball — you cannot boot a ghost.
        let ready = KickResolver.canStrike(body: me.body, ball: live.ball, tuning: tuning)
            && me.chargeFraction(tuning: tuning) >= wanted
            && (lined || dithering > 2.0)
            && worthTaking

        if ready { dithering = 0 }
        holdingKick = !ready
        return PlayerInput(move: aim, kickHeld: !ready, kickReleased: ready && wasHolding)
    }

    private mutating func defending(me: PlayerState, state: MatchState, live: MatchState,
                                    tuning: Tuning) -> PlayerInput {
        let spot = Steering.inside(ThreatModel.interceptSpot(for: index, state: state, standOff: 1.7),
                                   arena: state.arena,
                                   bodyRadius: tuning.playerRadius)
        let gap = me.body.position.distance(to: spot)

        // With the ball at your feet, defending is clearing it — hard, at whoever is furthest
        // from their own goal.
        if KickResolver.canStrike(body: me.body, ball: live.ball, tuning: tuning) {
            let clearance = shot ?? ShotEvaluator.best(for: index, state: state, tuning: tuning, noise: &rng)
            let away = clearance.map { ($0.target - state.ball.position).normalized }
                ?? (state.ball.position - state.arena.mouthCentre(of: index)).normalized
            let aim = away.rotated(by: aimJitter)

            let lined = Angles.separation(me.body.facing, aim.angle) < 0.3
            let ready = lined && me.chargeFraction(tuning: tuning) >= 0.7
            let input = PlayerInput(move: aim, kickHeld: !ready, kickReleased: ready && holdingKick)
            holdingKick = !ready
            return input
        }

        // Too far out to walk it: spend the lunge. Mistiming it leaves the mouth wide open,
        // which is exactly the trade the appetite setting governs.
        let desperate = gap > 1.1
            && ThreatModel.threat(to: index, state: state, tuning: tuning) > 0.7
            && me.dashCooldown <= 0
            && rng.bool(chance: difficulty.dashAppetite)

        holdingKick = true
        return PlayerInput(move: Steering.seek(from: me.body.position, to: spot),
                           kickHeld: true,
                           dashRequested: desperate)
    }

    /// Run at the ball and try to take it. Not at a spot behind the ball — that is what
    /// attacking does, and standing politely behind a ball somebody else has their foot on
    /// achieves nothing.
    private mutating func pressing(me: PlayerState, state: MatchState, tuning: Tuning) -> PlayerInput {
        let gap = me.body.position.distance(to: state.ball.position)

        // A lunge is worth spending at about its own length: any further and it lands short,
        // any closer and you were going to arrive anyway.
        let lunge = gap < tuning.dashDistance * 1.2
            && gap > tuning.playerRadius * 2
            && me.dashCooldown <= 0
            && rng.bool(chance: difficulty.dashAppetite)

        holdingKick = true
        return PlayerInput(move: Steering.seek(from: me.body.position,
                                               to: state.ball.position,
                                               slowingRadius: 0.3),
                           kickHeld: true,
                           dashRequested: lunge)
    }

    private mutating func recovering(me: PlayerState, state: MatchState, tuning: Tuning) -> PlayerInput {
        // Cover the angle between the ball and your own mouth, but stood well off it — close
        // enough to get back, far enough to join in if the ball comes loose.
        let spot = Steering.inside(ThreatModel.interceptSpot(for: index, state: state, standOff: 3.6),
                                   arena: state.arena,
                                   bodyRadius: tuning.playerRadius)
        holdingKick = true
        return PlayerInput(move: Steering.seek(from: me.body.position, to: spot), kickHeld: true)
    }
}
