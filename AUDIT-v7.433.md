# AmazonDark v7.433 audit — universal cross-frame UI probe

## Exact parent

- Parent: `7.432~pdp-safeframe-ad-fix`
- Parent archive: `AmazonDark-v7.432-pdp-safeframe-ad-fix-source.zip`
- Parent SHA256: `c3481332ffe076239fbb5340be8059e13184d144b2132454b0f9a87b4a27a4c0`

## Purpose

v7.432 proved that the remaining standalone sponsored-ad failure cannot be diagnosed reliably from the parent iframe shell alone. The existing universal Web probe could enumerate same-origin iframe DOM through `contentDocument`, but browser origin isolation prevents that for Amazon's cross-origin APE/SafeFrame ad documents. This build fixes the diagnostic architecture before another theming selector is attempted.

## Runtime delta

- Adds one dormant document-start `WKUserScript` to every frame (`forMainFrameOnly:NO`).
- Adds one `WKScriptMessageHandler` named `adUniversalUI7433` to each Web user-content controller.
- The bridge is inert during normal browsing except for a single `message` event listener in each document frame.
- On an explicit FULL or VIEWPORT trigger, the main document posts a nonce-scoped probe command to iframe windows with `postMessage`; every injected child frame inspects its own DOM and recursively dispatches to nested frames.
- Child-frame results are chunked at 96,000 characters, validated by the native handler, reassembled, and appended to the same universal probe output.
- A 900 ms terminal flush window permits the final SafeFrame chunks to arrive before `UI_PROBE_END` is written.

## Captured child-frame technical state

The cross-frame snapshot includes tag/id/class/test IDs and technical attributes; ancestor chain; bounds and scroll geometry; display/visibility/opacity/z/pointer/overflow; foreground and `-webkit-text-fill-color`; backgrounds/background images/masks; borders/radius/outline/shadow; font metadata; SVG fill/stroke; filter/blend/isolation/transform; pseudo-element paint; media dimensions/state; inline-style length/hash; style-sheet metadata; scrollable roots; viewport hit-test stacks; and text length/hash only.

Text-bearing elements also receive a diagnostic effective-background lookup and luminance classification: `dark-on-dark`, `light-on-light`, `contrast-ok`, or `unknown`. This is intended to expose the exact invisible-text node in the standalone sponsored ad rather than infer it from outer iframe ownership.

## Privacy contract

- No visible text strings.
- No accessibility label/value strings.
- No URL, `src`, or `href` values.
- No network payloads or clipboard data.
- Text is length + FNV hash only.
- Child-frame origin, pathname, referrer, and window name are hash-only.

## Performance contract

No MutationObserver, interval, recurring timer, RAF loop, Web scroll listener, polling loop, or recurring hierarchy scan is added. Capture work runs only after the existing screenshot FULL trigger or armed SIGUSR2 VIEWPORT trigger. The one new normal-runtime cost is an inert `message` listener per Web document frame.

## Theming scope

No visual theming rule is changed in v7.433. `Tweak.xm` differs from v7.432 only by version identity and bridge installation/removal bookkeeping. All v7.432 PDP SafeFrame theming remains byte-equivalent inside the existing theming functions.
