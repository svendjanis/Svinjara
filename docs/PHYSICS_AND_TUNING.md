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

SI throughout: metres, seconds, m/s, m/s². The pitch is 11 m in radius, a real centre circle is
9.15 m, so the scale is honest and the numbers can be reasoned about physically. Conversion to
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

**Tunnelling.** Only the ball is fast enough to matter: at 17 m/s it moves 14 cm per step, which
is larger than the ball itself. The goal test therefore solves the crossing analytically rather
than sampling positions — see below. Post contacts use a swept test against the segment the
ball travelled, not just its endpoint.

## 5. The goal crossing, exactly

This is the one place where an approximation would be felt by the player, so it is solved
properly. With the ball at `p₀` moving to `p₁ = p₀ + v·dt`, find `t ∈ [0,1]` where
`|p₀ + t·(p₁ − p₀)| = R`:

```
a = |Δ|²,  b = 2(p₀·Δ),  c = |p₀|² − R²
t = (−b + √(b² − 4ac)) / 2a
```

Take the crossing point `p₀ + t·Δ`, compute its bearing, and test *that* angle against the
mouth spans. Testing the before or after position instead would let a hard shot appear to pass
through a post, or score from a mouth it only travelled past.

## 6. The tuning table

All of these live in `Tuning.swift` as a single struct with defaults, so a balance test can
construct a variant without touching global state.

### Arena
| | |
|---|---|
| Pitch radius | 11.0 m |
| Goal mouth chord | 2.4 m |
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

## 7. How these were chosen

Start from physical plausibility, then tune against the numbers that matter to the feel:

- **Top speed 5.6 m/s vs ball 17 m/s.** A struck ball crosses the 22 m pitch in ~1.3 s; a
  player crosses it in ~4 s. You cannot chase a shot down, only anticipate it. This ratio is
  the single biggest lever on how defensive the game feels.
- **Damping 0.68/s.** A ball struck at full power still has ~7 m/s after 2 s, so it rattles
  around the circle rather than dying in the middle. Concrete, not grass.
- **Mouth 2.4 m vs player 0.84 m across.** One body covers about a third of their own mouth,
  so standing still never makes a goal safe. Guarding requires reading the shot.
- **Dash 9.5 m/s for 0.22 s** covers ~2 m — just enough to reach a shot aimed at the far post
  of your own mouth, and not enough to cross the pitch with it.
- **6 concedes** puts a full match at 24 goals. Scoring rate in the balance sim runs about
  6–8 goals/minute across all five goals, which lands a match in the 3–5 minute window.

`BalanceSimTests` runs a few hundred bot-only matches and reports match length, goals per
minute and the spread of winners. Any change to this table should be re-run against it, and
a degenerate win distribution (one slot winning far more than a fifth of the time) is a bug in
the AI or the geometry, not an acceptable outcome.
