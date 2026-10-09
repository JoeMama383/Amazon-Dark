# AmazonDark v7.614 — strict CI regression and probe version repair

**Parent:** v7.613~keep-shopping-media, preserving the UI fixes added after the v7.605 device captures. No reversion of product, review, Climate Pledge, lists, live, or Keep Shopping for theming.

## Root cause of GitHub CI failure

The v7.613 package metadata and native probe names had been updated, but the three helper shell scripts still identified themselves as v7.611. `scripts/validate.sh` correctly rejected `scripts/ui-probe.sh` because `VER=7.613` was missing; `skeleton-probe.sh` and `performance-probe.sh` were similarly stale. `COMMANDS.md` also still described the v7.611 push.

## Corrections

- Set `scripts/ui-probe.sh` to `VER=7.614`.
- Set `scripts/skeleton-probe.sh` to `AD_PROBE_VERSION=7.614`, `AD_PROBE_NAME=AmazonDark-v7.614`, and its installed-package guard to `7.614~*`.
- Set `scripts/performance-probe.sh` to `VER=7.614`; replace its stale receipt ceiling (`<=597`) with the running package version, so it discovers current v7.614 receipts.
- Synchronize the package control, native `AD_VERSION`, SpringBoard logs, three universal probe formats, skeleton/transition probe state names, and performance report names/diagnostics to v7.614.
- Update the current release handoff `COMMANDS.md` with the v7.614 ZIP, existing-clone push, and separately labeled FULL/VIEWPORT/TRANSITION instructions.
- Correct historical runtime diagnostics/comments that the retained regression contracts check for current-version identity (no behavior change).
- Remove an unused `ADInLiveViewer7612` static helper that the CI dead-function audit legitimately detected. Active native live theme methods remain in place.
- Extend strict validation to require the performance-probe helper version as well as UI and skeleton probe versions.
- Add `tests/test_v7614_probe_version_and_strict_ci.py` to protect script/package/probe identity, source handoff, and the v7.606–v7.613 regression coverage against future drift.

## Validation

The exact GitHub CI validation command `AD_STRICT_VALIDATE=1 sh scripts/validate.sh` completed successfully with **271/271 Python regression files**. Logos lint passed. Previous v7.606–v7.613 regressions, probe contracts, gnu++98/Node syntax checks covered by tests, and cumulative historical contracts were exercised. No actual Theos package build, iPhone installation, or GitHub push has been performed here.
