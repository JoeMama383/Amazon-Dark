# AmazonDark v7.477 — PDP ad/UI regression repair

Direct parent: **v7.476~pdp-offsite-ci-repair**.

v7.475/v7.476 made one incorrect assumption that explains the new device regression: the offsite child-frame `#absoluteComponents` structure was treated as if it belonged only to the medium standalone ad. The v7.473 VIEWPORT proves it is also the full-frame absolute overlay used by the already-working top standalone/offsite creative. Painting that overlay black can cover the creative's image/text layer even though the top ad is a different visual size. v7.477 removes that broad ownership completely.

## Top standalone/offsite card

The v7.477 survivor block is restored to the **exact v7.474 top-card implementation** (the last device-confirmed working boundary) before the medium-card addition. The full-frame `#absoluteComponents` overlay is no longer painted by AmazonDark. Brand/product-description/alternate neutral price text remain white, while Sponsored/info semantics remain gray/OLED as before.

## Medium 414×125 standalone card

The medium family is now isolated by the renderer identity actually proven in the v7.463 r3 capture: `[data-testid=modern-414x125-layout-container]` under the ad renderer. That historical capture shows the desired state directly: OLED renderer/main-content floors, one rounded gray `#3b4043` card edge, normal/tamed product imagery, white neutral copy/price, and authored Prime/star assets.

v7.477 applies only that exact family. It does not reuse the top card's absolute overlay or mutate the whole child document.

## Bottom navigation lines

The v7.473 native probe already contained enough evidence to fix these exactly. `ANXTabBarView` has a **1.10 pt layer border** plus a separate **44×5 pt top indicator**. The previous v7.475 `<=2px` sublayer heuristic could match neither one. v7.477 now clears the ANX bar's own border and suppresses only the 30–70 pt wide, ≤6 pt high top-edge indicator layer. Other bottom-bar classes are not included in this hairline suppression.

## PDP `Top / Details / Explore / Reviews` row

The prior v7.475 change targeted `#nav-subnav .mshop-subnav-link`, which is the **Shop Books / Categories / Kindle Unlimited** row, not the sticky PDP row shown in the screenshot. That wrong geometry override is removed.

The existing probe identifies the correct sticky owner as `#btf-sub-nav-top-navigation-bar`, but it does not expose enough descendant geometry to justify a hard-coded font/height guess. v7.477 therefore repairs the exact `#btfSubNavTopTab` owner by copying the first valid sibling tab's live computed font-size, font-weight, line-height, vertical padding, transform, display mode, and actual height at finite `DOMContentLoaded`/`pageshow` events. That makes `Top` follow Amazon's current sibling geometry instead of baking in guessed pixels.

FULL/VIEWPORT/PDP-stream diagnostics are also expanded with `btfNav7477`, recording the exact sticky-row descendant rect/font/alignment/transform plus text length/hash so the on-device result is directly verifiable. No visible strings are exported and no observer/polling/scroll loop is added.

## Validation

The exact version-normalized historical regression corpus used by `scripts/validate.sh` was executed in bounded batches after the final source changes: **154/154 Python regressions pass**. The modified probe programs also parse successfully in Node, `lint-logos` passes, all helper shell scripts pass `sh -n`, and `src/Tweak.xm` remains below the 856,000-byte source gate.
