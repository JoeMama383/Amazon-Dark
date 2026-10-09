# AmazonDark v7.611 — Validation

**Completed and PASS**

- Independently inspected `AmazonDark-v7.605-ui-viewport-probe-20261009-143125-790-r8.tar`; parsed 153 visible DOM nodes and found real selectors/color values. Confirmed `lists-carousel-container` pale `rgb(247,254,255)` and original card/button white `rgb(255,255,255)`, dark titles/price `rgb(15,17,17)`, and selected All border/color blue `rgb(33,98,161)`.
- New `tests/test_v7611_your_saves_probe_owner.py`: matching exact DOM + negative menu owner, selected-blue protection, raster preference gate, no geometry/observer changes, JS syntax and gnu++98 include syntax. PASS.
- v7.607 PDP, v7.608 review filter, v7.609 review-photo/sort, v7.610 profile/notification, v7.593 review business, v7.606 Climate Pledge and v7.601 FULL diagnostic targeted tests. PASS.
- `bash scripts/lint-logos.sh`: PASS.
- `python -m compileall -q tests src`: PASS.
- Source ZIP CRC and version/package identity checked.

**Limitations**

- The full historic `scripts/validate.sh` suite was attempted repeatedly. It progressed through v7.379 and passed native static-function checks after removing a dead unused v7.610 helper, but did not finish before the runtime time limit. No 100%-of-suite PASS claim is made. The log is supplied.
- The v7.605 r8 TAR is a VIEWPORT `armed-background-during-full`, *not* the FULL scan trace. It demonstrates a real background interruption of FULL but does not prove why a properly foregrounded screenshot-driven FULL may fail. Diagnostic marker was added; no unverified FULL traversal rewrite.
- Actual Theos build, GitHub push/CI, and iPhone visual verification have not been performed here.
