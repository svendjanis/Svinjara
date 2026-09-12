# Tools

`MakeAppIcon.swift` draws the app icon — the concrete circle, five little goals in five kits,
and the ball. Same principle as everything else in the game: the icon is a recipe rather than
an asset, so it can be regenerated at any size.

```bash
swiftc -O -o /tmp/makeicon Tools/MakeAppIcon.swift
/tmp/makeicon Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png
```

It renders into an explicit opaque 8-bit 1024×1024 context on purpose: an iOS app icon may not
carry an alpha channel, and `NSImage.lockFocus` would quietly render at the display's 2× scale.
