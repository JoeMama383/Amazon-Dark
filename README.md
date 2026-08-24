# AmazonDark v7.0.48

Built on v7.0.46 (`a6a6d86`), carrying v7.0.47.

## Amazon owns the Sponsored control again

v7.0.47 forced `brightness(0) invert(1)` on the glyph and `#e8e6e3` on the label. That
made both pure white, which is not Amazon's colour — it replaced their rendering instead
of revealing it.

The rest of this sheet already carries
`:not([class*=sponsored]):not([class*=ad-feedback]):not([id^=ad-feedback-text-])` guards
on every text rule, for exactly this reason: Amazon owns that control. The document is
already set to `color-scheme: dark`, so Amazon renders its own dark values without help.

What remains is only the two things that made the glyph invisible, neither of which is a
colour:

    opacity / visibility      it was being composited away
    position / z-index        it was sitting under the card floor
    mix-blend-mode: normal    it was multiplying against the OLED floor

No `filter`, no `color`, no `fill`, no `-webkit-text-fill-color`. The forced-white label
rule is deleted outright.

## Unchanged

- Chevron work from v7.0.42–46 — `a-icon-dropdown` still at 6 sites.
- Scrollbar owner from v7.0.47 — 2 sites.

## Verification

- The remaining glyph rule contains no `filter`, `color`, `fill` or
  `-webkit-text-fill-color` property, checked directly against the emitted rule text.
- Forced-white label rule confirmed absent.
- Balance 0/0/0; `scripts/lint-logos.sh`.
