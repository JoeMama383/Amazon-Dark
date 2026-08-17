# AmazonDark v6.0.101

## v6.0.101 — stabilize search deal hue + swatch rings, with targeted proof probe

- Keeps the v6.0.100 exact inner swatch-shell fix that removed the full-width white variation/swatch rectangles.
- Fixes the remaining circular flash: `.s-color-swatch-outer-circle` retained Amazon's stock light border until Dark Reader recolored it. v6.0.101 pre-owns only border/outline colors, with separate selected and unselected dark-theme values; `.s-color-swatch-inner-circle-fill` remains untouched.
- Fixes the `Limited time deal` hue flash. The old documentStart owner painted Amazon's raw `#cc0c39`, which is visibly lighter than the settled Dark Reader result. v6.0.101 uses the settled dark-theme red `#a50b31` at first paint and repeats that value in Dark Reader's authoritative fixes CSS.
- Probe 6101 ships in the same build and reuses the existing lazy-content observer. It now records border/outline/background/filter/color data and targets deal-label nodes too.
- No new MutationObserver, scroll listener, interval, RAF, or steady-state traversal is added.
