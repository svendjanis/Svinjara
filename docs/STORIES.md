# Stories

User stories with acceptance criteria. Each is small enough to land in one commit and each has
a test or a named on-device check. `ROADMAP.md` sequences them; this file defines *done*.

Status: `todo` · `wip` · `done`

---

## Epic A — Foundations

### A1 · Project builds and boots — `todo`
**As a developer** I want a generated Xcode project that builds and launches, so every later
story has somewhere to land.
- `xcodegen generate` produces `Svinjara.xcodeproj`; it is git-ignored.
- `xcodebuild … build` succeeds with no warnings for the app and test targets.
- App launches on the iPhone 17 Pro simulator to a placeholder scene, portrait-locked.

### A2 · Vector and RNG primitives — `todo`
**As a developer** I want `Vec2` and a seeded generator, so the simulation can be exact and
reproducible.
- `Vec2` covers add/sub/scale/dot/length/normalise/rotate/angle, plus a safe `normalized` that
  returns zero for a zero vector rather than NaN.
- `SeededRandom` is SplitMix64, gives the same sequence for the same seed, and is a value type
  so copying a state copies the stream.
- Tests: known-answer vectors; two generators with one seed agree over 10 000 draws.

---

## Epic B — The circle

### B1 · Arena geometry — `todo`
**As a player** I want a circular pitch with five goals on the line, so the game has a shape.
- `ArenaGeometry` exposes radius, five goal bearings 72° apart, and each mouth's angular span
  derived from the chord width.
- `isInsideMouth(angle:)` returns the owning player, or nil for wall, and nil for sealed goals.
- Post positions are derived from the mouth ends, never hardcoded.
- Tests: spans do not overlap; total mouth arc is under a third of the circle; sealing a goal
  makes its span read as wall.

### B2 · Players cannot leave — `todo`
**As a player** I want to be stopped by the white line, so the pitch contains the game.
- Position clamps to `R − playerRadius`; radial velocity zeroed, tangential kept.
- Running at the line diagonally slides along it and does not stick or bounce.
- Running at a goal mouth is stopped the same as wall — mouths are not doorways for players.
- Tests: a player driven outward for 5 s never exceeds the radius; tangential speed is retained.

### B3 · Ball rebounds off the line — `todo`
**As a player** I want the ball to stay in play, so a five-way scrap never stops.
- Ball reflects about the inward normal with wall restitution.
- Angle of incidence equals angle of reflection to within 1e-9 for a non-sealed wall hit.
- Ball speed strictly decreases across a bounce.
- Tests: reflection angles at several incidences; energy never increases; a ball fired at the
  wall 10 000 times never ends up outside the circle.

### B4 · Posts are solid — `todo`
**As a player** I want to hear it come back off the post, so shooting has luck and drama.
- Ten static post discs; swept test against the ball's travel segment, not just its endpoint.
- Players also collide with posts and cannot pass through a mouth's frame.
- Tests: a ball aimed exactly at a post centre returns along its own line; a 17 m/s ball aimed
  at a post never tunnels through it.

---

## Epic C — Football

### C1 · Run — `todo`
**As a player** I want responsive running, so the game feels good before anything else does.
- Acceleration toward input, capped top speed, friction when input is released.
- Facing turns toward travel at a limited rate rather than snapping.
- Tests: reaches 99% of top speed within the documented time; stops within the documented time.

### C2 · Kick with charge — `todo`
**As a player** I want to hold to hit it harder, so I can choose between a poke and a rocket.
- Charge accumulates while held, caps at 0.55 s; release strikes along facing.
- Legal only within reach and ±60°; an illegal kick consumes the charge and does nothing.
- Ball velocity is replaced, not added to.
- Tests: power at 0%/50%/100% charge; out-of-arc kick leaves the ball untouched; a ball moving
  toward the kicker does not gain extra speed.

### C3 · Dribble — `todo`
**As a player** I want the ball to stay near my feet when I run with it, so I can carry it.
- A light tap, or contact at low speed, nudges the ball along facing at dribble speed.
- Running into a slow ball pushes it rather than passing through it.
- Test: a player running a straight line keeps the ball within reach for 3 s.

### C4 · Dash and shoulder charge — `todo`
**As a player** I want a lunge, so I can make the save I could not walk to.
- Double-tap kick within 260 ms triggers a 0.22 s burst; 1.6 s cooldown; not available while
  staggered.
- Contact while dashing shoves the victim and staggers them 0.4 s.
- A staggered player cannot kick or dash and steers at reduced authority.
- Tests: cooldown is enforced; dash covers the documented distance; stagger expires exactly.

---

## Epic D — Rules

### D1 · Goals are detected exactly — `todo`
**As a player** I want a shot through the mouth to count and a shot off the post not to.
- Crossing is solved analytically; the bearing is tested at the crossing point.
- Only mouths of live players score; sealed arcs rebound.
- Own goals count against the owner.
- Tests: a 17 m/s shot through a mouth scores in one step; a shot clipping a post does not; a
  shot at a sealed arc rebounds and records nothing.

### D2 · Conceding and the reset — `todo`
**As a player** I want a clear beat after a goal, so I know what happened and can regroup.
- Concede applies immediately; 1.2 s celebration freezes play.
- On resume: ball centred at rest, every live player on their home spot facing centre, all
  transient state cleared.
- Test: state after a reset is identical regardless of what it was before.

### D3 · Elimination seals a goal — `todo`
**As a player** I want a knocked-out rival's goal bricked up, so the pitch changes as we go.
- At 6 conceded the player is removed during that same celebration.
- Their arc becomes wall for ball and players; posts removed.
- Arena radius and every other goal's position are unchanged.
- Tests: the 6th concede eliminates; a ball fired at the sealed arc rebounds; survivors' counts
  and positions untouched.

### D4 · Winning — `todo`
**As a player** I want the match to end when I am the last one standing.
- One live player remaining ends the match; finishing order is recorded.
- A concede that eliminates the fourth player ends the match in the same step.
- Test: a scripted match terminates with exactly one winner and a full four-deep order.

### D5 · Determinism — `todo`
**As a developer** I want identical results from identical inputs, so balance work means
something.
- No clock, no system RNG, no frame-duration dependence anywhere in `Systems/` or `AI/`.
- Test: the same seed and input script produce identical final state twice, including
  positions to the bit.

---

## Epic E — Bots

### E1 · A bot can play at all — `todo`
**As a player** I want opponents that chase, defend and shoot.
- `BotBrain` returns a `PlayerInput` and has no other channel into the simulation.
- States: Defend, Pursue, Attack, Recover, Stagger, with documented transitions.
- Test: in a 60 s bot-only match at least one goal is scored and no bot stands still for 5 s.

### E2 · Bots pick a victim sensibly — `todo`
**As a player** I want bots to punish whoever left their goal open, so leaving mine open matters.
- `ShotEvaluator` ranks the four rival goals by openness, lane clearance and distance.
- Tests: given an obviously open goal and an obviously guarded one, the open one is chosen; a
  goal behind a post-blocked lane is not chosen.

### E3 · Bots defend — `todo`
**As a player** I want bots to come home when threatened.
- `ThreatModel` scores ball distance to own goal against closing speed; above threshold the bot
  takes a spot on the line between ball and mouth.
- Test: a ball rolled at a bot's goal results in the bot positioned between ball and mouth.

### E4 · Difficulty tiers — `todo`
**As a player** I want to choose how hard they are.
- Easy/Normal/Hard differ only in reaction latency, aim σ and dash appetite.
- Test: over 100 sim matches, Hard bots beat Easy bots substantially more than half the time.

### E5 · Balance harness — `todo`
**As a developer** I want to measure balance instead of guessing.
- `BalanceSimTests` runs several hundred headless bot-only matches and reports match duration,
  goals per minute and the win spread.
- Asserts: no match exceeds a hard step cap, every match terminates, and no goal slot wins more
  than twice its fair share.

---

## Epic F — Feel

### F1 · Joystick — `todo`
**As a player** I want a thumb stick that appears where I touch.
- Appears on touch-down in the left half, follows within a radius, releases cleanly.
- A second finger in the right half does not disturb it.
- On-device check: run in all eight directions and in circles without the stick sticking.

### F2 · Kick button with power ring — `todo`
**As a player** I want to see my power as I charge it.
- Ring fills over the charge time; releasing strikes; double-tap dashes rather than kicking.
- Haptic tick at full charge; a distinct one on dash.
- On-device check: charge, release, and double-tap all behave on a real touch sequence.

### F3 · Top-down rendering — `todo`
**As a player** I want to see the whole pitch at once.
- The circle fits the width with the HUD above and controls below; no scrolling, no camera.
- The human's goal is at the bottom whichever slot they drew.
- Positions interpolate between simulation steps so motion is smooth at 60 and 120 Hz.

### F4 · Figures and kits — `todo`
**As a player** I want to tell everyone apart instantly.
- Shirt, head, hair, nose and boots drawn per `ART_STYLE.md`; facing readable at a glance.
- Own player carries an outline ring.
- Test: `NationCatalog` has exactly 20 entries, unique names, and no two shirt colours within
  the minimum hue separation.

### F5 · HUD — `todo`
**As a player** I want to know everyone's tally without taking my eyes off the ball.
- Five chips in goal order, six pips each, own chip emphasised, eliminated chips greyed.
- Goal banner in the conceding player's colour for the celebration, with an own-goal variant.

---

## Epic G — Shell

### G1 · Main menu — `todo`
Play, difficulty, sound, lifetime stats. Play goes to nation select.

### G2 · Nation select — `todo`
**As a player** I want to pick who I am before kickoff.
- Grid of 20, each showing its kit; selection previews the actual figure that will take the
  pitch.
- The previous choice is preselected on return.
- Bots are dealt distinct nations, never the player's, never a confusable clash.

### G3 · Results — `todo`
Final standings 1st to 5th with kits and conceded counts, a rematch button that keeps the
nation, and a button back to the menu.

### G4 · Persistence — `todo`
- `LocalStore` behind a protocol over `UserDefaults`; last nation, difficulty, sound, lifetime
  stats.
- Tests use an in-memory store and never touch real defaults.
- Test: values round-trip; a first run with empty storage yields sane defaults.

---

## Epic H — Polish

### H1 · Sound — `todo`
Kick, post clang, goal, whistle, elimination sting — synthesised, no audio assets. Respects the
sound setting.

### H2 · Juice — `todo`
Screen shake on a goal, ball scuff trail at speed, elimination fade, dash streaks, stagger
wobble. Nothing that obscures the ball.

### H3 · App icon — `todo`
Generated 1024² icon: the circle, five coloured arcs, a ball.
