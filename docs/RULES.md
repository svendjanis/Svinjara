# Rules

The authoritative statement of match rules. `Sources/Systems/MatchEngine.swift` implements this
file, and `Tests/` asserts it. If the code and this document disagree, one of them is a bug.

## 1. Setup

- Exactly **5 players**: one human, four bots. All have identical physical capabilities.
- Each player **owns exactly one goal**, assigned at kickoff and never reassigned.
- Goals sit on the white line at **72° apart**. The human's goal is rotated to screen bottom.
- Each player starts with **0 conceded**.

## 2. Boundary

- **Players may never leave the circle.** Position is hard-clamped to `r ≤ R − playerRadius`,
  including through the goal mouths. Radial velocity is zeroed on contact, tangential velocity
  is kept, so running into the line slides you along it rather than sticking you to it.
- **The ball rebounds off the line** everywhere except inside a goal mouth's angular span.
- **Posts are solid** for both ball and players.

## 3. Scoring

A goal is recorded when, in a single step, the ball's centre crosses from `r < R` to `r ≥ R`
while inside the angular span of a mouth belonging to a **live** player.

- The crossing point is found by solving for the exact fraction of the step at which `r = R`,
  and the angle is tested **at that point** — not before the step and not after it. A fast shot
  can travel further than a mouth is wide in one 1/120 s step, so testing the endpoints alone
  would let goals through the posts.
- The owner of that mouth **concedes one**. There is no notion of who "scored" for the score
  itself — only conceding is counted.
- **Own goals count.** Putting it through your own mouth concedes exactly as if a rival did it.
- The last player to touch the ball is recorded for the announcement line only ("Brazil beats
  Croatia"), and has no rules effect.
- A sealed goal (owner eliminated) is wall. The ball rebounds; nothing is recorded.

## 4. Restart after a goal

1. Play freezes for a 1.2 s celebration; the concede is applied immediately, not after the pause.
2. Ball returns to the centre spot, at rest.
3. Every live player returns to their home spot: `0.55 R` along their own goal's bearing, facing
   the centre. Velocity zeroed, charge cancelled, dash cooldown cleared, stagger cleared.
4. Play resumes for everyone at the same instant. There is no kickoff possession — it is a race
   to the centre and that is intended.

## 5. Elimination

- On reaching **6 conceded**, the player is eliminated **immediately** — at the moment of the
  sixth concede, during the same celebration pause.
- The eliminated player is removed from the pitch. They cannot be collided with and take no
  further part.
- **Their goal mouth seals into solid wall.** Its posts are removed with it: the arc becomes
  indistinguishable from the rest of the line for physics, and is painted as bricked up.
- **The arena does not change size, and the remaining goals do not move.** Each survivor keeps
  the exact goal they have been defending all match.
- Conceded counts of the survivors are untouched.

## 6. Winning

- When **one live player remains**, the match ends and that player wins.
- If the final concede eliminates the second-to-last player, the survivor wins immediately.
- A player who reaches 6 wins nothing; finishing order is recorded (4th out = runner-up) purely
  for the results screen.

## 7. Ball possession and the kick

- There is no possession flag. The ball is simply near your feet or it is not.
- A kick is legal when the ball centre lies within `playerRadius + ballRadius + 0.35 m` and
  within **±60°** of the kicker's facing.
- Kick power scales linearly with charge time, capped at 0.55 s. Releasing below 15% charge is
  a **soft touch** — a dribble nudge, not a shot.
- The ball's existing velocity is **replaced**, not added to, along the kick direction. Kicking
  a ball that is already flying at you does not produce a 30 m/s rocket.
- Running your **body** into the ball pushes it off at the speed you were carrying into it,
  and only that component — running past the ball must not fling it sideways. This is what
  dribbling is: the ball rolls, decays under rolling resistance, and you catch it a step later.
  There is no possession flag and no magnetism.

## 8. Contact

- Players collide as equal-mass discs with low restitution — bodies jostle, they do not bounce
  apart like billiards.
- A player in the **dash** state who contacts another applies a shove impulse and **staggers**
  the victim for 0.4 s. A staggered player cannot kick or dash and steers at reduced authority.
- There are no fouls and no free kicks. Barging is the game.

## 9. Determinism

Given the same seed and the same sequence of per-player input frames, a match produces an
identical result, step for step. Nothing in the simulation may read wall-clock time, system
RNG, or frame duration — the engine steps at a fixed 1/120 s and all randomness comes from the
seeded generator. `DeterminismTests` enforces this.
