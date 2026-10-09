# AmazonDark v7.601 — v7.600 probe evidence and scoped repairs

Evidence: `Archive(10).zip`, containing 1 FULL (16 MB TAR) and 2 VIEWPORT (1.5 MB / 920 KB TAR) captures. The FULL archive manifest says `state=partial`, both VIEWPORT manifests say `state=completed`. The forensic fixture in `tests/fixtures/v7601_probe_owners.json` was extracted from the actual sanitized DOM chains and computed styles, not a hand-invented HTML fixture.

## Why FULL was partial

The FULL probe drove the PDP document for 25 scroll-owner steps and streamed 212 batches (6,025 visited/emitted DOM elements in the final stream). The last streaming batch explicitly reported `reason=document-backgrounded`, `truncated=true`, followed by `WEB_OWNERS_INIT_FAILURE error=document-backgrounded` and `WEB_SWEEP_END reason=owners-init-failed`. This is an actual interruption, not an incorrect TAR-export label or size-cap failure. A `COVERAGE state=partial` receipt is correct for that capture. The probe also reported 9 non-main frame payloads, but did not verify full child-frame coverage.

v7.601 makes the opt-in PDP stream faster (96 vs 24 initial elements per slice, 384 vs 256 second-pass elements, 6ms vs 4ms slice budget, fewer WK bridge batches), and emits a distinct `PDP_STREAM_ABORT` diagnostic for interrupted terminal batches rather than mislabeling them as `PDP_STREAM_COMPLETE`. It deliberately does **not** mark an interrupted capture as completed. Keep Amazon in the foreground until the scan finishes before exporting FULL.

## UI owners established by actual captures

- **Shop by brand**: `#sims-discoveryAndInspiration_feature_div_0 [class*="_c2Itb_brandCard_"]` had a white `background-image:gradient`, despite transparent `background-color`, and a bright `rgb(213,217,217)` border. The fix removes the gradient, paints OLED black, standardizes the border, and makes scoped text white/gray. Blue CTA, brand artwork, stars and Prime are not recolored.
- **Shop Aisles**: `#ee-aisles-on-uss-widget-container [class*="_everyday-essentials-aisles_AisleImage_eeAisleImageContainer__"] > img` had `filter:none`; images were 540x540 natural-size and loaded. The fix brightness-tames only those image elements, without recoloring the category text.
- **Free delivery progress**: `.tpb-progress-bar-meter` and `.a-progress-bar` were square (`border-radius:0px`); `.a-meter` was white (`rgb(255,255,255)`) despite its 8px radius. The fix restores rounded clipping at each existing layer and makes the remaining track gray without altering dimensions or the green progress fill.
- **Close X focus rectangle**: `#ax-mbs-close-white` had `outline:3px auto rgb(0,113,133)` while the icon was correctly white. The fix suppresses the focus outline on that exact button only, leaving its glyph and geometry untouched.
- **Frequently bought together**: seven product-image records under the current `sims-multiProductBundle` family had `filter:none` while seven others were already `brightness(0.42)`. The v7.600 selector targeted an older `multi-bundle-container-t3` owner. The new rule targets the captured image-display family and its actual widget owner.
- **Bundles divider**: `hr.a-divider-normal.bundles-bottom-divider` had a gray background but a **2px top border of `rgb(216,220,220)`**, creating the bright line. The fix recolors the existing border, without inserting a new line or changing thickness.
- **Complementary Products**: the captured `_c3Atb_` mosaic product images already reported `brightness(0.42)`, and the actual plus button was already medium gray with a dark ring and white-tamed icon. The v7.601 rules explicitly retain that verified ownership; no unsupported claim of a missing-image fix is made.

## Verification limits

The probe-backed test reconstructs actual captured ancestor chains, supplements truncated chains only with parent owner records present in the same capture, and checks selector matching plus CSS declarations. This verifies that selectors address the recorded elements. It is not a substitute for a post-install screenshot from the live app. FULL can still be partial if Amazon is backgrounded or a renderer fails before completion.
