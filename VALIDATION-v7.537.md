# VALIDATION v7.537

## Root cause
The v7.535 transition capture showed that Amazon's keyboard host/placeholder/backing surfaces stay OLED black through the later keyboard recreation, so the bad state is not a floor regression. The remaining failure is the remote keycap appearance path. WebKit has a second, extended text-input-traits owner (`WKExtendedTextInputTraits`) used by the modern async/remote keyboard path; its `restoreDefaultValues` can write `UIKeyboardAppearanceDefault` after the initial legacy traits object was already forced dark.

## Fix
v7.537 keeps the legacy WKContentView dark-traits path and adds an exact Logos hook for `WKExtendedTextInputTraits`:
- `setKeyboardAppearance:` is clamped to `UIKeyboardAppearanceDark` while AmazonDark is enabled.
- `restoreDefaultValues` is allowed to run normally, then the exact extended traits object is restored to Dark.
- The v7.536 dynamic concrete-class replacement experiment is removed.
- No modal geometry/CSS changes, timers, polling, MutationObserver, requestAnimationFrame loops, or keyboard hierarchy scans were added.

## Validation
- `bash scripts/lint-logos.sh`: PASS.
- `sh -n scripts/ui-probe.sh`: PASS.
- `sh -n scripts/skeleton-probe.sh`: PASS.
- Current v7.537 targeted regressions: PASS.
- Reconstructed ADNewMenus JavaScript parse regression: PASS.
- Objective-C++ build syntax preflight regression: PASS.
- Exact normalized regression inventory produced by `scripts/validate.sh`: 193 tests; run sequentially in bounded batches against the final source tree: **193/193 PASS**.
- `src/Tweak.xm`: 855057 bytes, below the 856000-byte source gate.

The monolithic strict wrapper exceeds this execution environment's single-command time limit, so the same normalized test inventory was executed in bounded batches rather than claiming that the wrapper itself completed here.
