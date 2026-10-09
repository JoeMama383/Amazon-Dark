# AmazonDark v7.603 — validation

- Source: v7.602 `pdp-visual-repair` direct parent.
- Captures: both user-provided plain-TAR v7.602 VIEWPORT probes, 2026-10-09 10:43:28 and 10:46:56 local. Inspected the exact sustainability program-name span (dark `rgb(15,17,17)`), `.ripers-lrr-badge` border (2px/12px, gray `rgb(73,77,77)`), and loaded Subscribe logo composite image (949×953 natural / 26×26 screen).
- JavaScript parser: `node --check src/ADPDPMicroFix7603.js` — PASS.
- C++98 source embedding: `c++ -std=gnu++98` for the actual new `.js.inc` — PASS.
- `python tests/test_v7602_actual_visual_cascade.py` — PASS (inherited v7.602 owners).
- `python tests/test_v7603_pdp_accent_preservation.py` — PASS (new owner/selector, one-time SVG filter and data source sanity).
- Full `AD_STRICT_VALIDATE=1 sh scripts/validate.sh` — **PASS**, exit code 0; **260 Python regressions**, `lint-logos: OK`, and **79 production cold-launch policy cases**. Covers inherited v7.602 visual contracts, unchanged universal FULL/VIEWPORT/TRANSITION probes, no recurring work, and new v7.603 exact-target cases. Full run log accompanies the download.
- No Theos/iOS SDK installed in this environment, so a device `.deb` cannot be compiled here. Final rendered appearance requires user device testing.
