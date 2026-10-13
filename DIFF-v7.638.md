# AmazonDark v7.638 — render work and child-frame queue repair

Base: v7.637. This source release is ready for the existing manual push workflow. GitHub Actions builds the installable package after the push.

## Changes

1. **Remove an unintended forced layout on Search and product entry.** `recognizeFeedback` treated the Event object supplied by `DOMContentLoaded` and `pageshow` as an explicit user interaction. That bypassed its route guard and read the entire rendered page through `body.innerText`. Only the literal `true` passed by an actual feedback click now bypasses the guard. The supplied recording measured one of these callbacks at **678 ms**. Genuine feedback interactions retain the existing recognition and theming.
2. **Keep one owner for forced child-frame CSS.** The same repair rules were installed in both a style element and an adopted stylesheet. Supported WebKit versions now use the adopted sheet alone, with an empty marker element. Unsupported or failed adoption uses the same CSS in the style element. Missing heads and removed adopted sheets are repaired on the existing lifecycle events. The CSS text, selectors, semantic exceptions, and image-strength calculation are unchanged.
3. **Wait for child-frame evaluations before ending a repair pass.** The previous in-flight guard ended immediately after enqueuing JavaScript. Later frame events could enqueue another batch while WebContent was still handling the first batch. The pass now submits one child at a time, advances from its completion callback, and coalesces overlapping requests into one trailing enumeration. It yields to the native main queue between children. No polling, timer retry, DOM scan, or MutationObserver was added.
4. **Extend performance attribution.** Normal captures now include `childFrameRepairRoundTrip`, covering WebContent queueing, IPC and the evaluation together. This is not a pure JavaScript execution timer. Same-document theme reports tolerate WebKit's observed ~1 ms origin rounding, preventing duplicate counts. The explicit `arm styles` experiment includes known AmazonDark-owned adopted sheets, which the previous experiment missed. Its limits are 24 owned sheets and a 15-second soft work budget; app-owned sheets and shadow roots are excluded. Normal captures perform no forced stylesheet trials.

## Evidence from the supplied capture

The v7.637 session contained **40.3 seconds**, eight web document instances, 60 cumulative web reports, no dropped records, and no overlapping UI probe. It still showed **4,506 ms input arrival**, **4,785 ms input-to-next-RAF**, and **4,948 ms event-loop lag** maxima. Worst DOM interactive was **16,884 ms**. Native theme layout work stayed below 1 ms in this recording. These measurements locate substantial delay in WebContent; they do not identify every rendering cost.

Duplicate user-script counts were zero both before enrollment and after cleanup. The prior script-list repair therefore remains in place. The three main theme documents contained up to 47 theme style elements and 1,374 top-level rules, plus an adopted sheet. The capture did not enable stylesheet trials and did not contain child-document theme reports, so it cannot establish per-sheet cost or the total child-frame contribution.

## Rendering check and limits

A synthetic 11,509-node product fixture in Playwright WebKit 26.5 executed the actual old and new child-frame payloads. Initial evaluation plus layout changed from **727 to 542 ms** and **675 to 437 ms** in two interleaved pairs. All sampled computed colors, borders, image filters, opacity, dimensions, font size, display and visibility matched. These are desktop synthetic measurements, not iPhone performance claims; WebKit 26.5 is newer than the target iOS runtime.

Selector rewrites that did not show reliable improvement were left out. Existing OLED floors, button schemes, semantic colors, product-gallery geometry and image taming remain. FULL, VIEWPORT and TRANSITION TAR capture behavior is unchanged.

This release fixes demonstrated excess work. It does **not yet prove that the complete Search tap delay or product-image swipe delay is eliminated on the phone**. After installing the Actions-built package, fully close Amazon once. Arm a normal performance capture, enter a fresh Search page, open a product and swipe its images while keeping Amazon foreground for 30–60 seconds, then export. Stock Amazon's responsiveness is already established; no disabled-tweak comparison is requested. If delay remains, the separate `arm styles` capture now covers the previously missed owned adopted sheets. Do not treat its deliberate recalculations as normal-use input latency.
