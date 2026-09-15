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
- The owner of that mouth **concedes one**.
- **The scorer takes one back off their own tally**, floored at zero. Not for an own goal.

  This rule is why going forward is worth anything. Without it the game has a dominant
  strategy — sit on your own line and wait — because only conceding counts, so every goal you
  score helps all four rivals equally while your own mouth is unguarded. Measured over 150 bot
  matches, the tier that attacked 37% of the time finished 3.42nd on average and the tier that
  attacked 21% finished 2.63rd. With redemption the order is right way up: 2.55 against 3.47.

  **The floor at zero is load-bearing.** Without it every goal moves exactly one mark from the
  scorer to the conceder, the total across all five players never grows, and nobody is ever
  eliminated — the match cannot end.
- **Own goals count.** Putting it through your own mouth concedes exactly as if a rival did it.
- The last player to touch the ball is recorded for the announcement line only ("Brazil beats
  Croatia"), and has no rules effect.
- A sealed goal (owner eliminated) is wall. The ball rebounds; nothing is recorded.

## 4. Restart after a goal

1. Play freezes for a 1.2 s celebration; the concede is applied immediately, not after the pause.
2. **The player who conceded restarts, with a goal kick.** The ball is placed at `0.78 R` on
   their own goal's bearing — 2.1 m in front of their own line — and they stand one contact
   behind it, facing the centre. It is already at their feet; there is nothing to race for.
3. Every other live player returns to their home spot: `0.88 R` along their own goal's bearing —
   1.1 m off their own line — facing the centre. Deep on purpose: restarting in front of your
   own goal leaves every mouth open to whoever wins the race to the ball. Velocity zeroed, charge cancelled, dash cooldown cleared, stagger cleared.
4. **Every line-up is nudged** — up to ±0.06 R in depth and half a mouth sideways, so nobody
   stops guarding their own goal, and no two restarts in a match present the same picture.
5. Play resumes for everyone at the same instant, but **the other players stand off for
   1.3 s**, the way they would at a goal kick. This is honoured by the bots rather than
   enforced by the engine, which is the honest place for it: it is not a rule anything stops
   you breaking, it is opponents giving you room. Without it the taker had the ball for a
   median of 1.75 s before a rival could kick it, and only a third of restarts survived two
   seconds — fine for a bot, which takes its first touch 0.01 s after the whistle, and no use
   at all to a person who has just watched a goal go in. With it, 94% of restarts are still
   uncontested after two seconds.
6. The HUD says **YOUR BALL** when the restart is the human's. A possession nobody tells you
   about is one you spend watching somebody else take it.

The **opening kickoff** is the exception: nobody has earned it, so the ball is on the centre
spot and everyone starts at home. So is a restart whose taker was eliminated by the goal that
caused it — handing it to somebody else would be arbitrary, so it reverts to a scramble.

Why the conceder gets it: a restart used to put all five players the same distance from a ball
on the centre spot, which is a five-way sprint with a free shot at four unguarded mouths as the
prize. Measured, 26% of every goal in the game arrived in the same quarter-second of every
restart. Giving the ball to whoever was just scored against removes the race, and removes it in
the direction that is also fair — the restart is small compensation for the goal. See
`docs/PHYSICS_AND_TUNING.md` §7.3.

## 5. Elimination

- On reaching **4 conceded**, the player is eliminated **immediately** — at the moment of the
  fourth concede, during the same celebration pause.
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
- **The human's match ends the moment the human is out**, whoever else is still standing.
  Being knocked out is not a reason to sit and watch four bots finish. The results show the
  place they actually finished in, with the survivors ranked by how few they have let in as
  the table stood. This is a presentation rule, not a simulation one: the engine is perfectly
  capable of playing the match out, and does so in the balance harness.

## 7. Ball possession and the kick

- There is no possession flag. The ball is simply near your feet or it is not.
- A kick is legal when the ball centre lies within `playerRadius + ballRadius + 0.50 m` and
  within **±75°** of the kicker's facing. Both are generous on purpose: a thumb steers the
  facing, and nobody can hold a heading to the degree while four people are barging them.
- A kick may either carry an **explicit power** or be struck at whatever **charge** has
  accumulated. The thumbs supply an explicit full power, because shooting is a tap and there is
  nothing to hold; bots charge, which is how they vary power by range.
- Charge, when used, scales linearly up to 0.55 s: 8.5 m/s at nothing held, 17 m/s at full.
- A shot may be **snapped onto an open mouth within 40°** of the striker's facing, when the
  input asks for it. The goals are 72° apart, so most headings are within reach of some mouth —
  but your own is excluded, which means clearing away from your own line is never quietly bent
  into a shot at somebody sideways. Never onto the striker's own goal, and never onto a sealed one. This is an
  aid for thumbs — a bot aims precisely and has no reason to request it — and it travels
  through the same input struct as everything else.
- The ball's existing velocity is **replaced**, not added to, along the kick direction. Kicking
  a ball that is already flying at you does not produce a 30 m/s rocket.
- Running your **body** into the ball pushes it off at a fraction of the speed you were
  carrying into it, and only the component going into the ball — running past it must not fling
  it sideways. The fraction is under 1 deliberately, so a carried ball settles back at your feet
  instead of outrunning you. There is no possession flag and no magnetism.

## 8. Contact

- Players collide as equal-mass discs with low restitution — bodies jostle, they do not bounce
  apart like billiards.
- A player in the **dash** state — a tackle — who contacts another applies a shove impulse and
  **staggers** the victim for 0.4 s. A staggered player cannot kick or tackle and steers at
  reduced authority. A tackle that reaches the *ball* knocks it loose, since a body moving at
  lunge speed carries it well clear.
- There are no fouls and no free kicks. Barging is the game.

## 9. Determinism

Given the same seed and the same sequence of per-player input frames, a match produces an
identical result, step for step. Nothing in the simulation may read wall-clock time, system
RNG, or frame duration — the engine steps at a fixed 1/120 s and all randomness comes from the
seeded generator. `DeterminismTests` enforces this.

## 10. Progress

If the ball has not travelled more than **2 m** from where it was **7 seconds** ago, it is
returned to the centre spot at rest. Nothing else changes: play does not stop, nobody is
repositioned, nothing is recorded.

This exists because a ball resting against the paint cannot be struck along the wall at all —
the widest kick available is 53° from the outward radial, since standing any further round
would put the striker outside the pitch. Two players leaning on such a ball can hold it there
indefinitely, and in bot-only play roughly one match in six never reached a winner. A human can
do the same thing, deliberately or not.

The trigger is the ball having *gone nowhere*, not *nobody having touched it* — in a stalemate
the ball is being touched constantly.
