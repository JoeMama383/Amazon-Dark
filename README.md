# AmazonDark v7.0.71~probe

Diagnostic-only build on the exact v7.0.70 source. It adds one touch-began Sponsored glyph point capture. There is no MutationObserver, timer, recurring scan, scroll hook, interval, RAF, or signal/PID workflow. Touch the dark Sponsored info glyph once; the probe writes `AmazonDark-sponsored-point-probe-7071.txt` immediately. Production v7.0.70 theming behavior is otherwise unchanged.

# AmazonDark v7.0.70

## v7.0.70 — complete Sponsored glyph template coverage

- Direct source base: v7.0.69 production.
- Fixes the remaining dark Sponsored info glyph in the Recommended deals / Deals for you sponsored-products-mobile card.
- Historical device evidence shows this template uses a distinct 12x12 background-image glyph class beginning `_sponsored-products-mo`, while the GWM/NPACK badges use other families.
- The v7.0.69 learner only searched `ad-feedback` / `spr` families, so it never learned this renderer and therefore never emitted the persistent CSS rule for it.
- v7.0.70 keeps the existing exact computed-color behavior, but extends only the local glyph lookup around an already-identified Sponsored label to accept the known sponsored-products-mobile family or another 5–36 px nearby background/mask/vector painter.
- Once learned, the rule targets the real Amazon glyph selector, so later hydration/replacement remains matched automatically.
- Sponsored text is never recolored.
- No MutationObserver, retry timer, scroll listener, interval, RAF loop, or page-wide runtime scan is added.

## What five failed chevron builds have actually established

- v7.0.63 removed `brightness(0.5)` from the SVG dimming chains. **Confirmed on device**:
  the v7.0.63 sweep reports `filter=none` where it previously read `brightness(0.5)`.
  That fix landed and the chevrons were still dark.
- v7.0.64 ported the v6.0.185 rule for `.a-icon-next-rounded` /
  `.a-icon-previous-rounded` verbatim. Still dark, so those leaves are not present in
  this Home build either.
- Every rule so far — mine and v6.0.185's — sets `fill`/`color`/`filter` on the **svg
  element**.

The sweep reports `fill=none stroke=none` on those SVGs. That is the *svg's* computed
value. **A `<path>` carrying its own `fill` attribute ignores anything set on its svg
ancestor.** Every rule written to date targets the wrong node, which is consistent with
the chevron staying dark through all of them.

This build paints the path itself:

    [class*=header-icon], [class*=header-icon] path, [class*=header-icon] use,
    [class*=header-link] svg path, [class*=cardui-header] svg path, ...
    {fill:#e8e6e3!important;stroke:#e8e6e3!important;color:#e8e6e3!important;}

Harmless if `header-icon` is not the chevron. Decisive if it is.

## Sweep: outerHTML 220 -> 700 characters

The 220-character cap truncated every capture at `<path d="M7.0422 22C6.83522…` —
exactly before the `fill` attribute. That is why five builds went by without anyone
seeing whether the path carries its own colour. The next capture will show it.

## Honest status

I have made five wrong calls on this chevron and asserted several of them confidently.
The path-vs-svg distinction is the first explanation consistent with *all* the evidence
rather than just the latest capture, but it is still an inference until the widened
capture confirms it.

If the next sweep shows `<path fill="#0F1111"` or similar, this build fixes it. If the
path has no `fill` attribute, then `header-icon` is genuinely not the chevron and the
element is something the sweep has never matched — in which case the probe needs to walk
card-header subtrees by structure rather than by class.

## Verification

- Path-vs-svg tested in a real engine: the svg-level selector does **not** match the
  path, the path-level selector does, and a path with its own `fill` attribute keeps it
  against an svg-level rule. 3/3.
- Balance 0/0/0; `scripts/lint-logos.sh`.
