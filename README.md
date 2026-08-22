# AmazonDark v6.0.200~probe — Dark Reader cooperation / input-latency pass

## Goal

Start from the exact v6.0.185~probe visual baseline, stop competing with Dark Reader for generic web theming, and remove avoidable main-thread repair work without replacing the established look.

## v6.0.200 changes

- **Dark Reader owns the normal WebKit page floor again.** The old `ADPreDarken()` html/body painter is removed and `adfloor612` no longer forces `html`, `body`, `#a-page`, `#gwm-PageContent`, or `main` dark. The native WKWebView/WKContentView backing remains dark only to prevent literal unpainted tile flashes during fast scrolls.
- **The broad AmazonDark fallback contrast/background engine is removed.** No 1400/360/120-node TreeWalker, no full-root computed-style repair, no search escalation, no detach/reattach WeakMap cache, no idle repair queue, and no dedicated fallback MutationObserver remain.
- **Dark Reader stays fully dynamic.** `disableStyleSheetsProxy` remains `false`, so late Amazon styles/components can still be themed by Dark Reader rather than being frozen or replaced by an AmazonDark floor engine.
- **Dark Reader work that AmazonDark does not need is reduced.** Image analysis remains globally ignored, the custom-element registry proxy is disabled for this probe, and the existing inline-style exclusions are consolidated into fewer selector matches. Known AmazonDark-owned symbol controls are also excluded from Dark Reader inline-style churn.
- **Known visuals stay declarative.** The existing v185 direct CSS for light text/glyphs, neutral gray borders, product/card first-paint fixes, auth/variation/coupon surfaces, custom symbols, ad protection, and TWB is retained.
- **TWB now treats ordinary images as a universal leaf policy instead of a page-by-page policy.** Every normal WebKit `IMG` is tamed by one cheap CSS rule immediately, with explicit logo/icon/avatar/sprite exclusions; the old product/search/PDP/Home IMG selector list, IMG load callback, and initial IMG scan are gone. Native `UIImageView` photos use a cheap raster-metadata fast path before any semantic section walk or 12x12 luminance sampling. Small/ambiguous image assets still fall through to the existing v185 semantic rules, so special glyph/ad-card behavior is preserved rather than flattened.
- **Seasonal Home theming is declarative-only.** The duplicate runtime seasonal geometry/computed-style scanner is removed because the same exact `hp-mosaic`/widget selectors are already present in document-start and Dark Reader override CSS.
- **The v6.0.184 Interests caught-up gradient exception is retained as a tiny semantic bridge.** It only does local geometry/computed-style work after a small newly-added subtree contains the exact “You're all caught up!” phrase.
- **Warm lifecycle reapply is constant-time.** If `style.darkreader` still exists, appearance/BFCache/visibility recovery returns `warm`; it does not launch a document repair pass.

## Performance mechanism delta vs v6.0.185

- `new MutationObserver(`: **3 → 2**
- `createTreeWalker(`: **1 → 0**
- `getComputedStyle(` textual call sites: **31 → 15**
- `new WeakMap(`: **4 → 0**
- `querySelectorAll(` textual call sites: **33 → 30**
- `setTimeout(` textual call sites: **17 → 14**
- `requestIdleCallback` textual references: **4 → 2**
- web scroll listeners: **0 → 0**
- `setInterval(`: **0 → 0**
- `requestAnimationFrame(`: **0 → 0**
- `src/Tweak.xm`: about **464 KB → 415 KB**

## What this probe is testing

The intended A/B is simple: preserve v185's appearance as closely as possible while reducing touch/scroll latency during Amazon hydration. If a visual regression appears, it should identify a specific element that truly depended on the removed generic fallback; that element can then receive a cheap direct CSS owner instead of restoring the broad scanner.

---

# AmazonDark v6.0.185~probe — Buy Again nav re-entry border persistence

## v6.0.185 correction

- Keeps the v6.0.184 Interests caught-up gradient fix unchanged.
- Keeps the working v6.0.180 Buy Again TWB correction unchanged.
- Keeps the v6.0.183 whole-carousel gray border ownership and v6.0.184 detached-outline reattachment.
- Fixes the remaining bottom-nav re-entry case: v6.0.184 cleared Buy Again ownership when the Person React tree temporarily moved off-window. Because AmazonDark had already suppressed the original 51x51 white raster plate, returning to Person could leave the cards borderless.
- A claimed Buy Again card now preserves its association while temporarily detached.
- CALayer setContents suppression is active only while the claimed card is mounted and still resolves inside Buy Again; detached/recycled hosts may receive Amazon content normally.
- The existing current-controller viewDidAppear sweep now reasserts only already-owned or exact 51x51-style Buy Again card candidates, so a Person tree that remained mounted but had its sublayers rebuilt also recovers on tab return.
- No new observer, scroll listener, interval, RAF loop, nav-bar hook, or recurring recovery lane.
- Existing `AmazonDark-buyagain-probe-6180.txt` remains available; CARD records now include `window=` and `hidden=` alongside `marked`, `outline`, and `attached`.
