# AmazonDark v7.561 validation

- Base source: v7.560~returns-success-alert-oled.
- `scripts/lint-logos.sh`: PASS.
- `sh -n scripts/ui-probe.sh`: PASS.
- `sh -n scripts/skeleton-probe.sh`: PASS.
- `sh -n layout/DEBIAN/postinst`: PASS.
- Current-version synchronization across package/runtime/FULL/VIEWPORT/TRANSITION/PDP/SpringBoard probe identities: PASS.
- Normalized repository Python regressions: 215/215 PASS, executed in nine sequential chunks using the same version-normalization logic as `scripts/validate.sh`.
- New v7.561 exact-owner regression: PASS.
- v7.560 Returns success-alert regression retained under normalization: PASS.
- Production change adds one declarative exact-family CSS rule only; no observer/timer/RAF/scroll/poll/hierarchy-scan machinery.
- Monolithic `scripts/validate.sh` was also started and produced only PASS output before the container's per-command execution timeout; the full normalized test set was then completed chunk-by-chunk as above.
