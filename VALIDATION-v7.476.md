# AmazonDark v7.476 validation — strict-CI repair

## Reproduced v7.475 failure

The v7.475 source was version-normalized exactly as `scripts/validate.sh` does and the historical regressions were run. The first failing contract was:

`tests/test_v7406_video_sponsored_footer_restore.py`

It asserts that the source block between `ADProductScrollVideoBorderJS7405()` and `ADPDPCompletionJS7405()` must not contain `overflow:hidden!important`. v7.475 added that declaration to the new `#offsite-buy-box` card rule inside the same source region.

## Repair

v7.476 removes the `overflow:hidden!important` declaration from the offsite card shell and keeps:

- `border:1px solid #494d4d!important`
- `border-radius:10px!important`
- OLED wrapper floors
- neutral-text promotion
- dynamic Sponsored/Prime/star ownership
- PDP subnav geometry normalization
- native bottom-bar thin-layer suppression

No production delivery mechanism changed.

## Regression audit

The complete version-normalized Python regression corpus was executed in four bounded batches after adding `test_v7476_offsite_ci_repair.py`:

- batch 1: 39/39 pass
- batch 2: 38/38 pass
- batch 3: 38/38 pass
- batch 4: 38/38 pass
- total: **153/153 pass**

Additional audit checks:

- `scripts/lint-logos.sh`: pass
- `sh -n scripts/ui-probe.sh`: pass
- `sh -n scripts/skeleton-probe.sh`: pass
- `sh -n scripts/validate.sh`: pass
- source size: **854,963 bytes**, below the 856,000-byte gate
- no temporary `.ad-regressions*` directories included in the release tree
- release ZIP root is flat (`src/`, `layout/`, `scripts/`, `Makefile`, etc.) so the push command does not depend on a nested folder name

Theos itself is not installed in this execution container, so the final arm64/arm64e package compile remains the GitHub Actions build step; the source-side CI failure that stopped v7.475 is reproduced and fixed here before handoff.
