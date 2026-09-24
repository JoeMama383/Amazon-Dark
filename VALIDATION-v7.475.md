# AmazonDark v7.475 validation — offsite standalone repair + PDP nav/bottom-bar polish

## Evidence reviewed

Source base: **v7.474~pdp-visible-copy-swatch**.

Reviewed inputs:

- `AmazonDark-v7.473-ui-viewport-probe-20260924-002420-079-r1.tar`
- user screenshot of the accepted Celsius standalone card
- user screenshot of the broken blank medium standalone card / `Top` subnav issue / bottom-bar hairlines

## What the current VIEWPORT probe does and does not prove

### Proven by the tar

The tar contains the top sponsored/offsite child-frame family and proves the correct renderer structure is still the offsite standalone family already being owned:

- child frame reports `survivor7473 = 1`
- child frame reports `standalone7104 = 1`
- frame contains `#offsite-buy-box`
- frame contains `#absoluteComponents`
- frame contains `a#adLink`
- sponsored/info glyph ownership is still present

This means the remaining problem is not missing frame delivery. It is incomplete wrapper ownership inside the same family.

### Not directly proven by the tar

The lower blank medium standalone creative shown in the screenshot is not the exact visible creative emitted inside this tar, and the `Top` geometry problem is only shown visually. Those fixes therefore rely on:

- the shared offsite standalone family identity proved by the tar
- the screenshot-proven visual failure mode
- the already-owned `#nav-subnav` family for the PDP tab row

## Code-level changes validated

### 1. Offsite / medium standalone sponsored family

`ADPDPGridCarouselFix7454()` now additionally owns the offsite wrapper structure:

- `#ad #absoluteComponents`
- `#ad #absoluteComponents > div`
- `#ad #absoluteComponents > div > div`
- `#offsite-buy-box`, its immediate wrapper levels, and the existing renderer-factory host path

These wrappers now receive:

- OLED floor
- no extra box shadow
- `mix-blend-mode: normal`
- one gray border / rounded edge on the offsite card shell

The neutral text whitelist is also broadened to include `ratings-review-count` alongside the existing brand / description / price leaves. Sponsored/info ownership remains separate so the subdued gray circle/text contract is preserved.

### 2. PDP subnav `Top` alignment

`ADPDPProbeBackedFixesJS7458()` now normalizes the row geometry under `#nav-subnav`:

- `#mshop-subnav-scrollable` uses flex alignment
- `.mshop-subnav-link` uses flex centering with a `44px` minimum height and normalized line-height

This is intentionally limited to the already-owned PDP subnav family.

### 3. Bottom nav separators

Native bottom-bar ownership now includes exact thin-layer suppression:

- new helper `ADHideThinBarHairlines7475()`
- applied from `ADOwnBottomBar708()`
- re-applied during `layoutSubviews` for both `ANXTabBarView` and `UITabBar`

This hides thin partial/full separator layers while preserving Amazon icon/label geometry.

## Guardrails

- `src/Tweak.xm` size: **854,994 bytes**
- Remaining headroom under the **856,000-byte** ceiling: **1,006 bytes**
- No MutationObserver added
- No `setInterval` added
- No `requestAnimationFrame` added
- No web scroll listener added
- No new TreeWalker added

## Regression checks run

Focused tests executed successfully:

- `tests/test_v7475_offsite_nav_separators.py`
- `tests/test_v7474_visible_copy_swatch.py`
- `tests/test_v7473_standalone_survivor_sheet.py`

Repository validation to run on install/push:

```sh
AD_STRICT_VALIDATE=0 sh scripts/validate.sh
```
