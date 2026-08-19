# AmazonDark v6.0.140 probe

Temporary **Sign Out confirmation dialog probe**, built directly from the stable v6.0.138 behavior. No v6.0.139 button recolor is included. With the Sign Out confirmation visible, background Amazon once. The probe captures the visible UIKit/layer tree plus computed DOM/CSS for `Sign Out`, `Cancel`, and `You are signed in as`, then the SpringBoard companion automatically relays the completed file to:

`/private/var/mobile/Containers/Shared/AppGroup/D846D8DE-EE0F-4B82-9676-C68769E519CD/Documents/AmazonDark-signout-dialog-probe-6140.txt`

No recurring observer, scroll listener, interval, or RAF loop is added.

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
