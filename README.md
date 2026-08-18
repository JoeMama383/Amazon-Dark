# AmazonDark v6.0.116

## v6.0.116 — restore v5.446 Search glyph ownership

- Exact production base: v6.0.103. No v6.0.104-v6.0.115 symbol/menu experiments are stacked into this tree.
- Removes the v6.0.87 clock/X rule that painted the Search suggestion glyph host itself light. That rule is the source of the visible white square behind the black clock/X on the current Search pane.
- Restores the exact v5.446 Search/nav bitmap backdrop rule in both the earliest documentStart sheet and the post-DarkReader fixes sheet: real IMG chrome keeps a transparent surround, while the existing generic glyph pipeline owns the actual monochrome ink.
- There is no Search-specific JavaScript renderer detector, no Search mutation scan, and no new glyph owner. The working v5.446 separation between transparent icon backdrop and generic mechanism-aware glyph repair is restored instead.
- v6.0.103 two-cards first-paint behavior, Heart behavior, checkbox/Compare, carousel dot, product-image protections, TWB, video, voice, 120 Hz, JIT, top chrome, and SpringBoard source are otherwise unchanged.
- No new MutationObserver, scroll listener, interval, RAF loop, timeout, dispatch, querySelectorAll call, native hierarchy walk, or image sampler is added.
