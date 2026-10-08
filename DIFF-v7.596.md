# AmazonDark v7.596 — performance diagnostics, runtime cleanup and thank-you menu

Base: the supplied v7.595 source ZIP, SHA-256 `2facd6235db78189f9e476c91ebf32a697b2bf114e88280de5f4beab66daf64c`.

## Performance audit and changes

The audit covered native layout/image/text/color hooks, Web script construction and delivery, event listeners and shadow-root work, preference-dependent caches, diagnostic capture/writers, and unused runtime helpers. It identified avoidable work in the code; it does not establish which cost dominates a particular phone session.

- Removed duplicate service-image processing from `UIImageView` image-commit and window-entry paths. Their existing image owner already performs the same work. Image ownership and the existing dimming algorithm remain in place.
- Reordered Shop the Show checks to reject irrelevant classes and colors before walking ancestors. Reused the already-read background and avoided converting a duplicate layer color to a new UIColor.
- Made Medical event registration idempotent across script reinjection. Coalesced event bursts into one microtask, removed a redundant initial shadow pass and duplicate click handler, and visited each shadow host once per bounded pass. Account shadow styles now have a stable identity instead of acquiring duplicate styles when traversal order changes.
- Made Business Card lifecycle registration idempotent while retaining its initial owner pass.
- Deleted unused native subtree/synchronous scroll discovery helpers and the unused keyboard requested-style helper/write flag. The active cooperative native discovery implementation remains.
- Corrected both Web cache keys to include the image-dimming enable flag as well as strength. Unchanged settings still reuse the existing script; changed settings generate the appropriate bytes on the next script request.
- Corrected the core formatter from 17 to 18 slots: the address-management module was supplied but silently omitted. No existing module was removed.

No continuous production DOM scanner or polling loop was added. Existing route, image, semantic-color and cold-launch contracts remain covered by strict validation. Arbitrary deletion of reachable theme code would risk removing required owners, so retained helpers were not classified as dead merely because they were expensive or old.

## New opt-in performance capture

`performance-probe.sh arm` requests one foreground session of up to 90 seconds. The request expires after 10 minutes. Returning to the background ends the session early. It does not scroll, take screenshots or collect a DOM inventory.

Captured evidence:

- Native frame-callback gap histogram, long gaps per second, touch event age at dispatch, selected theme-hook timing aggregates, and controller appearance intervals.
- WKWebView loading intervals and bounded main-document reports: animation-frame gaps, input-to-next-animation-frame delay, supported long-task/event timing and aggregate resource/navigation timing.
- Explicit support/coverage flags, caps, dropped records and whether another diagnostic was observed. Missing browser APIs are reported as unsupported, not as zero delay.

The recorder has an inactive Boolean gate in instrumented hooks. Display links, timers, KVO and Web listeners exist only during capture. Buffers and enrollment are capped. Stop removes observers/listeners and cancels recurring work; a bounded background grace period allows final Web reports, then JSON encoding and atomic writing occur off the main thread. Export includes exactly one current session JSON in a plain TAR, never historical captures. Re-arming cannot export a stale completed session.

This is a timing probe, not a sampling CPU profiler. Hook intervals can overlap; do not sum them as exclusive CPU time. Controller intervals include animations, and input-to-next-frame is a responsiveness proxy, not proof of pixel presentation. The Web program attaches to the current main document after loading; it does not see cross-origin frame internals or every earliest navigation task. It cannot by itself attribute a server/network delay or another tweak's work to AmazonDark. Instrumentation overhead is part of the measurement.

The report does not include page URLs, DOM text, typed values, touch coordinates, request bodies or screenshots. Native controller class names and aggregate timing/counts are included.

## Order-confirmation menu

Evidence: the supplied completed v7.595 FULL capture and screenshots IMG_7793–IMG_7796. The styles target the captured `#typ-body-container` and its descendants, rather than broadening delivery/payment or unrelated pages.

- OLED confirmation, delivery, recommendation, Amazon Live, credit-card banner, carousel and image-container floors.
- Shop now, Add to cart and Continue shopping: OLED black, white text, one gray border; inner AUI wrappers transparent.
- Readable neutral headings, body copy and prices; secondary copy gray; dividers gray and neutral chevrons white.
- Preserved blue links/countdown, green success indicator, red savings, orange stars, Prime artwork and the featured-product outline.
- Tamed captured category/product art, live video/posters, featured product, credit-card image and banner art once at the existing image preference strength. Dimming is applied to artwork leaves, not text/card ancestors, and respects the enable toggle.
- Corrected the video mute control and sponsored disclosure contrast without dimming the surrounding text.

The theme addition is an idempotent stylesheet carried by existing core delivery. It adds no event handler, scan, observer or timer.

## Device follow-up

Install the CI-built package from this source before arming PERFORMANCE. Reproduce a normal slow interaction without FULL/VIEWPORT/TRANSITION running. Export the TAR and note the approximate action/time that felt slow. This is the evidence needed to distinguish event backlog, theme work, Web main-thread stalls and loading delays. On-phone performance and visual results remain to be measured.
