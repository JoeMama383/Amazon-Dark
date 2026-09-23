# AmazonDark v7.460 validation

## Evidence reviewed

v7.460 was built from the exact v7.458 source and the supplied `AmazonDark-v7.458-ui-viewport-probe-20260923-073220-076-r2.tar`, plus the Home/terminal screenshots. The completed VIEWPORT capture showed 2,046 visited DOM nodes spread across 107 WebKit continuation chunks and took roughly six seconds to become terminal. The Home hero Sponsored pill was recorded as `_single-video-card_style_sponsored-label-pill__*` with computed `rgba(255,255,255,0.6)`.

## Changes

- VIEWPORT now performs one finite WebKit DOM/shadow-tree pass instead of the v7.458 continuation chain. Off-screen elements are rejected before computed-style serialization; intersecting visible elements retain the detailed universal record.
- FULL keeps its existing cooperative 32-node / 3 ms continuation architecture.
- VIEWPORT cross-frame flush is 200 ms; FULL remains 900 ms.
- `ui-probe.sh export viewport` waits up to ten seconds for an already in-flight terminal state write before reporting failure.
- Home hero `_single-video-card_style_sponsored-label-pill__*` is `rgba(0,0,0,0.6)`, preserving the captured 60% opacity while changing only white -> black.
- Probe/package identities are regenerated as v7.460 for FULL, VIEWPORT, and TRANSITION.

## Regression / performance checks

- `scripts/lint-logos.sh`: PASS.
- 137 Python regression scripts are accounted for as PASS against the current production source: the 133 unaffected tests in the full parallel batch passed; the two historical invariants that intentionally covered the changed VIEWPORT/flush behavior were updated to preserve their FULL guarantees and then passed; the v7.458 PDP guard and new v7.460 ownership/reliability test both passed separately. Documentation-dependent regressions were rerun after the v7.460 handoff metadata update and passed.
- `src/Tweak.xm`: 855,809 bytes, below the existing 856,000-byte performance/source-size gate. The gate was not raised.
- No production MutationObserver, polling loop, RAF loop, scroll listener, or recurring document/hierarchy scan was added.

## Device validation still required

Install v7.460 and repeat VIEWPORT arm -> Amazon foreground -> one background -> export several times. Each attempt should terminate without a WebKit continuation chain, and immediate switching to NewTerm should be tolerated by the export wait. Confirm the Home hero Sponsored pill retains the same translucency but paints black rather than white.
