## v6.0.143 — unsigned Cart credit banner darkening + capture probe

- Starts from v6.0.142.
- Targets the unsigned-cart Amazon Visa promo semantically by the copy `Pay for this order` plus `$50 off` / `upon approval` / `Amazon Visa`; no guessed Amazon class is required.
- Reuses the existing bounded web contrast traversal and existing MutationObserver lifecycle. No additional web observer, interval, RAF loop, or scroll listener is added.
- The positively identified short/wide promo shell is painted with the current dark page background, structural descendants are made transparent, and promo text is lifted to the configured light foreground. Product/card artwork (`img`, `picture`, `svg`, video/canvas) is not recolored.
- Includes a temporary v6.0.143 verification probe. Backgrounding Amazon writes `AmazonDark-cart-credit-probe-6143.txt` and SpringBoard relays it to the normal Shared/AppGroup Documents push folder. The probe records mounted native WKWebView hosts plus DOM/CSS chains around the exact promo copy and whether `data-ad-cartcredit6143` landed.

## v6.0.142 — darker Sign Out surface, native text restored

- Built from v6.0.141 behavior while removing the special Sign Out text-color owner.
- `Sign Out` now leaves its title color entirely to Amazon/the existing foreground pipeline.
- Only the stock `AWButton` background image is recolored, to a darker yellow (`#D4A017`), preserving Amazon's original alpha mask, stretch caps, dimensions, and button geometry.
- `Cancel` is unchanged from v6.0.141: medium gray (`#666666`) stock-image surface with white title text.
- Targeting remains limited to the compact native dialog that contains `Sign Out`, `Cancel`, and `You are signed in as ...`.

# AmazonDark v6.0.138

Corrective build based on the pre-135 dark-background architecture. The failed 135-137 Sponsored/APE experiments are not carried forward.

## Sponsored presentation

Sponsored labels are bridged to the same dark-mode secondary gray (`#b1aaa0`) before the native-ad early-exit, so the native-island and generic-contrast paths no longer disagree. Amazon remains the owner of the info-glyph artwork, size, baseline, spacing, and internal "i". The existing bounded contrast traversal recognizes Sponsored ancestry, protects stock background-image sprites from generic inversion, and only redirects color-driven stock variants (SVG/pseudo/mask/icon-font) from dark/black ink to the same secondary gray. No custom Sponsored SVG, fallback icon, duplicate badge, or Sponsor-specific document scan is present.

## Background preservation

The v6.0.134-137 Sponsor-driven ancestor/standalone shell clearers are not carried forward. The only APE transparency retained is the narrow v6.0.133 probe-derived `ape-wrapper` / `ape-placement` / `ape-feedback` ownership that already existed on the last dark-background baseline. No new broad parent, iframe, card, or page-floor transparency path is added.

# AmazonDark v6.0.131 probe

Built directly from v6.0.128 after the standalone-ad scope/glyph patch produced no visible change.

This is diagnostic-only. Production behavior is intentionally unchanged from v6.0.128. The probe captures the exact live DOM and computed paint ownership for visible `Sponsored` labels, nearby info-glyph candidates, the nearest ad shell, child media/iframes, and active TWB markers when the app backgrounds.

No new MutationObserver, scroll listener, interval, requestAnimationFrame loop, or recurring scan is added. The older component-shell diagnostic hook is replaced with a no-op during mutations; the actual scan runs only when the existing native background exporter asks for a dump.

## Reproduction
1. Open Home and scroll to the standalone horizontal ad with the lighter full-width rectangle.
2. Background Amazon once.
3. Return to Amazon and open a product/search submenu containing the standalone sponsored ad whose photo-only taming is correct.
4. Background Amazon again.
5. On launch the probe first attempts the requested shared Documents path. If iOS rejects that cross-container write, it automatically falls back to Amazon's own Documents directory and records the primary-write error in the file header. Use the one-line NewTerm copy command from ChatGPT to copy the fallback file into the requested shared Documents folder.
