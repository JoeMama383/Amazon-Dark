# VALIDATION v7.536

Evidence: `AmazonDark-v7.535-transition-probe-20260930-124635-43094.tar`.

The transition archive does not expose the remote keyboard process's individual keycap colors. It does capture the Amazon-side keyboard host at both the initial presentation and later recreation: `UIInputSetHostView`, `_UIRemoteKeyboardPlaceholderView`, and `AmazonDarkOLEDBacking7130` remain opaque black. The remaining device failure is therefore downstream keycap appearance selection, not keyboard-floor paint.

v7.536 installs a one-time guard on the exact concrete WebKit text-input-traits class returned from `WKContentView`. Later `setKeyboardAppearance:` writes are forwarded through the original implementation with `UIKeyboardAppearanceDark`, preventing a post-focus rewrite from switching the remote keyboard skin back to light. No timers, observers, recurring scans, or modal geometry changes are added.

Validation on the final source tree:
- `scripts/lint-logos.sh`: PASS
- `sh -n scripts/ui-probe.sh`: PASS
- `sh -n scripts/skeleton-probe.sh`: PASS
- normalized `tests/test_*.py`: 192 / 192 PASS in seven sequential batches
- `src/Tweak.xm`: 855472 bytes (< 856000 gate)
- v7.536 WebKit trait rewrite regression: included in the 192/192 set
- Objective-C++ build/syntax guard and WebKit payload parse regressions: included in the 192/192 set
