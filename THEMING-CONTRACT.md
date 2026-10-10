# AmazonDark — OLED text and floor invariant

This is a release-blocking contract for all future native and WebKit menu work.

1. Neutral black or near-black text rendered on OLED black floors MUST become legible white (`#fff` or existing `ADLightText706`); an existing readable muted-secondary gray may remain, never a near-black gray.
2. Neutral floor/card/button/sheet surfaces MUST be OLED `#000`. Do not substitute gray floor fills. Authored teal/blue/semantic content, progress states, radios, stars, Prime and links retain their original dynamic colors.
3. Gray is used for existing borders, dividers, and appropriate secondary copy. Preserve all layout geometry and border widths; do not add duplicate synthetic borders.
4. All authored image content must remain visible; image taming uses the existing configurable TWB path, never hardcoded factors or forced cropping.
5. **React text rule:** test both the initial text-storage commit and the on-window/final-draw path. If a text leaf can commit before mounting, verify its final text color after mounting. Idempotent bounded corrections only; no recurring DOM/UIView sweeps.
6. A probe demonstrates a problem only if its captured foreground scene includes that menu. Report mismatched foreground captures rather than treating them as proof.
7. Never claim a UI fix is verified solely because a selector exists, lint passes, or source bytes are preserved; distinguish CI compilation and on-device visual validation.

v7.624 root cause: the native Alexa plus sheet's `RCTTextView` title had dark authored foreground and the v7.622 text conversion ran only at an initial React storage commit, often before `.window` existed. The `didMoveToWindow` and `drawRect:` owner is now protected by tests.
