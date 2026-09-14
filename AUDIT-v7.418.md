# AmazonDark v7.418 audit — Search caption + payment gift-card / switch cleanup

## Release
- Version: `7.418~payment-giftcard-switch-cleanup`
- Runtime: `v7.418-payment-giftcard-switch-cleanup`
- Direct shipped parent: `7.416~location-canonical-owner`
- The unshipped v7.417 Search-carousel title-strip delta is folded into this release.

## Evidence reconciled
The supplied v7.416 FULL payment probe and screenshot identify the visible payment owners exactly:

- Gift-card balance card: `data-testid="unselected-balance-pm-giftcard"`, stock white floor, 1px neutral border.
- Gift-card artwork is rendered through the card's `[data-testid="image"]` composite wrapper; switch artwork is a separate authored control.
- Enter-code white leak: `data-testid="input-claim-code-wrapper"`, stock white, while the nested text input is already dark with the desired gray border.
- Checked switch ring: `[role=switch]` contains `outline-outer` (2px gray) and `outline-inner` (1px white); the switch track itself is authored blue and the knob authored white.

The preceding Search screenshot plus historical v7.353-v7.356 diffs prove the autocomplete product-image carousel still receives light text, but the current caption panel no longer reliably matches the historical exact `.cards_carousel_widget-sug-text` floor selector.

## v7.418 correction

### Search autocomplete carousel
- Retains the historical exact `.cards_carousel_widget-sug-text` OLED/light owner.
- Adds only narrow direct-child non-media structural caption fallbacks inside `.cards_carousel_widget-sug-column`.
- Each fallback rejects descendants containing `img`, `picture`, `source`, or `cards_carousel_widget-sug-im*` media.
- Caption floor = OLED, neutral copy = light, neutral edge = `#494d4d`.
- Existing media transparency/visibility and brightness-only TWB remain unchanged.
- The rejected old broad descendant-floor owner is not restored.

### Payment gift-card row
- Adds the current `unselected-balance-pm-giftcard` family to the existing payment OLED/gray-edge owner.
- Neutral gift-card copy is pure white.
- Authored links and switch colors remain authored.
- The exact gift-card image wrapper joins the existing checkout brightness-only TWB factor; no inversion is added.

### Enter-code row
- `input-claim-code-wrapper` becomes OLED black, removing the narrow white wrapper/sliver.
- The nested actual input keeps its existing dark-gray fill and gray edge.

### Switch/sprite outline cleanup
- At document start, only `[role=switch] [data-testid=outline-outer]` and `[role=switch] [data-testid=outline-inner]` lose border/outline/box-shadow chrome.
- This is deliberately app-wide for first-party top-level Web/React switch controls while avoiding unrelated `outline-*` nodes used by text inputs.
- No switch track/knob color, image filter, glyph, SVG, or sprite ownership is added.

## Preserved behavior
- v7.416 canonical location ownership and all earlier location/permission fixes remain intact.
- Selected blue/orange/green/red semantic states remain authored.
- Existing checkout card/button/header theming remains intact.
- Existing universal FULL, VIEWPORT, and TRANSITION probes remain in place and are regenerated to v7.418.

## Architecture / cost
- New native hook class: 0.
- New WKUserScript family: 0.
- New MutationObserver: 0.
- New timer / setInterval / polling loop: 0.
- New requestAnimationFrame loop: 0.
- New Web scroll listener: 0.
- New recurring DOM/native hierarchy scan: 0.
- Search and switch corrections are static document-start CSS in the existing shared floor program.
- Gift-card and input corrections extend existing checkout selectors/TWB only.

## Validation
- 91/91 non-exhaustive Python regression files: PASS.
- Exhaustive `tests/test_probe_handoff.py`: PASS.
- `tests/test_v7417_search_carousel_title_strip_restore.py`: PASS.
- `tests/test_v7418_payment_giftcard_switch_cleanup.py`: PASS.
- `tests/test_v7418_skeleton_direct_parent_handoff.py`: PASS against the actually shipped v7.416 receipt.
- Historical shared-floor semantic hashes are still checked after normalizing only the exact approved v7.417/v7.418 deltas.
- `bash scripts/lint-logos.sh`: PASS.
- `sh -n scripts/ui-probe.sh`: PASS.
- `sh -n scripts/skeleton-probe.sh`: PASS.
- `sh -n layout/DEBIAN/postinst`: PASS.
- `layout/DEBIAN/postinst`: mode 0755.
- Local Theos/iOS SDK compile is unavailable in this environment; device/GitHub Actions remains the compile/link/package proof.
