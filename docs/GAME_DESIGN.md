# Game Design

## 1. The pitch in one sentence

Five players, one ball, one concrete circle, five little goals on the line — everyone against
everyone, and the first to let four in walks home.

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

A match is roughly three to five minutes: sixteen marks have to be handed out before four
players are eliminated, and a good many more goals than that scored to do it, since every goal
you score wipes one off your own tally. The pitch gets emptier — and each remaining goal
proportionally more exposed — as it goes.

## 4. What makes it interesting

**No allies, but temporary alignment.** You cannot mark four goals at once. If a rival is
lining up a shot at someone else's goal, the right move is to leave them alone. Every player is
constantly choosing between defending and joining the feeding frenzy.

**You cannot win by hiding.** Score, and one mark comes off your own tally — never below zero,
and never for an own goal. This is the rule that makes the game a game. Without it there is a
dominant strategy: park on your own line and wait, because only conceding counts and every goal
you score helps all four rivals equally while your own mouth sits open. It is not a theoretical
worry — measured over 150 bot matches, the tier that attacked more finished *worse*, 3.42nd on
average against 2.63rd. Being able to claw one back is what puts the risk back on the right
side of the ledger.

**The leader is the target.** A player on 0 conceded who parks in their own mouth has nothing
to gain from it and is a tempting thing to shoot at. The shot evaluator that drives the bots
ranks goals by *openness*, so the moment you step off your line to attack, four opponents
notice. Greed is punished about as often as it pays.

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
| Left thumb — floating joystick | Run. The figure turns toward travel, and that is also where you are aiming. |
| **SHOOT** | A full-blooded shot, the instant your thumb lands. Nothing to hold, nothing to time. The button dims when the ball is not close enough to strike, which is the answer to "why did nothing happen?". |
| **TACKLE** | A 0.22 s lunge. Reach the ball and you knock it loose; reach the player and you shove and stagger them. 1.6 s cooldown. |

There is no pass button because there is nobody to pass to.

**Aim assist.** A shot within 25° of an open mouth is snapped onto it. A thumb on a joystick
cannot aim to the degree, and without the assist the only way to line a goal up is to run at
it — which means chasing the ball toward your target rather than choosing one. The assist helps
you hit the goal you picked; it never picks it for you, it never snaps onto your own goal, and
it never snaps onto one that has been bricked up.

Carrying the ball is what running into it does — the ball leaves your feet at rather less than
your own speed, so it settles back to you rather than running away. The button is for hitting
it, not for nudging it.

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

Four tiers' worth of knobs across three tiers: reaction latency, aim error, how eagerly bots
spend the dash, and how good a chance they hold out for before shooting. No bot gets extra
speed, extra power, or knowledge the player doesn't have — bots submit the exact same input
struct the human's thumbs produce. This is a fairness rule and it is enforced by the type
system, not by discipline.

| | Reaction | Aim error σ | Dash appetite | Shot bar | Carry patience |
|---|---|---|---|---|---|
| Easy | 150 ms | 9° | 0.15 | 0.55 | 1.2 s |
| Normal | 90 ms | 5° | 0.30 | 0.75 | 1.8 s |
| Hard | 45 ms | 2.5° | 0.45 | 0.95 | 2.4 s |

**Every tier runs at 93% of full tilt**, and that is a handicap rather than a hidden advantage:
`move` already means "how hard the stick is pushed", so a bot holding it a touch short of the
rim is something a person does too. It exists because five players all running flat out all the
time read as a machine rather than as opponents, and because the person holding the phone
should be the fastest thing on the pitch when they want to be.

It is deliberately *not* a difficulty axis. It briefly was — 0.88 for easy up to 0.97 for hard
— and it was the wrong knob twice over: a slower bot defends as badly as it attacks, so the
tiers barely separated, and because slow play spreads the goals evenly an all-easy match
stopped being able to knock anybody out at all. Eight of eighty never reached a winner inside
fifteen minutes.

**The shot bar is what stops a bot hitting the best shot available when the best available is
dreadful.** Below it, the thing to do is carry the ball until something better appears; carry
patience is the escape valve, and it measures *lack of progress* rather than time on the ball,
so a bot running up the pitch with it is not on a clock. Without the distinction a goal kick
was simply hoofed the instant the count expired, from ten metres inside the taker's own half.

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
