# Game Design

## 1. The pitch in one sentence

Five players, one ball, one concrete circle, five little goals on the line — everyone against
everyone, and the first to let six in walks home.

## 2. Where the name comes from

*Svinjara* is the schoolyard game played on any concrete court in the Balkans. No teams, no
referee, no throw-ins. Everyone guards their own goal and everyone is fair game. Whoever lets in
the most is the *svinja*. This is that game, kept honest: same rules, same concrete, five goals
pinned to the white circle.

## 3. Core loop

```
kick off  →  scrap for the ball  →  pick a victim  →  shoot
    ↑                                                   │
    └──────  someone concedes, reset to centre  ←───────┘
                        │
              6th concede → that goal is bricked up, player walks
                        │
              one player left → winner
```

A match is roughly three to five minutes: 24 goals have to be scored before four players are
eliminated, and the pitch gets emptier — and each remaining goal proportionally more exposed —
as it goes.

## 4. What makes it interesting

**No allies, but temporary alignment.** You cannot mark four goals at once. If a rival is
lining up a shot at someone else's goal, the right move is to leave them alone. Every player is
constantly choosing between defending and joining the feeding frenzy.

**The leader is the target.** A player on 0 conceded who parks in their own mouth is a boring
opponent to shoot at. The shot evaluator that drives the bots ranks goals by *openness*, which
means the moment you step off your line to attack, four opponents notice. Greed is punished
about as often as it pays.

**Everyone is a keeper and nobody has hands.** There is no goalkeeper role because there is no
one else to be. You defend by standing in the way, and by the dash — a short lunge that saves
the shot you were never going to reach, at the cost of leaving your mouth wide open if you
mistime it.

**Elimination changes the geometry.** A dead player's goal is bricked up into solid wall. That
wall is a new surface to ricochet off and one fewer goal to feed on, so the survivors' goals
absorb the entire remaining pressure. The last two minutes of a match are much sharper than the
first.

## 5. The circle

One circle, the white line of a centre circle painted on a concrete court. Nobody may leave it.
The ball rebounds off the line everywhere except the five goal mouths — play effectively never
stops, which is what keeps a five-way scrap moving.

Five goals sit *on* the line at 72° apart. Each is two solid posts with an open mouth between
them. Posts are real: ball and players both bounce off them, so "off the post" is a genuine and
frequent event rather than a rounding error.

The camera is fixed and top-down, held in **landscape** with the whole circle always on screen.
The circle fits the height and the margins either side of it carry the thumbs, which is what
landscape buys: the controls sit beside the pitch rather than on top of it. **The human
player's goal is always rotated to the bottom of the screen**, so "back" always means "toward
my goal" regardless of which slot the player drew.

## 6. Controls

| Input | Action |
|---|---|
| Left thumb — floating joystick | Run. The figure turns toward travel. |
| Right thumb — hold kick | Charge. A power ring fills around the button over 0.55 s. |
| Release kick | Strike along the facing direction at the charged power. |
| Light tap kick | Soft touch — a dribble nudge that keeps the ball at your feet. |
| Double-tap kick | Dash: a 0.22 s lunge. Reaches balls you can't walk to, and shoulder-charges rivals off the ball. 1.6 s cooldown. |

There is no pass button because there is nobody to pass to.

## 7. Choosing a nation

Before kickoff the player picks from 20 footballing nations. Nationality is cosmetic — it does
not touch speed, power or anything else, and the design should keep it that way so no kit is
"the good one". What it changes:

- **Kit.** Shirt colours and pattern (solid, stripes, checks, sash), shorts, socks.
- **The player themselves.** Skin tone and hair colour/style are drawn from a per-nation range,
  so two Croatians look like two different people rather than one sprite twice.

The four bots are dealt distinct nations at random, never the player's, and never two kits close
enough to confuse at a glance — clashing kits are re-rolled.

## 8. Difficulty

Three tiers, differing only in reaction latency, aim error and how eagerly bots spend the dash.
No bot gets extra speed, extra power, or knowledge the player doesn't have — bots submit the
exact same input struct the human's thumbs produce. This is a fairness rule and it is enforced
by the type system, not by discipline.

| | Reaction | Aim error σ | Dash appetite |
|---|---|---|---|
| Easy | 150 ms | 9° | 0.15 |
| Normal | 90 ms | 5° | 0.30 |
| Hard | 45 ms | 2.5° | 0.45 |

**Reaction is perception lag**, not thinking frequency: a bot steers toward the ball as it was
that long ago. The distinction is not academic. Modelled as "how often the bot reconsiders" it
made higher difficulty *worse* — reconsidering more often catches more of the brief windows in
which you happen to be nearest the ball, and in this game going for the ball is what loses you
matches. Measured over 150 matches the fast tier finished 3.42nd on average against the slow
tier's 2.63rd. As perception lag it degrades attacking and defending alike, and the tiers come
out in the right order: hard 2.61st, easy 3.36th.

That underlying tension is real and deliberate. **Only conceding counts**, so every second you
spend attacking is a second your own mouth is unguarded, and the goal you score helps every
survivor equally. Attacking is a risk you take to knock somebody out, never a free move.

## 9. Deliberately out of scope

Everything local, nothing online: no accounts, no leaderboards, no server, no database. No
career mode, no unlockables, no power-ups, no stamina bar, no fouls, no offside. One match type.
The game should be entirely understood within ten seconds of the first kickoff.
