# AmazonDark v7.478 validation

Package: `7.479~timer-actionbar-edge`

Direct source parent: `AmazonDark-v7.477-pdp-ad-ui-repair-source.zip`.

## Six supplied issues and evidence

1. **Home Buy Again white pills** — v7.477 VIEWPORT identifies the repeated white owner as `button[data-csa-c-painter="Buy-Again-Rufus-Pills-Card"][class*=_pillRow_]`; the inner `_pillText_` is the neutral text owner. v7.478 targets only that family with OLED fill, gray border and white text.
2. **Home countdown number boxes** — v7.477 VIEWPORT identifies the three white chips as `#atf-countdownCard-Text-Timer-Numeric-1/2/3` with a `_Timer-Numeric__` class. v7.478 targets that exact class fragment so `Numeric-Bottom` hr/min/sec labels remain outside the rule.
3. **Home Prime billboard raster** — v7.477 VIEWPORT identifies a bare `img` under `_billboard-card_regularStyle_gwm-BillboardCard...`, outside the prior TWB selector. v7.478 adds that exact billboard family to the existing preference-controlled `whiteTame` brightness path and keeps its cropped wrapper OLED.
4. **PDP Top tab mismatch** — FULL records the outer `#btfSubNavTopTab` at the same 52 pt row height and 16/20 typography context as the sticky navigation, while the visible label is an inner `span.a-size-mini` at 12/16 below `i.a-icon-section-collapse`. v7.478 removes v7.477's outer-anchor computed-style copier and normalizes only that unique inner two-row structure.
5. **PDP 402x125 blank medium ad** — FULL/cross-frame evidence shows `#sp_hqp_phoneapp_shared_inner` is an absolute `z-index:100` overlay, while the product image/title/rating/price are sibling nodes underneath it. The v7.477 opaque black background therefore covered valid content. v7.478 retains the outer OLED card and changes only that overlay to transparent.
6. **PDP long white bottom line** — native FULL identifies the remaining line as the horizontal `_UIScrollViewScrollIndicator` inside the root `WKScrollView` (about 325x3 pt), not `ANXTabBarView`. v7.478 disables only the root WKScrollView horizontal indicator and retains vertical white-indicator behavior.

## Static / regression validation

- `scripts/lint-logos.sh`: **PASS**.
- `sh -n scripts/ui-probe.sh`, `scripts/skeleton-probe.sh`, and `scripts/validate.sh`: **PASS**.
- Changed `ADPDPProbeBackedFixesJS7458` payload parsed with `node --check`: **PASS**.
- Changed `ADPDPGridCarouselFix7454` payload parsed with `node --check`: **PASS**.
- `src/Tweak.xm`: **855,722 bytes**, below the **856,000-byte** performance/source gate.
- Historical/current Python regression corpus: **155/155 PASS** using the same current-version normalization performed by `scripts/validate.sh`. The corpus was executed in bounded batches because the monolithic runner exceeds this environment's command wall-time; no test was skipped.
- New `test_v7478_home_pdp_six_fix.py`: **PASS**, statically asserting all six exact owners plus the no-recurring-traversal architecture.
- Updated historical v7.471/v7.473 ad assertions reflect the intentional v7.478 correction: the z-index overlay must now be transparent rather than black.

## Runtime boundary

This is not labeled device-confirmed before installation. The fixes are probe-backed and statically validated, but the final visual/compositor result must be verified with fresh v7.478 FULL/VIEWPORT captures on device. TRANSITION remains independently version-bumped and available for regression checking.
