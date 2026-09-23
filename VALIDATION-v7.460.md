# AmazonDark v7.460 validation

- Direct parent: `7.459~viewport-terminal-home-hero-pill`.
- Device evidence: supplied v7.458 VIEWPORT capture plus Home screenshot.
- Root cause: v7.459 correctly identified the visible `_single-video-card_style_sponsored-label-pill__*` element, but incorrectly gated its black/60% rule behind a `#gwm-dashboard` ancestor that the captured hero-card ancestry does not establish. v7.459 also reused the older `ad7381-home-ad-shell-floor` style ID.
- Fix: v7.460 targets the exact `_single-video-card_style_sponsored-label-pill__*` family directly with `rgba(0,0,0,0.6)` and uses fresh style ID `ad7460-home-hero-pill`. The requested 60% alpha is unchanged.
- The v7.459 VIEWPORT terminal-state architecture is retained unchanged.
- Production architecture remains declarative for this fix: no MutationObserver, timer, polling loop, RAF loop, scroll listener, or recurring production traversal added.
- `src/Tweak.xm`: 855,787 bytes, below the existing 856,000-byte source-size gate.
- `bash scripts/lint-logos.sh`: PASS.
- Focused regressions PASS: v7.386 semantic/optimization golden, v7.459 VIEWPORT terminal policy, v7.460 Home hero owner test, transition handoff, selective screenshot registration, PDP SafeFrame inheritance.
- Theos/iOS SDK is unavailable in this environment; final package compilation and visual confirmation remain on-device.
