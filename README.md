# AmazonDark v7.114 — standalone store-image TWB parity

Production build based directly on the device-confirmed v7.113/v7.112 visual code. Existing captures already identify the standalone store/brand image precisely: the raster lives under `data-acei-id="brnd-logo"`, with the 414x125 renderer also exposing a `data-testid="logo"` wrapper and an `img[alt="Brand logo"]` leaf. v7.114 adds that exact identity raster to the same TWB brightness factor already used for standalone product imagery, in both the document-start TWB sheet and the constructable/adopted standalone survivor sheet. This covers the known compact, medium, large/dynamic, and first-party standalone renderer variants without reopening the generic logo/icon lane.

Prime blue, orange rating stars, red deal/coupon accents, Sponsored text/glyphs, ordinary page/store logos, badges, UI icons, geometry, borders, and the successful compact 320x50 fixes remain unchanged. The v7.113 compact diagnostic WKUserScript, SIGUSR2 handler, background observer/task, and probe file writer are removed from this production cut; no probe ships in v7.114. No MutationObserver, `querySelectorAll`, TreeWalker, web scroll listener, interval, RAF loop, or timeout is added.

---

# AmazonDark v7.113~probe — reliable background compact-ad capture

Built directly from v7.112~probe with the **visual/theming code unchanged**. The compact standalone parent-owned APE border and exact `lfstyl-img` / `prod-img` TWB selectors are preserved byte-for-byte. The only runtime change is probe delivery: backgrounding Amazon once now starts a short iOS background task, captures the currently visible WebKit frame, waits for the existing 450 ms child-frame replies, writes `AmazonDark-v7.113-compact-standalone-probe.txt`, then ends the background task. Manual SIGUSR2 remains as a fallback. No MutationObserver, querySelectorAll scan, TreeWalker, scroll listener, interval, RAF loop, or recurring timer is added.

# AmazonDark v7.112~probe — compact standalone parent-border + live media-host repair

This build is based directly on v7.111~probe and changes only the two compact standalone failures proven by the v7.111 SIGUSR2 capture.

- **Border:** removes the child `#ad::after` ring. The compact main-frame `.ape-placement` already owns the correct 1 px rounded border geometry, so v7.112 only recolors that existing transparent border to `#3b4043` when its wrapper is `--ad-height:50` and the placement is `aspect-ratio: 320 / 50`. The separate Sponsored feedback row stays outside the border.
- **TWB:** the live compact raster is under `data-acei-id="lfstyl-img"`, not only `prod-img`. v7.112 tames the media leaves under either known compact host, scoped behind `#ad:has(#dynamic-bb)`, in both the first-paint TWB sheet and constructable standalone survivor sheet.
- Existing compact OLED floor, transparent Limited-time-deal plate, medium/large standalone treatment, 300x250 standalone carousel treatment, third-party display/video TWB, Prime blue, rating-star orange, deal accents, and Sponsored paint remain unchanged.

The manual SIGUSR2 probe remains available as `AmazonDark-v7.112-compact-standalone-probe.txt`. No recurring observer, querySelectorAll scan, TreeWalker, scroll listener, interval, RAF loop, or timer is added.

---

# AmazonDark v7.110~probe — compact standalone geometry + floor parity

Built directly from v7.109~probe using the two manual current-frame captures made on the visible compact standalone variants.

The dark 394x62 `#dynamic-bb` creative is already OLED and TWB-tamed, but v7.109 moved its gray outline to the taller main-frame APE wrapper. That wrapper also contains Amazon's separate Sponsored feedback row, so the outline now incorrectly extends below Sponsored. v7.110 removes that wrapper outline and draws the established 1px `#3b4043` / 8px-radius outline as a zero-layout `::after` overlay on the exact `--ad-height:50` `.ape-placement`. The placement is the creative-height owner above `.ape-feedback`, so the bottom edge stays above Sponsored while remaining in the main frame where the child iframe cannot clip it.

The same `#dynamic-bb` capture also exposes the remaining white `Limited time deal` plate: it is a classless direct child of `[data-testid=deal-badge]` with an inline `background-color: rgb(255, 255, 255)`. v7.110 clears only that inline-white plate and leaves the red `% off` badge and red deal text authored.

The separate 430x67 renderer-factory capture proves that `html`, `body`, `#ad`, `renderer-factory-ad-container`, and `main-content` are already OLED. The sole surviving light plane is `[data-testid=content]`, whose inline white background wins because it was not part of the constructable survivor sheet. v7.110 adds that exact structural floor to both the first-paint and adopted standalone sheets, without changing its radius/layout or the already-correct Sponsored/border geometry.

The manual SIGUSR2 probe is retained as `AmazonDark-v7.110-compact-standalone-probe.txt`. All three corrections are declarative CSS only: no MutationObserver, querySelectorAll, TreeWalker, scroll listener, interval, RAF loop, timeout, or recurring probe work is added. Existing compact/medium TWB, 300x250 Swiper carousel treatment, third-party display/video TWB, Prime blue, orange rating stars, deal accents, and Sponsored ink/glyph behavior are preserved.

---

# AmazonDark v7.109~probe — compact standalone full-wrapper border

Built directly from v7.108~probe using the manual current-frame capture made on the visible Hill's Science Diet compact standalone ad. The probe resolves the remaining border defect: the compact creative itself is a 396x62 child iframe, but Amazon renders its `Sponsored` feedback chrome as a separate 398x20 main-frame sibling beneath that iframe. Both live inside the same 398x84.19 `.ape-wrapper` (`--ad-height:50`). The feedback row is already transparent; it was not covering the border. v7.108 simply put the border on the wrong ownership level — the child `#ad` — so the border necessarily ended before the Sponsored row.

v7.109 removes that child-frame border and gives the exact compact main-frame `.mobile-ad-container > .ape-wrapper[style*="--ad-height:50"]` the established 1px `#3b4043` / 8px-radius neutral border. This encloses both the creative and Amazon's Sponsored feedback row without changing either row's ink or adding any runtime DOM work. The compact product-image TWB from v7.108 remains unchanged, as does the exact 300x250 Swiper standalone-carousel repair and the third-party display/video TWB path.

The manual SIGUSR2 probe is retained as `AmazonDark-v7.109-compact-standalone-probe.txt` so the finished wrapper geometry can be verified on-device. No MutationObserver, querySelectorAll, timer, RAF, scroll listener, or recurring probe work is added.

---

# AmazonDark v7.108~probe — compact standalone + exact 300x250 Swiper repair

Built directly from v7.107~probe from the two device captures in the same probe run. For the compact 396x62/320x50 AdaptiveRenderer, the probe identifies the full-size `#ad` + `#dynamic-bb` shell, which is already OLED black but has no border, and `[data-acei-id=prod-img]` as the dedicated product-raster host. v7.108 gives that exact shell the established 1px `#3b4043` / 8px-radius standalone border and applies the existing TWB brightness factor only to its product raster.

The same v7.107 probe also proves why the previous rare `Featured by BEULT` carousel fix missed: this 430x250 child does **not** expose any class or `data-testid` containing `carousel`. Its stable renderer signature is `#ad[data-html-dimensions="300x250"]` with `[data-testid=gridContainer]`, `.swiper-wrapper`, and `.swiper-slide`. The surviving light plane is exactly `gridContainer` (`rgb(255,255,255)`), the active and next slide frames use `border-gray-500`, and both the product image and neighboring custom-image slide expose their raster as `[data-testid=pictureHighQuality]`. v7.108 therefore targets that exact Swiper signature in both the first-paint sheet and the constructable standalone survivor sheet: the grid floor becomes OLED black, slide structure stays transparent, existing slide borders become `#3b4043`, ordinary copy becomes v185 light, Sponsored becomes subdued light gray, and only `pictureHighQuality` rasters receive TWB. Prime/rating-star/badge/deal/glyph paint is explicitly excluded so Prime blue and orange stars remain authored.

The manual SIGUSR2 probe is retained as `AmazonDark-v7.108-compact-standalone-probe.txt` for verification and remains idle until triggered. No MutationObserver, querySelectorAll, timer, RAF, or scroll listener is added.

# AmazonDark v7.107~probe — standalone ad parity + Outlet ink

Built directly from v7.106~probe, retaining the zero-observer/adopted-sheet performance pass and the manual compact-standalone SIGUSR2 probe. The device capture identifies the bright AT&T creative as a nested Flashtalking 300x250 under the exact `#mobile-third-party-ad` host, so v7.107 restores TWB on that one outer third-party creative host rather than reopening the generic standalone-media lane. It also adds a below-fold Home neutral-ink fallback for standard Amazon product-title/price semantics outside the historical card roots. The revised v7.107 additionally covers the rare large first-party standalone sponsored carousel shown as a white `Featured by ...` panel: carousel structural floors become OLED, ordinary carousel copy becomes v185 light, and carousel product media receives the current TWB strength while Prime, rating-star, logo, badge, deal/coupon and Sponsored-feedback accent paint stay Amazon-owned. The same lane is present for both a child safe-frame renderer and the already-known main-document `mobile-mshop-ad` / `mobile-ad-container` form. The manual probe now records carousel/Featured/Prime/rating/star nodes, light planes, and dark-neutral text only when SIGUSR2 is triggered; it remains idle otherwise.

# AmazonDark v7.106~probe — compact standalone capture + zero-observer performance pass

Built directly from v7.105 production. The current standalone child-frame CSS payload is unchanged, but its shell-survival owner now uses `document.adoptedStyleSheets` instead of a direct-child MutationObserver. The legacy semantic Sponsored glyph learner is removed because the currently proven NPACK, Hybrid, product-carousel, and APE families already have deterministic static CSS owners. This probe adds a manual SIGUSR2 snapshot for the still-light compact standalone ad family; it performs no diagnostic traversal until triggered.

# AmazonDark v7.105 — production standalone survivor + transparent deal-message plate

- Production cut of the device-confirmed v7.104 standalone child-shell survival repair; the temporary lifecycle/UCC/SIGUSR2 probe runtime is removed.
- Retains the document-start standalone owner and its single direct-child `documentElement` MutationObserver so Amazon's late HEAD/BODY replacement cannot restore a white standalone card.
- Ports the existing Home `badgeMessage` treatment to the exact standalone Responsive eCommerce host exposed by the v7.104 device capture: `[data-testid="message-container"]` inside `renderer-factory-ad-container` now has a transparent background and no box shadow.
- The new rule does **not** recolor the `% off` badge, `Limited time deal` text, deal/coupon accent colors, product media, borders, geometry, links, or hit targets.
- No probe, recurring timer, RAF, scroll listener, subtree observer, or DOM scan was added.

# AmazonDark v7.104~probe — survive Amazon child-shell replacement

**Direct lineage:** v7.103~probe, whose production visual base is exact v7.96.

The v7.103 device capture finally identifies the standalone-ad failure precisely. In the visible 414x125 safe-frame, `ad7-static-theme`, `ad7-twb-static`, and `ad7-standalone-7103` are all present at document end / load / pageshow. One millisecond later Amazon removes both `HEAD` and `BODY`, adds replacements, and all three AmazonDark style owners disappear. The renderer then paints its stock inline `background: rgb(255,255,255)` and stock dark navy `rgb(0,0,17)` headline/product text. This exactly explains both symptoms: white cards and apparently missing text on dark cards.

v7.104 replaces the document-end standalone backstop with a document-start **shell-survival owner**. It observes only the direct children of the standalone child document's `HTML` element (`childList:true`, no subtree). If Amazon replaces `HEAD`/`BODY` or removes the owner itself, it immediately reattaches the standalone stylesheet directly to `HTML`. There is no document scan, scroll listener, interval, RAF, timer, or subtree observer.

The surviving stylesheet owns only the already-probed standalone renderer families: OLED floor; existing border color; 414x125 brand/product/price ink; 320x50 product-description/Subscribe & Save ink; large dynamic-product neutral copy; and the exact standalone product-raster TWB lanes at the current user strength. Geometry, padding, radius, flex/grid, positions, links, Prime, stars, colored deal/coupon accents, and outer Sponsored feedback chrome remain untouched.

The v7.104 probe adds the one thing previous probes did not have: the production repair's own bounded state (`installs`, `repairs`, `shells`, event timestamps, final style connectivity, HTML identity, and constructable-stylesheet support) alongside the final computed renderer paint. A successful failing-card capture should show `shells>=1`, `repairs>=1`, `connected=true`, medium layout background `rgb(0,0,0)`, and brand/product text `rgb(232,230,227)`.

---

# AmazonDark v7.96 — Disney hero-style product plates

- Production build based directly on v7.95; no probe runtime ships.
- Keeps the v7.95 Disney / Amazon Shopping Guides visibility fix, then gives its four product-image tiles the same OLED-black contain plate used by the seasonal NPACK hero cards.
- Only the Shopping Guides `_colored-background_` shell changes from Amazon's light `#f7f7f7` plate to OLED black. The product raster, sizing/contain behavior, padding, radius, position, links, labels, and card geometry are untouched.
- TWB continues to act on the actual product raster at the user's selected strength; the new black backdrop itself is never dimmed.
- No MutationObserver, recurring timer, RAF, scroll listener, or probe runtime.

# AmazonDark v7.95 — compact standalone + Disney media repair

- Production build based on v7.93 production plus the v7.94 viewport-probe findings; no probe runtime ships.
- Compact renderer-factory standalone ads keep their stock geometry while the actual responsive layout floor stays OLED black, the existing 1px border becomes `#3b4043`, primary copy becomes `#e8e6e3`, and secondary metadata becomes `#b1aaa0`.
- TWB now reaches the compact renderer's real `data-testid=image` / `data-acei-id=lfstyl-img` raster lane as well as the large dynamic-product lane.
- Standalone APE Sponsored text and info glyph are both fixed at `#b1aaa0`; the legacy glyph learner no longer overwrites the standalone glyph with the black parent control color.
- The Disney / Amazon Shopping Guides quad card keeps its product images visible by neutralizing only Amazon's `darken` / `multiply` blend modes on that renderer; layout and image geometry are untouched.
- No MutationObserver, recurring timer, RAF, scroll listener, or probe runtime.

# AmazonDark v7.93 — standalone dynamic-product ad theming

- Built from v7.91 production; the v7.92 probe runtime does **not** ship.
- Owns the probed standalone APE dynamic-product creative as OLED black while preserving Amazon blue/colored accents and orange rating stars.
- Primary standalone-ad copy uses `#e8e6e3`; secondary review/list-price metadata uses `#b1aaa0`.
- TWB skips generic standalone-child media and dims only the dedicated product-picture raster.
- Standalone APE Sponsored text + info glyph now use the same subdued `#b1aaa0` contrast as the corrected Home carousel Sponsored badges.
- No MutationObserver, recurring timer, RAF, scroll listener, or probe runtime.

# AmazonDark v7.91 — Sponsored gray + functional TWB range

- Home carousel Sponsored text and info glyphs now use the same subdued secondary gray (`#b1aaa0`) instead of pure white.
- Tame Light Backgrounds now maps the full 0–100 slider to an effective dimming range: 10% black-equivalent at 0 through 58% at 100. The toggle is the true off switch.
- The currently loaded web surface refreshes once when the TWB preference changes; native image overlays recalculate through their existing layout hooks.
- The upper TWB bound is slightly darker than v7.90's former 50% maximum.
- No probe ships in v7.91.

# AmazonDark v7.90 — Home carousel Sponsored parity

- Production build based on the v7.89 probe lineage; all temporary viewport-probe runtime has been removed.
- The v7.89 capture resolved the carousel mismatch as separate text-fill and masked-glyph paint lanes inside Amazon's product-carousel Sponsored badge shells.
- Only `[class*=widget-sponsored-badge-container]` / `[class*=asin-sponsored-badge-container]` Sponsored feedback rows are normalized to pure white text and a pure white 12x12 info-mask glyph.
- Covers the observed NPACK, GWM asin-tile, and blended/p13n (`_cXVhZ`) carousel renderer variants without changing Sponsored styling elsewhere.
- No MutationObserver, timer, scroll callback, or new runtime scan is added; the correction is static document-start CSS.
- No probe ships in v7.90.

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