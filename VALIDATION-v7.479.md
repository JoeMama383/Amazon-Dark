# AmazonDark v7.479 validation

Package: `7.479~timer-actionbar-edge`

## Probe evidence used

- **TNF countdown:** v7.477 VIEWPORT `085327-807-r1` records the three 40×40 `atf-countdownCard-Text-Timer-Numeric-*` white chips separately from their transparent hr/min/sec labels.
- **PDP action bar:** v7.477 FULL `075301-973-r1` records `RCTView#AXFActionBarContainer` with `borderTopWidth=1.00` and the child `AXFActionBarTextButton` as a separate rounded control.
- **Return Instructions:** v7.478 FULL `112235-589-r1` records `#print-label-button-app`, the white `#share-label-secondary-view-trigger > a.a-touch-link.a-box`, the white `#return-deadline-display .a-alert-info` with its blue border, printable table rows, dark-on-dark headings/list copy, and the native 430×82 white gradient sibling above the bottom tab bar.
- **Email-copy collapsed:** v7.478 FULL `112857-071-r2` records the white full-screen popover shell and collapsed `#email-recipient-selection` accordion family.
- **Email-copy expanded:** v7.478 FULL `112958-511-r3` records the expanded white accordion pane, white input wrapper, dark textarea, checkbox family, and white `#button-share`.

## v7.479 Returns changes

1. A screen-only, route-anchored stylesheet themes the Return Instructions page to OLED floors, white neutral copy, gray dividers/borders, dark controls, and tamed raster images.
2. `#return-deadline-display` keeps its authored blue alert ring; only its interior floor and neutral text are changed.
3. Dynamic links remain authored colors; error/success alert border/icon semantics are not recolored.
4. The Email-copy popover shell, accordion family, expanded pane, input wrapper, and Share button are dark-themed from the exact r2/r3 owners.
5. The bottom fade repair targets only the near-full-width near-white sibling of `ANXTabBarView` that owns a `CAGradientLayer`, then makes that exact surface transparent.
6. The stylesheet is installed declaratively at document start and contains no observer/timer/RAF/scroll machinery.

## Static validation

- `src/Tweak.xm` remains below the 856000-byte production source gate.
- the new Returns stylesheet and native owner are split into `.inc` files so the established `Tweak.xm` size contract is preserved.
- all FULL / VIEWPORT / TRANSITION helpers remain v7.479 and export independently as TAR.
- the regression corpus includes exact assertions for the Returns main page, Email-copy r2/r3 owners, blue alert-ring preservation, and the gradient sibling gate.

Post-install device confirmation is still required, but no part of this pass was selected blindly: every changed family is present in the supplied FULL captures.

## Validation result for this regenerated v7.479 source

- `lint-logos`: PASS.
- Returns stylesheet: decoded and parsed by Node with no syntax error.
- shell syntax: `ui-probe.sh`, `skeleton-probe.sh`, and `validate.sh` all pass `bash -n`.
- `src/Tweak.xm`: 855947 bytes, below the 856000-byte gate.
- normalized regression corpus: **157/157 PASS**, executed in four bounded batches against the final source tree.
- the monolithic `AD_STRICT_VALIDATE=1 sh scripts/validate.sh` invocation reached the regression set successfully but exceeded this environment's command timeout before completing, so it is not represented as one uninterrupted pass; the identical normalized Python corpus was then completed in bounded batches with no failures.
