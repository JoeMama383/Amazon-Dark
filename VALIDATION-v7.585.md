# AmazonDark v7.585 validation

Target: `7.585~medical-auth-probe-followup`

## Probe review

Reviewed the four post-v7.584 viewport archives:

- `AmazonDark-v7.584-ui-viewport-probe-20261006-193613-993-r1.tar`
- `AmazonDark-v7.584-ui-viewport-probe-20261006-193958-537-r3.tar`
- `AmazonDark-v7.584-ui-viewport-probe-20261006-194226-875-r4.tar`
- `AmazonDark-v7.584-ui-viewport-probe-20261006-194521-613-r5.tar`

The fixes in v7.585 are scoped to the probe-proven owners described in `DIFF-v7.585.md`.

## Static / handoff gates

- `scripts/lint-logos.sh`: PASS
- `layout/DEBIAN/postinst` executable-mode gate: PASS
- package identity: `7.585~medical-auth-probe-followup`: PASS
- `AD_VERSION`, FULL/VIEWPORT probe payloads, transition probe, launch probe identity: synchronized to 7.585: PASS
- stale superseded-regression guard: PASS
- emitted `ADNewMenus7482.js.inc` JavaScript parses with Node: PASS
- source regression count: 238

## Regression corpus

The stock `scripts/validate.sh` is sequential and exceeds the execution ceiling in this environment. Its own normalization logic was therefore applied to a temporary regression copy and the exact same 238 `tests/test_*.py` files were executed in four bounded parallel batches against the final source.

- batch 1: 60 / 60 PASS
- batch 2: 60 / 60 PASS
- batch 3: 60 / 60 PASS
- batch 4: 58 / 58 PASS
- total: **238 / 238 PASS**

The new v7.585 probe-shaped regression additionally verifies the standalone picker, Warbler quick actions/cards, OLED chat input, shadow-root CID sign-in styling, verification/loading owners, semantic-color preservation, artwork-only brightness scope, JavaScript syntax, and non-recurring runtime policy.
