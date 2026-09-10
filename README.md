# AmazonDark v7.387 — runtime and CSS optimization

Built directly from the supplied **v7.386 sponsored-shell-ownership source**.

This release reduces document-start code and repeated native work while preserving
the current theme, all 86 sponsored selectors, universal UI probes, and transition
capture. It fixes the BYG reload guard when storage fails, checkout TWB settings
refresh/cleanup, and stale script-installation receipts after a disabled clear.

Measured with the same local toolchain: main tweak dylib 1,579,056 → 1,513,280 bytes
(4.2% smaller). Default document-start programs: 169,397 → 151,581 bytes (10.5%
smaller); all features enabled: 215,176 → 183,817 bytes (14.6% smaller).
These are size measurements, not claimed FPS or launch-time improvements.

See **AUDIT-v7.387.md** for changes, validation and limitations, and **COMMANDS.md**
for the established phone push/probe workflow. Run `sh scripts/validate.sh` before
pushing. GitHub Actions builds the installable rootless package.
