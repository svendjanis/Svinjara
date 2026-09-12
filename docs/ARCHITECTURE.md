# Architecture

## 1. Shape of the app

SwiftUI owns the app shell and every static screen. SpriteKit owns exactly one thing: the match
scene. They meet at a single narrow bridge.

```
SvinjaraApp (@main)
└── RootView                         ← owns AppModel, switches on Screen
    ├── MenuView                     SwiftUI
    ├── NationSelectView             SwiftUI
    ├── ResultsView                  SwiftUI
    ├── SettingsView                 SwiftUI
    └── GameViewRepresentable        UIViewRepresentable → SKView → GameScene
                                                                      │
                                     GameSceneDelegate ◄──────────────┘
                                     (match ended, standings)
```

The bridge is one protocol with one method. The scene knows nothing about SwiftUI; the SwiftUI
layer knows nothing about SpriteKit beyond constructing the view. Screen state lives in
`AppModel` (`@Observable`), and the scene is built fresh per match and torn down on exit, so no
stale state survives between matches.

## 2. The line nothing crosses

```
        ┌──────────────── Sources/Systems + Sources/AI ────────────────┐
        │  Pure value types. No SpriteKit. No UIKit. No Foundation     │
        │  beyond the numerics. No clock, no system RNG, no I/O.       │
        │                                                              │
        │     MatchEngine.step(inputs:) -> [MatchEvent]                │
        └──────────────────────────────────────────────────────────────┘
                                    ▲
                     reads state    │    submits PlayerInput
                                    │
        ┌───────────────── Sources/Entities + Art + UI ────────────────┐
        │  SpriteKit. Draws whatever MatchState currently says.        │
        │  Owns no rules and may not mutate simulation state.          │
        └──────────────────────────────────────────────────────────────┘
```

This is the same call `DoodleJump` made for `PlayerPhysics`, taken further because here it is
the entire game and not just one solver. The payoff is that the rules, the collisions and the
bot AI all run in a unit test in milliseconds with no scene, no view and no device — which is
the only practical way to balance a five-way free-for-all.

`SKPhysicsBody` is not used anywhere. The whole world is six discs inside a circle; solving it
by hand is less code than configuring `SKPhysicsWorld` would be, and it is exact, reproducible
and steppable at arbitrary speed.

## 3. Directory layout

```
Sources/
  App/        SvinjaraApp, RootView, AppModel, GameViewRepresentable
  Game/       MatchState, MatchPhase, MatchEvent, PlayerInput, Tuning,
              Nation, NationCatalog, Appearance, GameScene
  Systems/    Vec2, SeededRandom, ArenaGeometry, CollisionSolver, BallPhysics,
              PlayerPhysics, KickResolver, GoalDetector, MatchEngine,
              TouchInput, LocalStore
  AI/         BotBrain, BotDifficulty, ThreatModel, ShotEvaluator, Steering
  Entities/   ArenaNode, GoalNode, PlayerNode, BallNode
  Art/        Theme, ArtFactory, ConcreteTexture, KitPainter
  UI/         MenuView, NationSelectView, ResultsView, SettingsView,
              HUDNode, JoystickNode, KickButtonNode
Tests/        one flat file per system
```

## 4. The simulation step

`MatchEngine` is the only thing allowed to mutate `MatchState`. Its step is a pure function of
`(state, inputs, dt)` and returns the events the renderer should react to.

```swift
mutating func step(inputs: [PlayerInput?], dt: Double) -> [MatchEvent]
```

Order within one step — this order is load-bearing and the tests pin it:

1. **Phase clock.** If celebrating, tick it down; on expiry reset positions and resume. While
   celebrating, steps 2–8 are skipped entirely.
2. **Intent.** Apply each `PlayerInput` — steering, charge accumulation, dash triggers.
   Staggered players have their intent damped here rather than ignored.
3. **Integrate players.** Accelerate, cap speed, apply friction, advance position.
4. **Clamp players** to the circle and resolve player↔player and player↔post contacts.
5. **Integrate ball.** Damping, then advance position.
6. **Goal test.** Solve the exact boundary crossing (see `RULES.md` §3) *before* the wall
   bounce, so a shot through a mouth is never reflected back by the wall it went through.
7. **Ball vs line and posts.** Reflect if it did not score.
8. **Kicks.** Resolve releases, soft touches and dribble nudges last so a kick's result is
   never overwritten by the same step's integration.
9. **Rules.** Apply concedes, eliminate at 6, seal goals, test the win condition.

The engine never reads a clock. `GameScene` accumulates real frame time and calls `step` a
whole number of times at exactly `1/120 s`, then renders an interpolation between the previous
and current state so motion stays smooth on a 60 or 120 Hz display regardless.

## 5. Inputs, and why bots use the same struct

```swift
struct PlayerInput {
    var move: Vec2        // desired direction, magnitude 0…1
    var kickHeld: Bool
    var kickReleased: Bool
    var dashRequested: Bool
}
```

The human's thumbs produce this. `BotBrain.decide(...)` also produces exactly this, and it is
the only channel a bot has. A bot therefore cannot teleport, cannot exceed the human's top
speed and cannot kick further, because none of those are expressible in the struct. Fairness is
a property of the type, not of anyone's restraint.

It also means a match can be driven entirely from a recorded array of input frames, which is
what makes `DeterminismTests` and `BalanceSimTests` possible.

## 6. Rendering

`GameScene` holds one node per entity and moves them; nothing is created or destroyed during
play. Every texture is drawn once with Core Graphics at load and cached in `ArtFactory` — the
concrete surface, the painted line, each nation's kit. There are no image assets in the bundle
beyond the app icon.

Node z-order, bottom to top: concrete → painted line and goal arcs → shadows → ball → players →
posts (so a player behind a post is occluded by it) → HUD.

## 7. Persistence

`LocalStore` wraps `UserDefaults` behind a small protocol, holding the last chosen nation, the
difficulty, sound preference and lifetime stats (matches played, won, goals conceded). It is
injected, so tests use an in-memory implementation and never touch the real defaults. There is
no database and nothing leaves the device.
