# AmazonDark v7.0.0-invert — experimental

**A deliberate reset. This is not v6.x with fixes; it is a different approach entirely.**

## What was deleted

Everything. Dark Reader and its 346KB payload, White Background Taming, the
symbols/checkbox owners, the contrast walk, the Person raster machinery, the SpringBoard
splash tweak, every probe and every bisect switch.

    src/Tweak.xm     464,383 -> 7,670 bytes
    darkreader.js    346,017 -> removed
    source files     6 -> 1
    native hooks     48 classes / 99 methods -> 3 classes / 4 methods

## Why

v6.0.211 established on device that Dark Reader's MutationObserver was the input
latency: it re-themes every node as it arrives, and Search and PDP hydrate continuously,
so it ran on the main thread through exactly the window where taps queued. Most of the
6.x apparatus existed to correct what that engine got wrong.

This build asks the opposite question: what if nothing analyses anything?

## How it works

One inversion, applied once, by the compositor.

**Web** — a single document-start stylesheet. `html` gets
`filter: invert(1) hue-rotate(180deg)`; `img`, `video`, `canvas`, `picture`, `svg`,
`iframe`, `embed`, `object` and inline `background-image` elements get the same filter
again. A filter on an ancestor composites with one on a descendant, so media returns to
its original colours. `hue-rotate` keeps hues near where they started — a bare invert
turns Amazon's orange blue.

**Native** — one `colorInvert` CAFilter on the window layer, cancelled on
`UIImageView` layers by the same double-inversion. WebKit layers have the filter removed
entirely, since the page already inverts itself.

Cost per node: nothing. No observer, no scan, no timer, no `querySelectorAll`, no
`getComputedStyle`, no `getBoundingClientRect`. Four hooks, each firing once per object.

## Known limits, stated up front

- **CSS-painted imagery** — art painted from a stylesheet class rather than an inline
  `style` attribute has no element a tag selector can reach, and will appear inverted.
  The inline `background-image` case is covered; the stylesheet case is not.
- **Non-UIImageView native drawing** — a custom `-drawRect:`, a `CAGradientLayer`, a
  video layer. Not cancelled, so it will appear inverted.
- **Native hue** — `CAFilter` has no hue-rotate, so native accent colours shift where
  web ones do not.
- **Inverted, not designed.** Colours are the mathematical complement. Photographs are
  correct; everything else is a flip, not a theme.

This is an experiment in cost. Expect it to be fast and visually rough, and judge it on
whether the responsiveness is worth the roughness.

## Verification

- Injected stylesheet tested in jsdom: element injected, root rule first, escaped quotes
  survived, parsed as 4 real CSS rules by the engine, img re-inverted, inline
  background-image re-inverted, nested media neutralised. 7/7.
- Injected JS parses; `scripts/lint-logos.sh`.
