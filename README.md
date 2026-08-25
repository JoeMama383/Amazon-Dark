# AmazonDark v7.89~probe — restored proven manual probe I/O

- Directly based on v7.88~probe; production theming behavior is unchanged.
- Keeps the manual SIGUSR2 one-shot trigger.
- Restores the proven probe I/O model: Amazon writes inside its own sandbox Documents directory; NewTerm finds that file and copies it to the shared AppGroup Documents folder.
- Removes the invalid v7.88 behavior that tried to write directly from the sandboxed Amazon process into NewTerm's shared AppGroup path.
- Viewport capture remains fixed-current-frame only: no auto-scroll, no auto-tap, no MutationObserver, no recurring timer.
- Two identical runs are intended: GOOD carousel state, then BAD carousel state.

# AmazonDark v7.88~probe — manual viewport snapshot

- Direct base: v7.87~probe, with **no production theming changes**.
- Replaces the unreliable screenshot-notification trigger with an explicit one-shot **SIGUSR2** trigger.
- The capture remains viewport-only: no scrolling, no tapping, no MutationObserver, no recurring timer/RAF, and no whole-document `querySelectorAll("*")`.
- Run the exact same trigger twice: once after leaving the good carousel state on screen, then again after leaving the bad state on screen.
- Captures Sponsored text/glyph paint plus local chevron/SVG/path/pseudo-element state inside card/header roots found in the current viewport.
- Output appends to `AmazonDark-v7.88-viewport-probe.txt` in the shared AppGroup Documents folder.

# AmazonDark v7.86 — isolate Hybrid carousel Sponsor glyph color

- Built from clean v7.83 production. The v7.84/v7.85 standalone-ad probe/overrides are not carried forward.
- Root cause of the carousel inconsistency: the legacy `ADSPG7070` learner emits a literal color into a CSS selector built from Amazon's shared hashed Sponsor-glyph classes. Multiple sibling carousel cards reuse those same classes, so whichever card is sampled during hydration can overwrite the glyph color for another card; refresh changes the sampling/order and makes the bug appear random.
- v7.86 prevents that learner from owning Hybrid `ad-feedback-sprite-mobile` glyphs. Those glyphs are now handled entirely by a declarative direct-family rule that converts the stock info PNG to a mask and paints it with `currentColor`, inherited from that glyph's own adjacent Amazon-owned Sponsored label.
- Sponsored text is never recolored. No standalone-ad work or standalone-ad probe ships in this build.
- No MutationObserver, timer, interval, RAF, or web scroll listener is added.

# AmazonDark v7.83 — Sponsor glyph inherits Amazon label color

- Built directly from v7.82 production, preserving the v7.0.79 white-scrollbar baseline and the v7.82 deterministic Hybrid Sponsor-glyph ownership.
- v7.82 correctly prevented late hydration from making Hybrid Sponsor glyphs dark, but hard-coded every captured Hybrid glyph to `#e8e6e3`.
- v7.83 keeps the same high-specificity glyph-only selector and changes its paint to `color: inherit` + `background-color: currentColor`, so each masked info glyph follows the adjacent Amazon-owned Sponsored label whether Amazon renders that label gray or white.
- Sponsored text is never recolored. No MutationObserver, timer, interval, RAF, web scroll listener, or probe runtime is added.

# AmazonDark v7.82 — deterministic Hybrid Sponsored glyph paint

- Built from the v7.0.79 production/scrollbar baseline through the v7.81 inventory probe.
- v7.81 proved the intermittent dark Sponsor glyph is Amazon's Hybrid NPACK/GWM `ad-feedback-sprite-mobile` renderer: the visible text is Amazon-owned, while the masked 12x12 glyph can hydrate to `rgb(17,17,17)`.
- Adds one declarative, high-specificity CSS rule anchored to `data-ad-feedback-label-id` so Amazon's late two-class Grey-theme rule cannot win by stylesheet order.
- Paints only the Sponsor glyph light; Sponsored text remains fully Amazon-owned.
- Removes the v7.81 screenshot probe/runtime. No MutationObserver, timer, interval, RAF, or web scroll listener.

# AmazonDark v7.0.79

- Pre-release refresh: themes Amazon's ad-feedback bottom sheet with cheap documentStart CSS only.
- Feedback sheet structural floor is OLED black; headings/body/labels are light; issue textarea uses the same #303335 gray as the current search field; buttons and checkbox chrome are dark/neutral.
- The sheet rule is scoped to `adFeedbackBottomSheet` / `mobile-ad-feedback-container`; the existing Sponsored-glyph fix is otherwise unchanged.
- No MutationObserver, timer, scroll listener, interval, RAF, or probe runtime is added.

- Built directly from the clean v7.0.70 production source.
- Fixes the remaining Deals-for-you Sponsored info glyph by recognizing Amazon feedback controls exposed as `aria-label="Leave feedback on Sponsored"`, even when their visible label has no `ad-feedback-text` / `sponsored-label` class.
- Reads the exact visible Sponsored text leaf's computed color and applies it only to the adjacent stock info glyph through the existing persistent Amazon-class CSS renderer lock.
- No MutationObserver, retry timer, scroll listener, interval, RAF, or probe runtime. Sponsored text remains Amazon-owned.

# AmazonDark v7.0.70

## v7.0.79 — Sponsor persistence + exact Home spinner center

- Adds a permanent CSS-only paint for late-hydrating NPACK / sponsored-products Sponsored info glyphs so Amazon replacement nodes cannot revert dark after the one-shot Sponsor pass. Sponsored text remains Amazon-owned.
- Fixes the actual Home mosaic load-more spinner identified by the v7.0.78 screenshot probe: its `::after` pseudo-element was the opaque white center disc, so only that center is changed to OLED black while the rotating light ring remains intact.
- Retains the white native scrollbar on the exact `WKScrollView` runtime class and leaves `WKChildScrollView` carousel descendants alone.
- No MutationObserver, timer, interval, RAF, web scroll listener, or probe runtime ships in this production build.

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


## v7.0.73 — Sponsored feedback focus-ring cleanup

Amazon's ad-feedback text control applies its own rounded focus outline. After closing the feedback sheet, that control can remain focused, leaving a gray box around `Sponsored`. v7.0.73 suppresses only the focus outline/box-shadow/tap highlight for Sponsored/ad-feedback trigger families. Sponsored text and glyph color ownership from v7.0.72 is unchanged. No observer, timer, scan, scroll hook, interval, or RAF was added.
