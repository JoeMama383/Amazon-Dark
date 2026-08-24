# AmazonDark v7.0.50~probe

Built from the current v7.0.49 functional state. v7.0.49 itself was built on v7.0.46 (`a6a6d86`), so this source retains the v7.0.46 border/standalone-ad work and the v7.0.49 unscoped chevron fallback while replacing the two behaviors under test below.

## Sponsored: Amazon owns the label, AmazonDark only owns the glyph

- Removes v7.0.49's fixed `#e8e6e3` Sponsored-label paint.
- The standalone short/wide ad text rule now explicitly excludes Sponsored/ad-feedback label families and their descendants, so it cannot recolor the label indirectly.
- AmazonDark reads the real label's **computed color** and applies that result only to the adjacent stock info glyph.
- Existing CSS-mask and SVG/currentColor glyphs receive the exact computed label color.
- Background-image `ad-feedback-spr` sprites are converted in place to a mask using their own image/position/size/repeat, then filled with the exact computed label color. Geometry and the stock glyph artwork stay in place; the Sponsored text itself is never written.
- Initial/pageshow Sponsor discovery is bounded to 64 matching labels. Lazy/recycled ad coverage piggybacks on normal load events and a local ancestor search. No MutationObserver, scroll listener, interval or RAF is added.

## Chevron tap probe

The v7.0.49 unscoped `a-icon-dropdown` / chevron paint remains present so the probe observes the exact currently failing behavior rather than changing the target again.

- Replaces the v7.0.46 palette probe with a manual two-stage `SIGUSR2` chevron probe.
- First `SIGUSR2`: arms exactly one interaction in every mounted frame.
- Tap the still-dark chevron as the **first touch after arming**.
- The probe captures the target's DOM ancestry, composed event path, outerHTML, point stack, computed background/mask/filter/fill/stroke/pseudo paint, plus 0/80/250/650 ms post-tap states.
- At 650 ms it also takes a bounded `elementsFromPoint()` viewport grid so the menu opened by the chevron is recorded while it is still visible.
- Child/ad frames post their one-shot capture to the top frame; if a child-frame tap opens a parent-frame menu, the top frame also records a 650 ms grid.
- Native UIKit touch ancestry is captured from the same touch. A bounded visible UIKit snapshot runs once at +650 ms, after the menu has opened, so a native chevron/menu can be distinguished from WebKit.
- Second `SIGUSR2`: serializes the cached WebKit + UIKit evidence to `AmazonDark-chevron-tap-probe-7050.txt` in Amazon's Documents sandbox.

## Runtime shape

Normal paint remains observer-free: `MutationObserver=0`, `TreeWalker=0`, web scroll listeners=0, `setInterval=0`, `requestAnimationFrame=0`. The dynamic Sponsored glyph bridge uses three bounded/local `querySelectorAll` call sites. Chevron probe work is dormant until manually armed; its post-tap timeouts and visible-tree/grid capture run only for that one diagnostic interaction.

## Preserved

- v7.0.49 broad/unscoped chevron attempt, for direct before/after probe evidence.
- v7.0.47-v7.0.49 neutral WebKit scrollbar owner (`#6f6f6f` thumb / transparent track).
- v7.0.46 gray border and standalone-ad OLED/background rules.
- v7.0.45 seasonal product-photo plate and search/location chrome corrections.
- v7.0.44 NPACK background-video TWB persistence.
- TWB, 120 Hz, JIT, launch cover, bottom navigation and unrelated static theme behavior.

## Previous v7.0.49 notes

# AmazonDark v7.0.49

Built on v7.0.46 (`a6a6d86`).

### Sponsored glyph: painted again, to sheet ink

v7.0.48 removed the paint on the theory that `color-scheme: dark` would make Amazon render its own dark values for this control. It does not — the glyph went dark again. v7.0.49 therefore painted the glyph and label to `#e8e6e3`. v7.0.50 replaces that fixed pair with label-owned text plus glyph-only dynamic matching.

### Chevrons

v7.0.49 broadened the prior Home-scoped `a-icon-dropdown` rule to an unscoped dropdown/chevron fallback. On-device testing still shows dark chevrons, so v7.0.50 probes the actual tapped painter instead of adding another guessed selector.
