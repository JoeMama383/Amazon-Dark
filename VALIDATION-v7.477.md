# AmazonDark v7.477 validation — PDP ad/UI regression repair

## Root cause of the v7.476 device regression

The top standalone/offsite ad and the medium standalone ad are different visible creatives, but they share child-frame scaffolding. The v7.473 VIEWPORT proves the working top creative uses a full-frame `#absoluteComponents` overlay (430×74) above the `#offsite-buy-box` content. v7.475/v7.476 incorrectly black-painted `#absoluteComponents` and two descendant wrapper levels while trying to repair the medium card. That broad rule could cover the top creative's authored image/text layer, which is why a change intended for the medium family regressed the top family.

v7.477 removes every `#absoluteComponents` selector from `ADPDPGridCarouselFix7454()`. After deleting the new medium-only addition from the v7.477 block, the remaining function is **byte-for-byte identical to v7.474**, the last device-confirmed top-ad implementation.

## Medium 414×125 family

The historical v7.463 r3 child-frame capture provides an exact successful reference:

- child viewport approximately 400×123
- `[data-testid=renderer-factory-ad-container]`: OLED
- `[data-testid=main-content]`: OLED
- `[data-testid=modern-414x125-layout-container]`: OLED, one 1px `rgb(59,64,67)` (`#3b4043`) rounded border, radius 8
- product image: normal blend with TWB brightness treatment
- neutral title/price copy: light
- Prime/star SVG families: authored semantics retained

v7.477 targets only `modern-414x125-layout-container` plus its renderer/main-content host. It does not repaint the full child document or the top creative's absolute overlay.

## Bottom navigation lines

The v7.473 native capture proves two separate owners:

1. `ANXTabBarView.layer.borderWidth = 1.10` — the full thin outline.
2. A top-edge layer/view approximately 44×5 — the partial bright line/indicator.

The v7.475/v7.476 helper only searched sublayers with height ≤2, so it could match neither owner. v7.477 narrows the helper to `ANXTabBarView`, clears the bar's own border, and suppresses only a top-edge sublayer with height ≤6 and width 30–70. It is reasserted on the existing layout lifecycle; icons, labels, selection state, and general tab geometry are untouched.

## PDP Top / Details / Explore / Reviews row

The v7.475/v7.476 geometry rule targeted `#nav-subnav .mshop-subnav-link`. Probe evidence identifies that as the separate Shop Books / Categories / Kindle Unlimited subnav, not the sticky PDP row shown in the screenshot. That geometry override is removed in v7.477.

The existing capture identifies the correct sticky owner as `#btf-sub-nav-top-navigation-bar`, but does not expose its text descendants' font-size, line-height, rect, alignment, or transform. v7.477 therefore does two things instead of hardcoding a guessed font size:

1. production uses the exact `#btfSubNavTopTab` owner and, at document-ready/pageshow, copies the first valid sibling tab's computed `font-size`, `font-weight`, `line-height`, vertical padding, transform, display, and actual height onto `Top`; this makes Top follow Amazon's current sibling geometry rather than a fixed pixel guess;
2. the probe expands all relevant diagnostics with a bounded `btfNav7477` record containing those same fields plus text length/hash, so the on-device result can be verified directly.

Visible text strings remain excluded. The lightweight viewport-sample path preserves its historical no-`querySelectorAll`/no-TreeWalker contract by using a bounded 49-node child stack. The geometry repair is event-driven only (`DOMContentLoaded` + `pageshow`) and adds no polling/observer/scroll machinery.

## Source and performance gates

Final `src/Tweak.xm`: **855,937 bytes**.

Headroom under the frozen 856,000-byte gate: **63 bytes**.

Frozen mature standalone engine source SHA-256 remains:

`2734e76915bf577d60b9a012b6fee226035582aab2a499ee1c40e3a3130f7ebe`

Production recurring-mechanism textual counts in `Tweak.xm`:

- `new MutationObserver(`: 0
- `setInterval(`: 0
- `requestAnimationFrame(`: 0
- Web `addEventListener('scroll'`: 0
- `createTreeWalker(`: 0

No new production polling, DOM walker, observer, RAF loop, or scroll listener was added.

## Regression audit

The exact version-normalization performed by `scripts/validate.sh` was applied to the complete repository test tree. The final source was executed in bounded batches:

- tests 1–30: **30/30 PASS**
- tests 31–60: **30/30 PASS**
- tests 61–90: **30/30 PASS**
- tests 91–120: **30/30 PASS**
- tests 121–150: initially 29/30; the new probe instrumentation exposed a frozen `ADUIProbeViewportSample7449` no-`querySelectorAll` contract. The implementation was corrected to a bounded `.children` stack and the failing `test_v7449_full_probe_nonblocking.py` then passed, yielding **30/30** for that batch.
- tests 151–154: **4/4 PASS**

Final effective result: **154/154 PASS**.

Additional final-source checks:

- `scripts/lint-logos.sh`: PASS
- `sh -n scripts/ui-probe.sh`: PASS
- `sh -n scripts/skeleton-probe.sh`: PASS
- `sh -n scripts/validate.sh`: PASS
- `ADUniversalUIProbe7362.js.inc` extracted JS: Node syntax PASS
- `ADUniversalUIProbe7362.frame.js.inc` extracted JS: Node syntax PASS
- `ADUIProbeViewportSample7449.js.inc` extracted JS: Node syntax PASS
- `ADPDPMainStream7451.js.inc` extracted JS: Node syntax PASS
- `git diff --no-index --check` against v7.476: no whitespace errors

Theos/iOS SDK compilation cannot be executed in this container; GitHub Actions remains the compilation authority. The complete source/regression stage that previously caused repeated failures has been audited before packaging.

## Final packaged-release replay

After creating the flat-root release ZIP, it was extracted into a clean `ad7477_roundtrip` directory. The complete `scripts/validate.sh` version-normalization was recreated against that **extracted package**, and all **154/154 Python regressions passed again** in six bounded batches: 30/30, 30/30, 30/30, 30/30, 30/30, and 4/4. The extracted package also passed the focused v7.474–v7.477 tests, `lint-logos`, and shell syntax checks.
