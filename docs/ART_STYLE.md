# Art Style

## 1. Principle

Everything is drawn in code. There are no image assets in the bundle beyond the app icon.
`ArtFactory` renders each texture once with Core Graphics at scene load and caches it; a
national kit is therefore a handful of colours in a table, not twenty PNGs, and adding a nation
costs one line.

The look is a concrete court seen from directly overhead on a bright day: flat, slightly dirty,
high contrast, no gradients pretending to be 3D. Readability beats detail — at any moment the
player must be able to tell five figures apart and find the ball instantly.

## 2. Surface

Concrete is drawn once into a tile texture: a mid-grey base with per-pixel value noise, a few
darker aggregate speckles, two or three hairline cracks, and a subtle large-scale blotch layer
so it does not read as repeating. Slightly cooler grey than photographic concrete, so the white
paint and the kits both pop against it.

The white line is genuine paint: 8 cm wide, not pure white but a scuffed off-white, with small
gaps and thin spots so it looks walked-on rather than vector-perfect.

Each live goal's arc is painted in that player's shirt colour — a thicker band laid over the
white line. This is the one piece of information the player needs constantly (*whose goal is
that?*) and colour on the ground answers it without a label.

A sealed goal is painted over: the arc becomes a dark brick-grey patch, visibly a repair rather
than original surface, and its posts are gone.

## 3. Figures

Seen from directly above, so the silhouette is shoulders and a head, not a face. Built from
five drawn parts:

```
        ╭─────╮
       ╱  ███  ╲        ███  hair cap — nation hair palette
      │  ▓▓▓▓▓  │       ▓▓▓  head disc — nation skin range
      │    ▲    │        ▲   nose wedge — points where you face
      ╰──╮   ╭──╯
    ╭────┴───┴────╮
    │  ██  ██  ██ │      ██   shirt — nation colours + pattern
    │  ██  ██  ██ │
    ╰──────┬──────╯
        ▪     ▪           ▪   boots, animated with the run cycle
```

- **Shirt** is the large, always-visible shape and carries the identity: primary colour with
  one of four patterns — solid, vertical stripes, checks, sash.
- **Head** is a disc in a skin tone sampled from the nation's range.
- **Hair** is a cap covering the rear of the head, in one of five styles (short, fade, curly,
  long, bald) from the nation's hair palette. Its asymmetry is what makes facing readable.
- **Nose** is a small wedge at the front. Deliberately exaggerated: from overhead it is the
  only reliable cue for which way someone is about to kick.
- **Boots** are two dots that scissor with speed, so a sprinting player reads as sprinting.

`Appearance` is derived deterministically from `(nation, seed)`, so two players in the same
nation's palette still get different hair and skin — they look like two people, not one sprite
drawn twice.

## 4. The ball

Classic white with black pentagon patches, ~22 cm across on an 11 m pitch, which is small. It
gets a hard drop shadow offset a few points and a short motion-scuff trail when travelling
fast, which is what actually makes it findable in a scrap.

## 5. Colour and state

| Element | Treatment |
|---|---|
| Live player | Full saturation |
| Own player | Thin bright outline ring — always findable, never flashy |
| Charging kick | Power ring fills around the kick button, and a short aim line at the player's feet |
| Dashing | Brief speed streaks behind the figure |
| Staggered | Figure desaturates and wobbles for 0.4 s |
| Eliminated | Figure fades out over 0.5 s and is gone; goal arc turns brick-grey |

## 6. HUD

Landscape, so the pitch is a circle in the middle with a margin each side. Along the top: five
chips, one per player, in goal order. Each shows the nation's kit colours
and six pips, filling as they concede. The human's chip is larger and outlined. A chip greys out
and its pips go solid when that player is eliminated. No numbers, no names — colour and pips
carry it, and the eye can read the whole standings in one glance without leaving the ball.

Goal announcements are a single band across the middle for 1.2 s, in the conceding player's
colour: *"CROATIA LETS ONE IN"*. Own goals get their own line.

## 7. Typography

One typeface, the system rounded face, used at three sizes only. Menus are large and quiet;
the HUD is small and never competes with the pitch. No drop shadows on text, no outlines, no
skeuomorphic chrome.

## 8. The 20 kits

Brazil · Argentina · France · Germany · Spain · Italy · England · Portugal · Netherlands ·
Belgium · Croatia · Uruguay · Mexico · USA · Japan · Morocco · Senegal · Serbia · Poland ·
Denmark

Each entry holds shirt primary, shirt secondary, pattern, shorts, socks, a skin-tone range and a
hair palette. Colours are the recognisable national ones, not licensed kit reproductions.
Because several nations sit in the same red or white family, the bot dealer re-rolls any pairing
whose shirts are too close in hue to tell apart mid-scrap — distinguishability is a gameplay
requirement, not a nicety.
