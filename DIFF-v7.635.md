# v7.635 — Input-delay diagnostic repair

The supplied v7.634 capture does not establish the cause of the reported delay. It contains 720 native touch samples (maximum event age 37.3 ms), but only one web input sample, five failed/missing periodic web snapshots, and no successful message-bridge reports. A 13.56-second WebView loading interval is not proof of 13.56 seconds of blocked input.

Fixed probe gaps:
- Install the armed recorder at document start in a dedicated WebKit content world. Loading-state changes alone could install into the outgoing document, leaving the next page unmeasured until load completion.
- Use the same isolated world for the message bridge and every native evaluation, independent of the page's globals and bridge overrides.
- Preserve the final numeric snapshot through the native evaluation callback, including when the recorder has already stopped. Previously the final evaluation discarded its return value and relied on the failing bridge.
- Recover a missing recorder at periodic sampling, cap concurrent evaluations per view, and retain numeric evaluation duration/error details.
- Add event-arrival age, queued-task delay, pointer-up/click coverage, a touch fallback, and a 250 ms foreground event-loop heartbeat. This supplies measurements when Safari does not support Event Timing or Long Tasks.
- Keep a bounded slow-event timeline and retain final cumulative samples when the snapshot limit is reached.
- Remove the diagnostic document-start script after capture while retaining other scripts in order.

The theming payloads and production styling behavior are unchanged. All added timers/listeners are armed-only and stop on deadline/page exit. No selectors, DOM traversal, text, input values, or URLs are collected.

Limitations: main-frame web input only; native touch/dispatch counters cover native menus. Timer and RAF delays include diagnostic overhead and are not hardware presentation latency. A WebKit evaluation still pending at the end of the one-second export grace may not arrive in the saved report. The release fixes demonstrated recorder defects; it does not claim a device-verified lag fix.

## Next capture

Install the Actions-built v7.635 package. Arm PERFORMANCE, return to Amazon, reproduce the delayed taps/typing/scrolling for about 30–60 seconds, then return to the terminal and export. Do not run FULL or TRANSITION alongside it. Upload the TAR and describe the interaction that felt delayed. If attribution remains ambiguous, repeat the identical route with AmazonDark disabled for an on/off comparison; the probe records the enabled preference at arm time.
