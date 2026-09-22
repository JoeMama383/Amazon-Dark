# AmazonDark v7.454 validation

- 132/132 Python regression entry points passed after the v7.454 changes. Several tests execute the extracted JavaScript payloads in Node fixtures, including universal root/inner-panel walking, restoration, background/collapse/detachment guards, PDP streaming and payload execution.
- The v7.454-specific regression verifies exact carousel selector scope, preservation of arrow/CTA/media selectors, walk-first FULL routing, fixed-height vertical-owner discovery, and unseen-node catch-up.
- Full-suite validation caught and corrected a WebUI concatenation integration error: adding the carousel program initially left 16 format slots for 17 programs. The final source has 17 format slots and retains `ADAddressManagementJS7412()` as the final inherited program.
- `scripts/lint-logos.sh` passes.
- No Theos toolchain is configured in this workspace, so an iOS package was not compiled here. Device validation remains required after the GitHub Actions build is installed.
