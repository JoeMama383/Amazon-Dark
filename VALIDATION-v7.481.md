# AmazonDark v7.481 validation

Package: `7.481~returns-menu-completion`

## Probe evidence

- **FULL r1** identifies the remaining ORC return-details white owners: `#orc-items-details-and-content-section`, `#consumed-unit-section`, `#orc-returning-items-section`, white `a-color-base-background` / `a-color-alternate-background` planes, a white `a-alert-warning`, and a white `a-button-base`.
- **FULL r2** identifies `.your-returns-page-container.instrumentation` with a gray page floor, white active-return cards, white Returns/history base planes, a white recommendation section, dark neutral copy, untamed history/recommendation images, blue authored links, and red authored price text.
- **FULL r3** shows the native bottom-tab gradient sibling already transparent, while the web document still contains `a-divider.a-divider-section > .a-divider-inner` at approximately 404×42. That is the residual visible fade/box.

## v7.481 changes

1. ORC return-details page uses route-scoped OLED floors, white neutral copy, gray dividers/borders, dark-gray secondary-button styling, neutral chevrons, and `brightness(.42)` raster taming. Authored link and alert-symbol colors are preserved.
2. Your Returns landing/history page uses OLED page/card/recommendation floors, white neutral copy, gray card/divider edges, white neutral chevrons, and raster taming. Blue links and red price text remain authored via `currentColor` preservation.
3. Return Authorization Slip collapses the 42pt AUI divider/fade family to a single 1px gray divider and removes its pseudo-element fade.
4. Native bottom-bar gradient suppression no longer depends on the sibling still being bright; the exact geometry + `CAGradientLayer` sibling remains suppressed if Amazon repaints it.
5. The v7.480 Objective-C++ build-syntax guard is retained unchanged.

## Performance / build contract

No MutationObserver, polling, RAF loop, production scroll listener, or recurring hierarchy scan is added. The new web work is declarative CSS under existing document-start injection. FULL, VIEWPORT, and TRANSITION remain separately versioned TAR workflows, and handoff commands contain no status step.

## Executed validation

- `lint-logos.sh`: PASS.
- `ui-probe.sh`, `skeleton-probe.sh`, `validate.sh`: shell syntax PASS.
- `src/Tweak.xm`: **852,534 bytes**, below the 856,000-byte source gate.
- New v7.481 Returns/menu regression: PASS.
- Retained v7.480 Objective-C++ build-syntax regression that caught the v7.479 failure: PASS.
- Retained Camera permission regression: PASS.
- Retained Returns main/email regression: PASS after updating the intentional native fade-owner assertion for v7.481.
- `ADReturnsTheme7480.js.inc`: decoded JavaScript parses with Node; the adjacent-literal include passes both C99 and GNU++98 syntax checks.
- `ADReturnsNative7480.inc`: isolated GNU++98 Objective-C++ syntax preflight PASS.
- Full normalized Python regression corpus: **160/160 PASS**, executed in four bounded batches using the same v7.460→current identity normalization performed by `scripts/validate.sh`.
- A monolithic `AD_STRICT_VALIDATE=1 sh scripts/validate.sh` run was also started and produced only PASS output until this container's execution-time limit terminated it. The entire identical normalized Python corpus was subsequently completed in bounded batches with no failures.

## Build boundary

This environment still does not contain the final Theos iOS SDK/toolchain used by GitHub Actions for the `.deb` package step. The v7.479 compiler failure remains guarded by the retained exact Objective-C++ syntax regression, and every new v7.481 source/include change has been syntax-preflighted locally before handoff.
