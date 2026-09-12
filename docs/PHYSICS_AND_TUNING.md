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
| Goal mouth chord | 3.6 m |
| Post radius | 0.12 m |
| Goals | 5, at 72° spacing |

### Ball
| | |
|---|---|
| Radius | 0.11 m |
| Damping | 0.68 /s (concrete rolls far — grass would be ~1.4) |
| Wall restitution | 0.72 |
| Post restitution | 0.85 |
| Rest threshold | 0.15 m/s |
| Max speed | 22 m/s |

### Player
| | |
|---|---|
| Radius | 0.42 m |
| Acceleration | 26 m/s² |
| Top speed | 5.6 m/s |
| Friction | 8.0 /s |
| Turn rate | 12 rad/s |
| Restitution | 0.30 |

### Kick
| | |
|---|---|
| Charge time to full | 0.55 s |
| Speed at min charge | 6 m/s |
| Speed at full charge | 17 m/s |
| Reach | radii + 0.35 m |
| Arc | ±60° of facing |
| Soft-touch threshold | 15% charge |
| Dribble nudge speed | 3.2 m/s |

### Dash
| | |
|---|---|
| Double-tap window | 260 ms |
| Duration | 0.22 s |
| Speed | 9.5 m/s |
| Cooldown | 1.6 s |
| Shove impulse | 4.5 m/s |
| Stagger inflicted | 0.4 s |

### Match
| | |
|---|---|
| Concedes to elimination | 6 |
| Celebration pause | 1.2 s |
| Home spot radius | 0.55 R |
| Stagnation timeout | 7 s |
| Stagnation radius | 2 m |

## 7. How these were chosen

Start from physical plausibility, then tune against the numbers that matter to the feel:

- **Top speed 5.6 m/s vs ball 17 m/s.** A struck ball crosses the 19 m pitch in ~1.1 s; a
  player crosses it in ~3.4 s. You cannot chase a shot down, only anticipate it. This ratio is
  the single biggest lever on how defensive the game feels.
- **Damping 0.68/s.** A ball struck at full power still has ~7 m/s after 2 s, so it rattles
  around the circle rather than dying in the middle. Concrete, not grass.
- **Mouth 3.6 m vs player 0.84 m across.** One body covers under a quarter of their own mouth,
  so standing still never makes a goal safe. Guarding requires reading the shot.
- **Dash 9.5 m/s for 0.22 s** covers ~2.1 m — just enough to reach a shot aimed at the far post
  of your own mouth, and not enough to cross the pitch with it.
- **6 concedes** puts a full match at 24 goals minimum.

### What the sweep actually said

Radius and mouth width were swept together, 100 bot-only matches per cell. Mouth width dominates
everything else: at 2.4 m the median match ran past 7 minutes and a fifth never finished at all;
at 3.6 m it lands at 3.1 minutes. Radius mattered far less, and 9.5 m was chosen for the best
win fairness rather than for pace.

The shipping numbers, 150 matches at each difficulty, all of them finishing:

| | median | p90 | goals/min | worst slot's win share |
|---|---|---|---|---|
| All easy | 220 s | 291 s | 7.7 | 1.10× fair |
| All normal | 189 s | 246 s | 9.0 | 1.13× fair |
| All hard | 186 s | 248 s | 9.3 | 1.47× fair |

`BalanceSimTests` re-runs a smaller version of this. Any change to this table should be checked
against it, and a degenerate win distribution — one slot winning far more than a fifth of the
time — is a bug in the AI or the geometry, not an acceptable outcome.
