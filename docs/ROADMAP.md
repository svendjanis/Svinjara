# Roadmap

Eight milestones. Each one ends with the project building, the suite green, and a commit. The
order is chosen so the game is playable as early as possible and everything after M5 is
improvement rather than plumbing.

| | Milestone | Stories | Ends when |
|---|---|---|---|
| **M0** | Scaffold | A1 | App boots on the simulator; docs and `project.yml` in place |
| **M1** | Solver | A2, B1–B4, C1 | A ball can be fired into the circle and bounces forever, under test |
| **M2** | Rules | C2–C4, D1–D5 | A scripted match reaches a winner headlessly |
| **M3** | Render | F3, F4 | The match is visible and readable on the simulator |
| **M4** | Input | F1, F2 | A human can score a goal with their thumbs |
| **M5** | Bots | E1–E5 | Four bots make a real match of it; balance measured |
| **M6** | Shell | G1–G4 | Menu → nation select → match → results → rematch, all persisted |
| **M7** | Polish | F5, H1–H3 | HUD, sound, juice, icon |

**M2 is the interesting checkpoint** — at that point the entire game exists and can be played
to completion by a test, with no pixels drawn. Everything from M3 on is presentation and
opponents.

## Order rationale

Rules before rendering because the rules are the risky part and a bug in the goal-crossing
solver is far cheaper to find in a test than by watching a shot look wrong. Input before bots
because a human needs to feel the kick before bot behaviour can be judged against it. Balance
last among the gameplay work because it depends on everything else being final.

## Definition of done for a milestone

- Every story in it meets its acceptance criteria in `STORIES.md`.
- `xcodebuild … test` passes with no new warnings.
- `Sources/Systems` and `Sources/AI` still import no SpriteKit and no UIKit.
- `PHYSICS_AND_TUNING.md` matches `Tuning.swift` if any number moved.
- One commit, message naming the milestone and the stories it closed.
