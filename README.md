# AmazonDark v7.0.59

## 1. Sponsored glyph reverting — fixed at the mechanism

The painter reads the label's computed colour and tints the sprite with that exact
value. That part was always right. It reverted because it wrote **inline styles onto a
specific element**, and Amazon re-renders these ad cards after hydration — the
replacement element carries none of them.

v7.0.57 added a settle train, which only moved the deadline. The replacement still wins
whenever it happens after the last pass.

The painter now also emits a **style rule** carrying the same resolved colour. A rule
applies to whatever element matches, including one Amazon substituted a moment ago. It
is emitted once per distinct colour and capped at four, so a page produces one or two
rules total and every later re-render is covered with no further JavaScript and no
observer.

## 2. The probe was capturing the wrong element

Both the v7.0.56 and v7.0.57 chevron captures landed on asin product images. That was a
probe defect, not a mis-tap.

The probe converted the touch to a **fraction of the webview**, then re-multiplied by
`innerWidth`/`innerHeight` inside the page. `evaluateJavaScript` is asynchronous, so any
scroll between the tap and the evaluation left that fraction pointing at whatever had
scrolled under it. Both captures resolved onto product images near the bottom of the
screen, with different scroll offsets in each.

The touch is now converted to an **absolute document coordinate** using the scroll offset
read synchronously at touch time. The JS subtracts the *current* offset, so a scroll
between tap and evaluation cancels out. The old fraction is retained as a fallback for
the case where the element has scrolled entirely off screen.

## 3. Chevrons — still not changed

No blind rule. The existing `a-icon-dropdown` ownership is untouched. With the probe
fixed, one tap on a chevron will identify the leaf.

## Verification

- Emitted glyph rule: parses as 2 real rules, carries the label-resolved colour, lifts
  above the card floor, matches a hashed glyph class, and **still matches after the
  element is replaced** — which is the whole point. 7/7.
- Scroll compensation arithmetic: unchanged with no scroll, follows the element when the
  page scrolls either direction, falls back to the fraction when the element leaves the
  viewport. 4/4.
- Probe format specifiers and arguments: 4 and 4.
- MutationObserver count still 0; balance 0/0/0; `scripts/lint-logos.sh`.
