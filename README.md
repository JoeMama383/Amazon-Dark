# AmazonDark v6.0.108

## v6.0.108 — true first-frame Heart + exact two-cards visual size

- Production base: v6.0.107.
- v6.0.107 fixed the transparent Heart backdrop, but the first-frame race remained: some rows briefly expose only a tiny transient child before Amazon mounts the final `lists-framework-action-button`, creating the visible white dot before the Heart appears.
- v6.0.108 moves visual ownership to the stable `[class*=puis-heart-position]` shell, which necessarily exists before that transient child can paint.
- The shell receives one self-contained 32x32 SVG containing the `#181a1b` disc, 1.5px translucent-white chrome, and white outline Heart. The control therefore has no dependency on Amazon's lazy Heart bitmap/SVG for its first visible frame.
- Every Amazon descendant inside that tiny Heart shell is kept at `opacity:0`; the real button remains in the DOM and remains tappable, but placeholder -> hydrated artwork swaps can no longer create a second visual cycle.
- The Heart's visual circle is now exactly 32x32, matching the More-like-this two-cards control instead of the 35x35 Heart host measured by the v6.0.106 device probe.
- The identical rule is present in both the earliest documentStart sheet and `ADFixesLiteral`, so Dark Reader cannot introduce a later paint handoff.
- v6.0.104 two-cards behavior and the v6.0.107 opaque-backdrop correction are otherwise unchanged.
- No new observer, selector traversal, timer, scroll listener, RAF, `dispatch_after`, or image sampler.
