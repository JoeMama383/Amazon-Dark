# AmazonDark v7.406 audit — restore Sponsored footer below video border

## Direct parent

- `7.405~pdp-completion`
- This is a one-regression correction on the second `c2Itd` Product Search video-ad family.

## Device regression

v7.405 correctly moved the single gray frame to the probe-proven `shortProduct` owner so the frame encloses video + product copy and ends above Amazon's Sponsored footer. However, that rule also set `overflow:hidden` on `shortProduct`. Amazon positions the Sponsored text/info-glyph footer below that owner's visible rectangle, so the footer was clipped even though it remained in the renderer.

## Fix

- Keep the root `c2Itd_container` border at zero.
- Keep the nested `singleAsin` border at zero.
- Keep exactly one `#494d4d` border on `shortProduct`.
- Change only `shortProduct` overflow from `hidden` to `visible`, allowing the authored Sponsored text and info glyph to render below the border.
- Do not force a new display/layout for Sponsored; Amazon keeps ownership and placement.

## Architecture

No MutationObserver, timer, polling loop, RAF, scroll listener, recurring hierarchy scan, new hook, new WKUserScript family, or generic sponsored override is added. FULL, VIEWPORT and transition probe identities are regenerated as v7.406.
