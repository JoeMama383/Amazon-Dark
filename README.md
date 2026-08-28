# AmazonDark v7.148~search-mute-coupon-fix-probe — Search mute state + coupon chrome

Built directly on the working v7.147 diagnostic build / v7.146 production-performance theming baseline. Existing Search video playback/TWB, More-like-this, Home-ad and diagnostic coverage remain intact.

- Fixes the Search sponsored-video mute control at the WebKit media-control layer. The v7.147 probe proves the visible controls are not DOM descendants of `.sbv-video-overlay`; the video-control tree contains zero button controls. v7.148 gives `VIDEO.sbv-video-player-ecx` one state-specific mute glyph: speaker + waves when unmuted, speaker + X when muted. The stock circular shell and play/pause control remain untouched.
- Normalizes Search coupon-price/highlight chrome to medium gray `#4a4f51` with white text while leaving checkbox/icon leaves alone. Covers the established `s-coupon-component` / `s-coupon-unclipped` / `s-coupon-highlight-color` family plus bounded coupon-price/highlight class variants.
- Retains the full screenshot/SIGUSR2 diagnostic stack. The probe now records VIDEO `muted`, `volume`, `paused`, `controls`, `readyState`, `currentTime`, and computed WebKit media-control pseudo styles, and adds a dedicated coupon inventory.
- The fixes themselves are declarative CSS only: no new MutationObserver, timer, interval, RAF loop, scroll listener, media-event listener or recurring DOM scan.

# AmazonDark v7.147~ui-diagnostics-probe — restored full diagnostics + mute-control subtree

Diagnostic-only build based directly on the known-good v7.146 production compaction. The v7.146 theming/runtime fixes remain intact; the v7.145 screenshot/SIGUSR2 UI probe, cross-frame media bridge, and Privacy diagnostic counters are restored temporarily for debugging.

- Restores screenshot + `SIGUSR2` manual captures and the all-frame Home/Search media bridge.
- Restores the prior native/WebKit/Privacy diagnostic bookkeeping removed from v7.146.
- Adds a dedicated Search-video control inventory that captures every visible button/`role=button`, semantic mute/sound/volume candidate, its full ancestor chain, and a bounded recursive descendant tree including pseudo-element computed styles, icon-font metrics, SVG `viewBox`/`path d`/`use href`, transforms, clipping, outline, text shadow and WebKit text stroke.
- Probe does not read typed query text, element text, outerHTML, clipboard data, request bodies or headers.
- No MutationObserver, interval, RAF loop or scroll listener is added. The expensive DOM/subtree collection runs only on screenshot/SIGUSR2.

# AmazonDark v7.146 — performance compaction

Production compaction built directly from v7.145. Visual and functional fixes are retained, including the Search video/More-like-this repair. Probe-only runtime, dead SpringBoard launch-window code, and Privacy diagnostic bookkeeping were removed. Hot-path constant colors/TWB paint are cached and duplicate UIImageView classification passes are eliminated.

No Dark Reader, MutationObserver, interval, RAF loop, scroll listener, or recurring DOM scanner is added. This production build intentionally ships no manual probe.
