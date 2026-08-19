# AmazonDark v6.0.132

Production build. Restores the ad-frame classification the 5.x → 6.x rewrite dropped,
narrows White Background Taming so it can no longer claim a whole sponsored ad shell,
makes the Sponsored info glyph deterministic, and repairs the diagnostic exporter so
it can actually write a file.

## Changes

**Ad-frame mode is published again.** v5.446 set `__ADFRAME_MODE__` inside every ad
frame and left it undefined in the main document. Two main-document-only guards
(`__AD_HEARTSHELL427__`, `stockCheckbox434`) still test it, but 6.x dropped the
assignment, so both guards passed inside every ad iframe and ran search/product
control work in documents that contain no such controls.

**Taming no longer swallows the ad.** In a frame carrying its own `Sponsored` copy,
`paintBg()` now refuses any plane that covers essentially the whole frame, and the
full-frame rejection that already governed `productad`/`standalone` extends to
`hero`. Home standalone ads therefore get the same photo-only treatment the
product-page ads already got; a Home hero creative with no `Sponsored` copy is
unaffected.

**Sponsored info glyph is owned outright.** Three rules were previously fighting over
it: `invert(1)` on the sprite, `fill:#ffffff` on every descendant path, and a blanket
descendant `background-color:transparent`. Against sprite artwork that yields an
inverted two-tone badge; against SVG artwork the forced fill floods the counter-form
of the "i" and the blanket transparent erases the disc — the observed alternation
between a white circle and a dark circle with a white "i". The glyph now uses its own
artwork (white disc, dark "i"), the same technique v6.0.103 uses for
`mlt-icon-container`, so Amazon's variant no longer matters.

**Probe exporter fixed.** v6.0.129 wrote to `NSTemporaryDirectory()` and v6.0.130
wrote straight to the NewTerm push folder. Neither file appeared: the write is
attempted from inside Amazon, whose sandbox has no access to another app's App Group
container, and every write is wrapped in `@try` with `error:nil`, so the denial was
silent. The destination is now resolved once by really writing a test file to each
candidate, so it cannot fail silently, and the chosen path is recorded in the file's
own header.

## Runtime cost

No new MutationObserver, scroll listener, interval, `requestAnimationFrame` loop, or
recurring scan. `SPON()` reads `document.body.textContent` at most once per frame and
caches the result; `textContent` does not force layout the way `innerText` would.

## Dead and duplicated code removed (v6.0.132)

Four stylesheet blocks were maintained as two hand-kept copies each — one in the
documentStart floor sheet, one in the Dark Reader fixes sheet. Two copies is
deliberate: the same paint has to exist before and after Dark Reader runs. Two
*editable* copies is not, and is how they drift. They are now single `#define`
blocks with two use sites, and the emitted payloads are byte-identical to v6.0.131
(`ADFixesLiteral` unchanged at 19,528 bytes, `ADDarkReaderBootstrap` unchanged apart
from the deletion below).

`__AD_FLASH_TOUCH6101__` was reduced to an empty stub in v6.0.129, but both the stub
and its guarded call in the mutation-observer path were left behind. Both are gone,
which takes a per-added-node property lookup off the mutation path.

`src/Tweak.xm` is 383,504 → 378,345 bytes. No unreferenced static functions remain.

## Verification

- All six injected JS payloads extract and pass `node --check`.
- jsdom behavioural test: 11/11 checks over main document, Home sponsored frame,
  Home hero frame, and product-page ad frame.
- clang `-fsyntax-only` harness over the changed ObjC glue.
- String/comment-aware whole-file brace, paren and bracket balance scan.
- `scripts/lint-logos.sh`.

## If the ad rectangle persists

Reproduce both interfaces in one launch, backgrounding Amazon once after each, then
read the header of `AmazonDark-standalone-ad-probe-6131.txt` — it names the directory
it resolved to. The dump records which element owns each `Sponsored` label, which
nodes carry `data-ad-twb6033` / `data-ad-twb-bg6033`, and the surrounding wrapper and
iframe chains.
