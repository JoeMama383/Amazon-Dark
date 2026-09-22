# AmazonDark v7.448 — performance consolidation

Direct parent: **v7.447~probe-responsiveness**. This is a dedicated performance pass. It does not intentionally change the accepted visual theme, preference behavior, FULL/VIEWPORT/TRANSITION capture contract, or the v7.447 plain-TAR export workflow.

## Production runtime changes

- Compacts only the later/post-v7.388 CSS additions where a shorthand declaration already makes an immediately repeated longhand declaration redundant. The legacy v7.386/v7.387 semantic-golden programs are left structurally intact and remain regression-checked.
- Makes forced PDP child-frame delivery idempotent per document and per white-tame strength. Repeated lifecycle/frame events now return immediately when the same owner program is already installed.
- Caches the strength-dependent forced-frame JavaScript instead of rebuilding the large program on every frame-owner delivery.
- Gates the main-document frame-owner trigger on an actual `#dp` root, so ordinary Home/Search/Cart/etc. documents do not traverse their iframe tree for PDP ownership.
- Removes the ineffective early `document-start` frame-tree ping while retaining DOM-ready, iframe-load, one gated `window.load`, and `pageshow` coverage.
- Caches `WKContentWorld.pageWorld` with `dispatch_once`. The WebKit message handler deliberately keeps the v7.447 defensive remove/re-add behavior so Amazon-side handler removal cannot strand the frame owner.

## Explicit probe efficiency

Large native diagnostic breadth-first walks now use cursor queues instead of repeatedly removing index zero from mutable arrays. This removes avoidable array shifting during FULL/VIEWPORT/transition/launch diagnostics. Probe traversal remains opt-in, finite, bounded, and separate from normal app browsing.

## Static payload comparison vs v7.447

- `src/Tweak.xm`: **861,712 → 853,010 bytes** (-8,702 / -1.01%).
- Core document-start Web program: **208,738 → 205,874 bytes** (-2,864 / -1.37%).
- Checkout floor program: **69,983 → 63,571 bytes** (-6,412 / -9.16%).
- Default installed Web payload: **280,135 → 270,859 bytes** (-9,276 / -3.31%).
- All-feature Web payload: **313,468 → 304,192 bytes** (-9,276 / -2.96%).

These are static program-size/runtime-architecture measurements, not a claim of measured device FPS, launch time, energy use, or battery improvement. On-device performance still requires device timing if we want quantitative real-world numbers.

## Performance invariants

Normal production theming still has no `MutationObserver`, Web scroll listener, `setInterval`, `requestAnimationFrame` loop, `TreeWalker`, polling loop, or recurring hierarchy scanner. Expensive FULL/VIEWPORT traversal remains manual/armed and bounded.

See `AUDIT-v7.448.md`, `VALIDATION-v7.448.md`, and `COMMANDS.md`.
