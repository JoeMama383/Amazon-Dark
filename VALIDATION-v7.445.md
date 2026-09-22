# AmazonDark v7.445 validation

## Evidence used

Fresh v7.444 transition recording captured the Search -> PDP loader as an image-backed `UIImageView` directly under `IESSkeletonView`, itself under `AWLoadingIndicatorFullScreenModalBar`. The trace reports a logical image size of approximately 460x1036 points. The inherited production matcher compared raw CGImage pixel dimensions, which could reject the same logical raster at @2x/@3x scale.

The v7.444 helper behavior also reproduced three independent probe faults: an armed transition recorder could consume a screenshot before FULL began; UI export collected FULL and VIEWPORT together; and transition export wildcarded historical v7.x recordings into one large uncompressed tar.

## v7.445 acceptance contracts

- Screenshot trigger always reaches universal FULL, even while TRANSITION is armed.
- VIEWPORT remains a one-shot armed SIGUSR2 capture and does not start FULL.
- FULL follows WKWebView content growth until three stable bottom checks, then restores the original offset and scroll-enabled state.
- Every Web JavaScript capture callback has a finite 4-second timeout.
- Generic native FULL traversal is finite and bounded to four selected scroll candidates, 32 vertical / 16 horizontal steps, and 2500-node per-step snapshots.
- FULL and VIEWPORT completion states are independent and their exports require an explicit mode.
- FULL, VIEWPORT, and TRANSITION export as separate ZIPs.
- TRANSITION export selects only the newest current-version recording created after the current arm marker; historical captures are not copied.
- Transition image evidence includes logical size, image scale, and backing pixel size.
- Search -> PDP skeleton matching uses the exact native owner chain plus logical/scale-normalized geometry, not raw backing-pixel dimensions.
- No new production recurring traversal machinery is introduced.

## Local validation

`bash scripts/lint-logos.sh`: PASS.

All 124 Python regression tests were executed. Every test produced PASS output, no stderr output was produced, and no failure was recorded. The serial `scripts/validate.sh` wrapper itself exceeds this environment's execution-time ceiling because the historical suite is large, so the complete suite was also run in bounded parallel batches after the serial prefix had emitted only PASS results.

`sh -n scripts/ui-probe.sh`: PASS.

`sh -n scripts/skeleton-probe.sh`: PASS.

Theos/device compilation is not claimed in this environment. The GitHub/phone build remains the compile proof.

## Device checks after install

1. Search -> PDP: verify the light image-backed skeleton is now transformed to the existing dark/Home-style skeleton treatment.
2. PDP FULL: take one screenshot and allow the sweep to traverse the complete product document, including lazy growth. It must return to the original position and leave Amazon responsive.
3. Export FULL with `ui-probe.sh export full`; verify one ZIP is produced and contains only the current FULL capture plus manifest.
4. Arm/export VIEWPORT separately; verify it produces its own ZIP and does not re-export FULL.
5. Arm/reproduce/export TRANSITION; verify the ZIP is small/current-session-only and records `imageScale` plus `imagePixels` for image-backed transition views.
