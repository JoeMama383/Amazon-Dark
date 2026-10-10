# AmazonDark v7.619 — CI handoff regression repair and cumulative UI source audit

Parent: v7.618 (complete source). v7.619 is intentionally **not** another UI repaint or probe walker redesign.

## Direct CI failure repaired

GitHub CI stopped at `test_v7598_pdp_reviews_ad_followup.py` because it could not find three versioned command headers in `COMMANDS.md`.

`COMMANDS.md` now contains the literal current-version headers required by the existing regression suite:
- `## FULL — v7.619`
- `## VIEWPORT — v7.619 ARM` / `EXPORT`
- `## TRANSITION — v7.619 ARM` / `EXPORT`

The scripts and package identity are aligned with v7.619 (`scripts/ui-probe.sh`, `scripts/skeleton-probe.sh`, `scripts/performance-probe.sh`, `src/Tweak.xm`, UI probe outputs, and `layout/DEBIAN/control`). Existing-clone PUSH and three separately labeled probe command groups remain intact.

## Cumulative theme audit (original source to current)

Compared actual source files in the v7.613 archive with v7.619:
- **15 JavaScript theme modules are byte-for-byte identical**, including the separate v7.605–v7.613 sustainability, Climate Pledge, PDP summary, review-filter, review-photo/sort, Your Saves, and Keep Shopping implementations, along with inherited v7.600–v7.604 and Live/thank-you theme modules.
- **No v7.613 source file was removed** from v7.619.
- All seven post-v7.605 standalone `*.js.inc` payloads match their JavaScript sources byte-for-byte after decoding C string lines, and all seven remain wired once, in order, into `ADNewMenusJS7482()`.
- Native profile-picker/notification owner symbols from v7.610 and Live viewer/report/follow/video symbols from v7.612 remain present in `src/Tweak.xm`.
- Comparison of the v7.613 and v7.619 `Tweak.xm` files shows compiler fixes (forward declarations, three C-string class identifiers, the Live text local, and a formatting argument) and the removal of one unused helper; no removed theme injectors.
- Historical source/UI regression fixtures for v7.605–v7.618 passed individually after the project's existing current-version normalization.

These are **source-preservation findings, not proof of correct device painting**. Keep Shopping images, notification thumbnails, universal FULL traversal across every native/WebKit menu, and the Order Details OLED menu still require real device probes/rendering confirmation.

## Regression hardening

Added `tests/test_v7619_release_ui_and_commands.py` to guard exact FULL/VIEWPORT/TRANSITION command handoff headings and retained 605–613 JavaScript/native UI owners on future releases. This reduces risk of accidentally dropping these modules during repeated CI repairs.

## Important limitation

Static source inspection and Python regression tests cannot replace an actual Theos ARM64 compile or on-device UI verification. The submitted source should not be called a successful *build* until GitHub Actions produces a package.
