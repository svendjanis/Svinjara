# Physics and Tuning

## 1. Why not SKPhysicsBody

The world is five player discs and one ball disc inside one circle, plus ten static post discs.
That is a closed problem with an exact solution. `SKPhysicsWorld` would hand back a black box
that cannot be stepped headlessly, cannot be seeded, and resolves contacts on its own schedule —
which makes "did that shot go through the mouth or hit the post?" unanswerable in a test.

Everything here is a pure function of its inputs, so the entire game is testable without a
scene and a 4-minute match simulates in a few milliseconds. That is what makes it possible to
balance the bots over hundreds of matches instead of by feel.

## 2. Units

SI throughout: metres, seconds, m/s, m/s². The pitch is 9.5 m in radius against a real centre
circle's 9.15 m, so the scale is honest and the numbers can be reasoned about physically. Conversion to
points happens once, in the renderer, via `Theme.pointsPerMetre` derived from the view size.

## 3. Integration

Semi-implicit Euler at a fixed `dt = 1/120 s`:

```
v += a · dt
x += v · dt
```

Velocity is updated first. With a fixed step and no stiff forces this is stable and, unlike
plain Euler, does not pump energy into a bouncing ball. There are no springs and no constraint
solver, so nothing needs sub-stepping.

Damping is applied as an exponential decay per step, `v *= exp(-k·dt)`, rather than subtracting
a constant. A constant subtraction is frame-rate dependent and makes a slow ball stop abruptly;
exponential decay is the physically right model for rolling resistance and is step-size
independent, which determinism requires.

## 4. Collisions

**Disc vs circular boundary (ball).** The line is a container, so contact is `|p| + r > R`.
Push the ball back along its own radius vector and reflect velocity about that radius:
`v' = (v − 2(v·n̂)n̂) · restitution` where `n̂ = −p̂`.

**Disc vs circular boundary (players).** Players do not bounce off the line, they slide along
it: clamp `|p|` to `R − r`, zero the radial velocity component, keep the tangential one. Bouncing
players off the wall feels broken when you are simply trying to run along your own goal line.

**Disc vs disc (players, posts).** Standard equal-mass impulse along the contact normal, with
positional correction split by mass so overlapping bodies separate without jitter. Posts are
infinite mass — they never move, so the whole impulse goes into the moving body.

**Sweeping.** At 120 Hz nothing here can tunnel: the fastest legal shot moves 14 cm per step,
well under the 46 cm capture diameter of a post, so a contact can never be skipped over
entirely. What an endpoint-only test *does* miss is a **graze** — a path that clips the edge of
a post and is back out again before the step ends, which happens whenever the path passes
between about 22 and 23 cm from a post centre. Those are exactly the deflections a player
notices, so post contacts are swept against the segment the ball travelled rather than tested
at its endpoint.

## 5. The goal crossing, exactly

A goal is decided by the *bearing* at which the ball crossed the line, and that bearing is
taken at the crossing point rather than wherever the step happened to end.

It is worth being precise about how much this buys, because the obvious justification is wrong.
Over one step near the line the bearing swings by at most `0.14 / 11 = 0.013 rad` (0.74°),
against a mouth half-width of 6.26°. But a post's contact radius casts an angular shadow of
`0.23 / 11 = 0.021 rad` (1.20°) either side of each mouth edge — **wider than the swing**. So
any crossing close enough to a mouth edge for the endpoint and the crossing point to disagree
has already been intercepted by the post, and the goal verdict itself is never actually in
doubt. That is a pleasant property of the geometry rather than an accident, and it is why there
are no ambiguous goals.

What the crossing point genuinely buys is the **rebound**: the surface normal is the radius at
the point of contact, and taking it from the penetrated endpoint instead would tilt every
bounce by up to 0.74° and reposition the ball at a bearing it never actually reached. The
closed form is four lines and exact, so there is no reason to carry an approximation.

With the ball at `p₀` moving to `p₁ = p₀ + v·dt`, find `t ∈ [0,1]` where
`|p₀ + t·(p₁ − p₀)| = R`:

```
a = |Δ|²,  b = 2(p₀·Δ),  c = |p₀|² − R²
t = (−b + √(b² − 4ac)) / 2a
```

Take the crossing point `p₀ + t·Δ`, compute its bearing, and test *that* angle against the
mouth spans.

Note the two radii are different and both are needed. The ball **rebounds** when its edge
reaches the paint, at `R − ballRadius`; it has **scored** only once its centre is past `R`,
which on a wall bearing can never happen. Collapsing them into one radius would either let the
ball rebound off the open air inside a mouth, or let it roll a centimetre past the paint on a
wall and count.

## 6. The tuning table

All of these live in `Tuning.swift` as a single struct with defaults, so a balance test can
construct a variant without touching global state.

### Arena
| | |
|---|---|
| Pitch radius | 9.5 m |
| Goal mouth chord | 4.4 m |
| Post radius | 0.12 m |
| Goals | 5, at 72° spacing |

### Ball
| | |
|---|---|
| Radius | 0.11 m |
| Damping | 0.72 /s (concrete rolls far — grass would be ~1.4) |
| Wall restitution | 0.72 |
| Post restitution | 0.85 |
| Rest threshold | 0.15 m/s |
| Max speed | 19 m/s |

### Player
| | |
|---|---|
| Radius | 0.42 m |
| Acceleration | 21 m/s² |
| Top speed | 4.5 m/s |
| Friction | 8.0 /s |
| Turn rate | 12 rad/s |
| Restitution | 0.30 |

### Kick
| | |
|---|---|
| Charge time to full | 0.55 s |
| Speed at min charge (a bare tap) | 7.5 m/s |
| Speed at full charge | 15 m/s |
| Reach | radii + 0.50 m |
| Arc | ±75° of facing |
| Aim assist window | ±40° |
| Dribble grip | 0.72 of your closing speed |
| Dribble gather | push steered up to 0.55 rad toward your run |

### Tackle (the dash)
| | |
|---|---|
| Duration | 0.27 s |
| Speed | 7.7 m/s |
| Cooldown | 1.6 s |
| Shove impulse | 4.5 m/s |
| Stagger inflicted | 0.4 s |

### Match
| | |
|---|---|
| Concedes to elimination | 4 |
| Scoring redeems one (floored at 0) | yes |
| Celebration pause | 1.2 s |
| Home spot radius | 0.88 R |
| Restart line-up spread | ±0.06 R, ±half a mouth sideways |
| Goal kick spot | 0.78 R, in front of the conceder's own mouth |
| Stagnation timeout | 7 s |
| Stagnation radius | 2 m |

### Bot
| | |
|---|---|
| Pace (stick push, every tier) | 0.93 |
| Goal-kick stand-off | 1.3 s |
| Shot bar | easy 0.55 · normal 0.75 · hard 0.95 |
| Carry patience | easy 1.2 s · normal 1.8 s · hard 2.4 s, ×0.7–1.4 |
| Press range | 0.70 of the pitch width, second nearest only |

## 7. How these were chosen

Start from physical plausibility, then tune against the numbers that matter to the feel:

- **Top speed 4.5 m/s vs ball 15 m/s.** A struck ball crosses the 19 m pitch in ~1.5 s; a
  player crosses it in ~4.2 s. You cannot chase a shot down, only anticipate it. This ratio is
  the single biggest lever on how defensive the game feels.

  It used to be 5.6 against 17, and the whole game came down a fifth because at that pace there
  was no time to read where the ball would end up — a scramble rather than a game. Only the
  ceiling moved: acceleration came down in the same proportion, so the time from standstill to
  top speed is unchanged at ~0.21 s and the stick answers exactly as fast as it did.
- **Damping 0.72/s.** What this number has to clear is `kickMaxSpeed / ballDamping` — how far a
  struck ball can ever travel — against the 19 m pitch. At 0.80 it was 17.5 m, and two of the
  four goals you are attacking were out of range from your own end.
- **Mouth 4.4 m vs player 0.84 m across.** One body covers under a quarter of their own mouth,
  so standing still never makes a goal safe. Guarding requires reading the shot.
- **Dash 7.7 m/s for 0.27 s** covers ~2.1 m — just enough to reach a shot aimed at the far post
  of your own mouth, and not enough to cross the pitch with it. It slowed with everything else
  and was lengthened to match, so a lunge still buys the same ground.
- **Dribble gather 0.55 rad.** Two circles meeting send the ball off along the line between
  their centres, so a touch taken a few centimetres off-line puts the ball further off-line
  still and the next touch compounds it. Contact alone *diverges*, which is the honest reason
  carrying the ball felt like herding however the grip was set: grip decides how fast the ball
  leaves, not which way. A foot points where its owner is running, so the push is steered
  toward the direction of travel — capped, so sprinting past a ball still only clips it.
- **4 concedes.** Six, until the bots learned to defend — see §7.4.
- **Home spot 0.88 R**, so a player restarts 1.1 m from their own line rather than 4.3 m in
  front of it. At 0.55 R every goal was undefended at the instant of a kickoff and 19% of all
  goals arrived inside two seconds of one. Depth was swept: below about 0.85 R the restart is
  effectively a scripted goal — the gap from restart to goal collapses onto a single value
  around 2.2 s — and above it a real scramble opens up (p10 2.4 s, median 5.4 s).
- **The goal kick at 0.78 R**, taken by whoever conceded, with everybody else on their own
  line. See §7.3: moving the home spot deep was only half the fix, and the half that could be
  measured with the test that existed at the time.

### What the sweeps actually said

**Mouth width dominates everything else.** Radius and mouth were swept together, 100 bot-only
matches per cell: at 2.4 m the median match ran past 7 minutes and a fifth never finished at
all. Radius mattered far less, and 9.5 m was chosen for the best win fairness rather than for
pace.

**Redemption lengthens matches, and the mouth is what pays for it.** Letting a scorer wipe one
mark off their own tally slows the rate at which tallies grow, so the same pitch that gave a
3.5-minute median gave a 5.5-minute one once the rule was in. Widening the mouth from 3.6 m to
4.4 m pulled it back, at 200 matches per cell:

| mouth | median | p90 | goals/min | worst slot's win share |
|---|---|---|---|---|
| 3.6 m | 331 s | 430 s | 8.2 | 1.29× fair |
| **4.4 m** | **285 s** | **384 s** | **10.4** | **1.18× fair** |
| 4.8 m | 259 s | 337 s | 11.4 | 1.10× fair |

4.8 m is marginally better on every number and was not taken: at 4.4 m each goal is 27° of the
circle and the five together are 37% of it, and the brief says *little* goals.

**Redemption also fixed the difficulty scale**, which is the stronger argument for it. Mean
finishing place over 150 matches with the tiers rotated:

| | without redemption | with it |
|---|---|---|
| Hard | 2.61 | **2.55** |
| Normal | — | 2.97 |
| Easy | 3.36 | **3.47** |

Hard bots attack far more than easy ones, so the gap widening is the same thing as attacking
starting to pay.

`BalanceSimTests` re-runs a smaller version of this. Any change to this table should be checked
against it, and a degenerate win distribution — one slot winning far more than a fifth of the
time — is a bug in the AI or the geometry, not an acceptable outcome.

### The restart was a script, and one threshold could not see it

Moving the home spots out to 0.88 R was checked by asking whether a goal arrived within 1.5 s
of a restart, and the answer was a clean 0.0%. The test passed for months. Plotted as a
histogram instead, over 24 bot matches and 1,177 goals:

| gap from restart to goal | share of *all* goals in the game |
|---|---|
| 2.00–2.25 s | 4.4% |
| **2.25–2.50 s** | **25.9%** |
| 2.50–2.75 s | 6.6% |
| 2.75–3.00 s | 2.0% |

A quarter of every goal in the game landed in one quarter-second bucket. Nothing a person does
is that sharp: it was the same race, won by the same run, ending the same way, every single
time. Five players the same distance from a ball on the centre spot, all starting from a
standstill, and nothing downstream of that is random. The 1.5 s threshold sat just under it and
reported nothing wrong.

Four separate things were needed, and the sizes are worth recording because they are not what
they look like:

1. **A goal kick instead of a centre-spot kickoff.** Whoever conceded restarts, with the ball
   in front of their own mouth and everybody else on their line. There is no race, because the
   ball is already at somebody's feet, and no quick goal, because the nearest rival mouth is
   10 m away with all five players at home. This is the structural half of the fix.
2. **Pressing.** Only the single nearest player ever chased the ball; everyone else stood on
   their line. A ball at somebody's feet therefore crossed the whole pitch unopposed, and the
   only thing between it and a goal was the owner of whichever mouth it finally arrived at.
   The next nearest now closes them down — exactly one, because sending everybody is the
   failure this game started with. Worth 27.6% → 16.9% of goals arriving inside 3 s.
3. **A shot bar.** A bot took the best shot available even when the best available was
   dreadful, which from the centre spot they all are.
4. **Clearing what the bot remembers at the whistle.** The perception buffer holds the ball as
   it was a fraction of a second ago; during a celebration what it holds is the ball crossing a
   line. Every bot spent the first moments of a restart believing the ball was still in the
   net — long enough to commit to a shot from a position the ball was nowhere near, and
   `commitShot` then held that plan for 0.6 s more. This single bug was 8.6% of every goal in
   the game arriving within 2 s of a restart, and 46% of those were own goals: a ball hammered
   at a phantom, deflected in off whoever happened to be standing in the way. Clearing the
   buffer took it to 2.0%.

A fifth thing was needed once the other four were in, and it is the one a histogram cannot
see: whether the restart *reads* as yours. It is not enough for the engine to put the ball at
the conceder's feet — measured, that bought them a median of 1.75 s before a rival could kick
it, and only 35% of restarts still had it after two seconds. A bot takes its first touch 0.01 s
after the whistle and never notices. A person has just watched a goal go in, heard a whistle
and seen the pitch snap to new positions, and does not have their thumb back on the stick. So
the bots now stand off for 1.3 s, and the HUD says whose ball it is: median uncontested
possession 2.22 s, and 94% of restarts still uncontested after two seconds.

Where it ended up, at 80 matches:

| | before | after |
|---|---|---|
| tallest 0.25 s bucket | 25.9% | 6.6% |
| goals within 3 s of a restart | ~39% | 13.9% |
| goals more than 6 s after one | 37.8% | 52.4% |
| median gap | 4.65 s | 6.32 s |

`testNoSingleMomentAfterARestartOwnsTheGoals` now asserts the shape rather than a point on it.
A quarter-second bucket is narrower than the spread of anything a person does, so a tall one is
a script; a flat-ish distribution puts 3–4% in each.

### Six concedes became four

Elimination needs somebody to *fall behind*. Redemption means a goal only grows the table when
its scorer is already on zero, which was fine against bots that conceded in lumps — a restart
used to hand somebody three in a minute. Once the goal kick and pressing spread the goals
evenly, the table stopped growing. Measured over 80 easy matches: 4.4 goals a minute scored,
total tally climbing by 1.3 a minute, so reaching six took thirteen minutes and one match in
ten never got there inside fifteen.

The threshold is the cheap half of that trade. Turning redemption off entirely puts six back in
the band at a 239 s median — it is that rule, not the pace, that costs the time — but
redemption is what stops camping on your own line being the winning move, so the number gave
way instead:

| concedes | easy | normal | hard | longest of 240 |
|---|---|---|---|---|
| 6 | 617 s, 1 in 10 unfinished | 520 s | 405 s | — |
| 5 | 446 s, 1 in 80 unfinished | 405 s | 328 s | 747 s |
| **4** | **340 s** | **295 s** | **222 s** | **495 s** |
