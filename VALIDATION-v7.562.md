# AmazonDark v7.562 validation

- Base source: v7.561~help-note-oled.
- `scripts/lint-logos.sh`: PASS.
- `sh -n scripts/ui-probe.sh`: PASS.
- `sh -n scripts/skeleton-probe.sh`: PASS.
- `sh -n layout/DEBIAN/postinst`: PASS.
- Current package/runtime/FULL/VIEWPORT/TRANSITION/PDP/SpringBoard probe identities synchronized to 7.562: PASS.
- Normalized repository Python regressions: 216/216 PASS, executed in six sequential 36-test chunks using the same identity-normalization logic as `scripts/validate.sh`.
- Historical v7.369 core-Web hash contract: PASS after keeping the new Seller Messaging program behind the existing `ADNewMenusJS7482()` expansion point.
- Historical v7.480 Objective-C++ Returns/PDP syntax guard: PASS.
- New v7.562 Seller Messaging regression: PASS.
- New v7.562 helper Objective-C++ syntax preflight with clang++: PASS.
- Reconstructed v7.562 emitted Seller Messaging JavaScript parses with `node --check`: PASS.
- v7.561 help-note, v7.560 Returns success-alert, v7.559 order-item/count, and v7.558 Filters/probe regressions all retained under normalization: PASS.
- New route program adds no MutationObserver, interval, timeout, RAF, scroll listener, polling loop, `querySelectorAll('*')` DOM walker, or recurring hierarchy scan. The only finite runtime enumeration is a maximum of 120 `document.images` entries on the exact Seller Messaging route, immediate/once-at-load.
- A monolithic `AD_STRICT_VALIDATE=1 sh scripts/validate.sh` run was also started and produced only PASS output before the container command timeout; the complete normalized regression set was then run successfully in bounded chunks as above.
