# AmazonDark v7.637 — startup work and attribution

Base: v7.636. This is a source release; GitHub Actions builds the installable package after your push.

- Fixed a reproducible interaction between performance-probe teardown and the production `removeAllUserScripts` hook. Teardown restored the saved script list after the hook had already reinstalled the theme, leaving duplicate programs for subsequent navigations. Controlled replacement now preserves script order and installation receipts without triggering another reinstall.
- Coalesced overlapping child-frame refresh requests and stopped invoking both frame-tree APIs for every refresh. The legacy API is now a fallback, including unexpected primary-API responses. Existing child-frame CSS delivery and same-document guard remain.
- Added armed-only timings for AmazonDark startup programs, its own event callbacks, computed-style calls, and forced child-frame delivery. Includes main/child document coverage, script-copy counts before/after cleanup, and a numeric document time origin to correlate with input stalls.
- Added a separate optional `performance-probe.sh arm styles` experiment. It ranks up to 24 theme style elements by disable/restore plus forced-layout cost, restores each sheet before yielding, and labels those results separately from normal input latency. Adopted and shadow-root sheets are not individually benchmarked.
- Fixed a pre-existing missing formatter argument in Order Details image taming so standard and WebKit-prefixed brightness use the same configured factor.
- Preserved every existing theme CSS/JS payload string (apart from release stamps), including Search hearts, product galleries, OLED floors, semantic colors and image strength. FULL/VIEWPORT/TRANSITION capture behavior is retained.

## Evidence and limits

The supplied v7.636 recording lasts 34.4 seconds and shows WebKit input-to-next-RAF delays up to 2,654 ms, input arrival up to 1,631 ms, and DOM interactive up to 15,451 ms. It does not contain script-copy counts or timings attributable to particular theme programs. The duplicate-script defect and redundant frame delivery are confirmed in code; the recording cannot prove how much of this session's delay they caused.

Device responsiveness is not yet verified. The new execution trace covers fresh documents after arming. Normal captures do not run stylesheet trials. The style experiment deliberately creates recalculation work and must not be treated as a normal-use latency measurement. All timing rows are inclusive where noted.

After installing, fully close Amazon once and reopen it to discard the prior process's script list. Then use the normal performance capture and reproduce Search → product → image swipes. Stock Amazon's responsiveness is already established; no disabled-tweak comparison is requested.
