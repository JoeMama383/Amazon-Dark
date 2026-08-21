## v6.0.170~probe — PDP performance / cache-lifecycle timing probe

- Exact functional base: v6.0.169, itself built from v6.0.153.
- No production theming/cache behavior change.
- Records DarkReader.enable duration, fallback FIXCONTRAST duration, idle-queue wait, reapply count, navigation/resource timing, DOM/image/review state.
- Reuses the existing app-background exporter; no new observer, scroll listener, interval, RAF, or steady-state file I/O.
- Output: AmazonDark-pdp-performance-probe-6170.txt after reproducing and backgrounding Amazon once.

## v6.0.169 — preserve Amazon warm WebViews / navigation state

- Built directly from the full v6.0.153 source tree.
- Leaves Amazon's `WKUserContentController removeAllUserScripts` cleanup completely stock instead of synchronously repopulating it during WebView reuse.
- Stops global re-theme passes from evaluating JavaScript in off-window retained/prewarmed WKWebViews.
- Scopes `viewDidAppear` WebView recovery to the newly shown controller tree, so PDP Details/Explore/Reviews hydration does not wake the warm parent Home/Search WebView underneath it.
- Background/prewarm navigation completion no longer runs AmazonDark runtime paint until that WebView is actually mounted.
- Does not clear or replace `NSURLCache`, `WKWebsiteDataStore`, `WKProcessPool`, cookies, back-forward lists, or any Amazon/WebKit cache. No reload is forced.
- v6.0.153 theming, TWB, symbols/checkboxes, Person borders, JIT, 120 Hz, splash, and native color ownership otherwise remain the implementation baseline.

## v6.0.153 — instantaneous bottom-nav selection

The bottom navigation already snapped selected glyphs white, but the touch-down path reused the committed selection cache and immediately queued a correction. On a busy tab transition that correction could run before Amazon flipped its real `selected` bit, briefly repainting the newly tapped glyph blue and making the response feel delayed or inconsistent.

- Adds a transient finger-down owner separate from Amazon's committed selected state.
- On touch-down, the tapped tab branch is painted white immediately while sibling tab branches are painted Amazon blue in the same pass.
- Deferred correction and image/tint catch-up paths now honor the transient state, so they cannot race the new white glyph back to blue before Amazon commits the selection.
- `setSelected:YES` clears transient ownership only after Amazon has caught up; cancelled touches release it and fall back to the normal correction pass.
- Adds a `setHighlighted:YES` fallback for Amazon tab controls that signal press/highlight before a conventional tracking callback.
- No vibration/haptic feedback, timer, RAF loop, scroll listener, or new recurring scheduler is added; this is purely a lower-latency visual state handoff.

## v6.0.152 — Sponsored info-glyph color parity

The Home product-card Sponsored labels were already pinned to AmazonDark's secondary gray (`#b1aaa0`), but several 11/12 px information-badge variants remained dark because v6.0.138 intentionally preserved stock bitmap/background-image glyphs. v6.0.152 closes that gap without widening the Sponsor scan.

- Keeps Sponsored text at the existing `#b1aaa0` secondary gray.
- The known `ad-feedback-spr` first-paint host and the existing semantic `data-ad-sponsorglyph6138` marker now use one canonical 12 px information badge whose outer disc is exactly `#b1aaa0`.
- The existing bounded Sponsored bridge now also replaces positively identified bitmap/background-image badge variants rather than leaving their dark stock pixels untouched; known IMG/vector/mask variants remain geometry-gated to 5–30 px and Sponsor-context-gated.
- No new MutationObserver, timer, RAF loop, scroll listener, or page-wide Sponsor scan is added. The working v6.0.151 Person-border and search-border fixes are unchanged.

## v6.0.151 — single-source Person borders + first-paint suppression

The 6.0.150 result exposed two separate ownership conflicts. **Explore more to shop** was correctly losing its white React-Native raster plate, but our replacement `CALayer.borderColor` was then being re-mapped by the generic border engine to the familiar brown/tan hue. **Redeem Gift Card / Reload Balance** still retained their stock raster border under our gray overlay, producing the doubled/misaligned edge visible when zoomed in.

v6.0.151 makes the probe-proven raster cards use one border source only. Explore, Gift Card, and the compact Your Account chips now suppress the stale host `CALayer.contents` plate and render a single 1pt `#494D4D` `CAShapeLayer` outline. The direct `CALayer` border is kept at zero so the generic border curve cannot recolor it or stack another edge underneath. The `CALayer setContents:` owner also recognizes these semantic/geometry-gated RCT cards on the **first raster assignment**, so the initial white Explore outline should never reach the screen. The working search-bar border owner is unchanged.

## v6.0.150 — finish Person-tab raster borders

Probe 6149 showed that the remaining bright borders were not ordinary `borderColor` values. The visible white outline was baked into React Native `CALayer.contents` on two raster-backed card families: the outer **Explore more to shop** card and the compact **Your Account** carousel buttons. v6.0.150 replaces only those probe-proven raster plates with their existing dark logical fill plus the same 1pt `#494D4D` outline already used by Redeem Gift Card / Reload Balance. The layer-contents hook prevents React Native from repainting the stale white plate after layout. The working search-bar border logic is unchanged. The 6149 diagnostic exporter is removed.

## v6.0.149 — Person-tab border recovery + targeted probe

- Keeps the working v6.0.148 native search-bar border correction unchanged.
- Normalizes React/Fabric line breaks before target matching (for example `Explore\nmore to\nshop`), then retries the Person-tab card claim from the React text view's **layout pass**, after Fabric/Paper hierarchy and geometry have settled. This addresses both likely v6.0.147/148 miss paths: split backing text and a setter firing before the final bordered card existed.
- Once a target card is positively claimed, bright neutral direct `CALayer` borders and `CAShapeLayer` strokes are changed to the same `#494D4D` gray before the existing 1 pt neutral overlay is maintained. Rasterized RN border artwork remains covered by the overlay.
- Includes a temporary native probe for the visible Person-tab lower half. Backgrounding Amazon once writes `AmazonDark-person-border-probe-6149.txt`; the probe records visible React/native classes, frames, text, direct border colors, nested shape-layer strokes, `layer.contents`, and whether the target card was tagged.
- Adds no MutationObserver, scroll listener, interval, RAF loop, or recurring scheduler.

## v6.0.148 — compile fix for Person/search border owner

- Preserves the v6.0.147 visual changes exactly: the bright Person-tab borders around Redeem Gift Card, Reload Balance, and Explore more to shop use the thin neutral gray border, and the native Amazon search field loses its brown/tan border.
- Fixes the Logos/Clang build failure by accepting hooked forward-declared classes at the helper boundary and casting to `UIView *` internally. No border matching, colors, fills, text, icons, spacing, or geometry changed.

## v6.0.147 — normalize Person-card and search-bar borders

- Person tab: changes only the bright outlines around **Redeem Gift Card**, **Reload Balance**, and **Explore more to shop** to the same thin neutral gray (`#494D4D`) sampled from neighboring AmazonDark cards.
- Native search chrome: replaces the remaining brown/tan `SBSearchBar` / `SBSearchField` border with the same neutral gray.
- Leaves fills, text, icons, dimensions, corner geometry, and all v6.0.146 behavior unchanged.

## v6.0.146 — repackage of v6.0.145

No functional changes from v6.0.145. This release exists only to produce a fresh GitHub Actions artifact after the previous artifact was deleted.

## v6.0.145 — eliminate first-paint sign-in footer gradient

- Keeps the successful v6.0.144 `/ap/signin` footer normalization as a hydrated-DOM fallback.
- Adds auth-footer/divider selectors to AmazonDark's existing document-start stylesheet so the stock light gradient/pseudo-element is suppressed before the first visible frame.
- The new first-paint rule is structural and auth-specific (`#auth-footer` / `.auth-footer`); it does not recolor the footer links, copyright copy, sign-in form, or Continue button.
- All v6.0.143 Cart-credit and v6.0.142 native Sign Out/Cancel behavior is preserved.

## v6.0.144 — normalize Amazon sign-in footer strip

- Starts from the confirmed-working v6.0.143 behavior.
- Uses the v6.0.143 capture showing the affected screen is a single top-level `WKWebView` at `/ap/signin`.
- On `/ap/signin` only, the existing bounded contrast traversal recognizes the narrow footer group containing `Conditions of Use`, `Privacy Notice`, and `Help`.
- That positively identified footer shell, its structural descendants, and structural pseudo-elements lose their light/gradient background paint and inherit the configured dark page background. Link colors, copyright text, form fields, the Continue button, and all other sign-in UI are left alone.
- The successful unsigned-Cart Visa banner fix from v6.0.143 is retained.
- The temporary v6.0.143 Cart-credit probe and SpringBoard relay are removed from this production build; no background probe file is generated by v6.0.144.
- No new MutationObserver, scroll listener, interval, RAF loop, or recurring scheduler is introduced.

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
