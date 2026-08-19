# AmazonDark v6.0.134

Production build on the v6.0.133 lineage.

## Sponsored labels and info glyphs

Amazon currently ships several different Sponsored templates across Home, Search/product surfaces, NPACK/GWM cards, sponsored-products cards, and APE standalone placements. v6.0.134 gives those paths one visual owner: Sponsored text is pinned to pure white, and the 11/12 px info badge uses one deterministic white-disc/dark-“i” artwork instead of inheriting the source sprite’s gray level.

Known Sponsored/ad-feedback hosts are handled at first paint. A bounded local owner covers classless/lazy variants by starting only from recognized Sponsored/ad-feedback families, finding an exact “Sponsored” / “Sponsored Ad” text leaf, and examining only its small nearby glyph candidates. It runs once on the initial document and then piggybacks on the existing v6.0.15 native-ad child-list observer; no additional observer, timer, scroll listener, interval, or requestAnimationFrame loop is added.

## Standalone Home ad shell

The v6.0.133 probe proved the Home standalone rectangle was not Tame Light Backgrounds. Its APE shell used a lighter structural background than the page floor, and the placement carried a visible border. v6.0.134 keeps the known APE wrapper/placement/feedback shells transparent and adds a bounded structural owner for short, wide Sponsored strips. It clears only plain structural background/border/shadow paint. IMG, VIDEO, CANVAS, SVG, PICTURE, and any node carrying real background artwork are skipped.

This is intended to make the standalone strip expose the same live Home page floor while leaving the actual product/creative image under the existing Tame Light Backgrounds rules.

## Performance / preservation

The v6.0.132 dead `__AD_FLASH_TOUCH6101__` no-op and its per-added-node lookup remain removed. The new Sponsored/shell work reuses the existing native-ad lifecycle instead of adding another scheduling path. Search/chevron/Share, Heart, two-cards, checkbox/Compare, carousel dot, video controls, voice, 120 Hz, JIT, top chrome, and SpringBoard behavior are not intentionally changed.

---

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
