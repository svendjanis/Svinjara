# Svinjara

Five players, one ball, one concrete circle, five little goals on the white line. Everyone
against everyone — the first to let four in walks home, and the last one standing wins.

Native SpriteKit + SwiftUI, no third-party dependencies, no backend, no database. Everything
lives on the device.

Pick one of 20 footballing nations, then it's a free-for-all. You defend your own goal and
attack the other four. Left thumb runs; SHOOT and TACKLE sit under the right one.

## Requirements

- Xcode 16 or newer (developed against Xcode 26.6 / Swift 6.3)
- iOS 18.0+ target
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) — `brew install xcodegen`

## Build and run

```bash
xcodegen generate
open Svinjara.xcodeproj
```

Or entirely from the command line:

```bash
xcodegen generate
xcodebuild -project Svinjara.xcodeproj -scheme Svinjara \
           -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

`Svinjara.xcodeproj` is generated and git-ignored — `project.yml` is the source of truth, so
project settings diff cleanly and never conflict.

## Run it on a real device

```bash
xcodegen generate
xcodebuild -project Svinjara.xcodeproj -scheme Svinjara \
           -destination 'platform=iOS,id=<device udid>' \
           -derivedDataPath build-device -allowProvisioningUpdates build
xcrun devicectl device install app --device <device udid> \
      build-device/Build/Products/Debug-iphoneos/Svinjara.app
```

`xcrun devicectl list devices` prints the udid. The app is landscape-only, so hold the phone
sideways: left thumb anywhere on the left half to run, and the SHOOT and TACKLE buttons under
the right one.

## Tests

```bash
xcodegen generate
xcodebuild -project Svinjara.xcodeproj -scheme Svinjara \
           -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

The physics, the rules and the bot AI are plain value types with no SpriteKit or UIKit
dependency, so a whole four-minute match simulates headlessly in milliseconds. That is what
makes it possible to balance a five-way free-for-all over hundreds of matches instead of by
feel — see `BalanceSimTests`.

## Docs

| | |
|---|---|
| [GAME_DESIGN.md](docs/GAME_DESIGN.md) | What the game is and why it's interesting |
| [RULES.md](docs/RULES.md) | The authoritative match rules the engine implements |
| [ARCHITECTURE.md](docs/ARCHITECTURE.md) | How the app is put together |
| [PHYSICS_AND_TUNING.md](docs/PHYSICS_AND_TUNING.md) | The solver, and every tunable number |
| [ART_STYLE.md](docs/ART_STYLE.md) | Everything is drawn in code — this is how |
| [STORIES.md](docs/STORIES.md) | Stories with acceptance criteria |
| [ROADMAP.md](docs/ROADMAP.md) | Milestones and their order |
