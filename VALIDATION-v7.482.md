# AmazonDark v7.482 validation

Package: `7.482~pdp-immersive-review-profile-theme`

## Probe evidence

- VIEWPORT r1 identifies the PUTB immersive Book details secondary view: `.a-popover.putb-immersive-view-gallery`, white popover wrapper/header, `li.putb-card` white card, `putb-card-immersive-view`, four raster detail glyphs, and pagination dots.
- VIEWPORT r2 identifies the sibling What's it about card under the same PUTB immersive owner and confirms the same white shell/card family.
- VIEWPORT r3 identifies the in-context review route: `#react-app.ryp__mobile`, `#in-context-ryp-form`, white review wrapper, white media-upload tile, yellow submit control, authored orange star images, authored blue Clear link, and product thumbnail raster.
- VIEWPORT r4 identifies the Switch Accounts React bottom sheet: `RCTView#sheet-view` / `#sheet-inset-view`, uniquely gated by `profile-picker-close-bottomsheet-button`, with white sheet planes and a 1 px light separator. The selected-account blue outline and teal account actions are authored semantic colors.

## v7.482 changes

1. PUTB immersive secondary views use OLED shell/card floors, white/light-gray neutral copy, standard gray borders/dividers, visible white detail glyphs, and preserve the authored blue selected pagination dot.
2. In-context review uses OLED floors, dark inputs/media control with gray borders, white/light-gray neutral copy, a standard OLED primary submit button, tamed product thumbnail, visible media glyph, while orange stars and the blue Clear link remain authored.
3. Switch Accounts reuses the exact native React `sheet-view` owner rather than adding a generic scanner. White sheet/row planes become OLED, dark neutral title/close/account copy becomes light, and the 1 px separator becomes the standard gray divider. Blue selection/link colors are not flattened.
4. v7.481 Returns completion, v7.480 camera/build-syntax repair, and all prior theming/probe behavior remain retained.

## Validation

- `lint-logos.sh`: PASS.
- `ui-probe.sh`, `skeleton-probe.sh`, `validate.sh`: shell syntax PASS.
- `src/Tweak.xm`: **854,059 bytes**, below the 856,000-byte source gate.
- `ADNewMenus7482.js.inc`: adjacent-literal C99 syntax PASS; GNU++98 syntax PASS; decoded JavaScript parses with Node.
- New v7.482 probe-backed regression: PASS.
- Retained v7.480 Objective-C++ build-syntax regression that catches the v7.479 malformed nested message-send failure: PASS.
- New-menu production payload contains no MutationObserver, setInterval, requestAnimationFrame, or scroll listener.
- Full normalized Python regression corpus: **161/161 PASS**, executed in bounded batches using the same v7.460→current identity normalization performed by `scripts/validate.sh`.
- A monolithic `AD_STRICT_VALIDATE=0 sh scripts/validate.sh` run passed through the early/startup/probe/sponsored/checkout suite and reached the v7.389 regression before this container's command timeout. It did not report a regression failure before timeout; the complete 161-test corpus was then run to completion in bounded batches.

## Build boundary

This environment does not contain the final Theos iOS SDK/toolchain used by GitHub Actions for the `.deb` package step. The exact compiler failure that killed v7.479 remains covered by the retained v7.480 Objective-C++ syntax regression, and all new v7.482 source/include changes passed local syntax and regression preflights before handoff.
