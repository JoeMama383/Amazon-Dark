# AmazonDark v7.392 — probe handoff CI fix

Direct parent: `7.391~ui-completion-audit-fix`.

This is a **probe-helper / CI-only correction** on top of v7.391. The seven-menu UI completion,
Subscribe & Save loading treatment, checkout Maple/TWB work, and checkout app-switcher fix are
unchanged. No production theming selector, color, image rule, native view ownership rule, or timing
policy is intentionally changed in this release.

GitHub Actions exposed a real bug in `scripts/skeleton-probe.sh`: when `plutil` was unavailable,
the helper attempted to recover Amazon's container from probe receipts, but v7.391's candidate list
skipped the immediately previous v7.390 receipt and its version regex stopped at v7.390. As a
result, the freshly written v7.391 receipt was ignored and `arm launch` failed with
`Amazon container matches: 0`.

v7.392 removes the duplicated per-version receipt filename lists. Receipt discovery now scans only
`AmazonDark-v7.*-probe-status.json`, then requires all of the following before trusting a path:
Amazon bundle identity, `PROBE_BOOTSTRAP` event, a numeric supported receipt version, and exact
filename/payload version agreement. This preserves the Amazon-only safety boundary while preventing
a normal version bump from silently making current/previous receipts undiscoverable. Report/export use the same globbed receipt family, eliminating the second omission path. The universal
`ui-probe.sh` helper used the same fragile explicit-version pattern, so v7.392 applies the same
filename/payload-validated receipt discovery there too; this prevents viewport/export discovery from
drifting on future version bumps.

The handoff regression now explicitly covers: current-receipt fallback with every `plutil` dialect
failing; immediate v7.391 and v7.390 upgrade receipts; another-bundle rejection; filename/payload
version mismatch rejection; de-duplication; archive/export fallback; and the older compatibility
receipts.

No MutationObserver, timer, RAF loop, Web scroll listener, recurring hierarchy scan, additional
WKUserScript, or app-switcher painter is added.

See `AUDIT-v7.392.md` and `COMMANDS.md`.
