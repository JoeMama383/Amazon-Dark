# AmazonDark v7.433 — universal cross-frame UI probe

Exact parent: v7.432 `pdp-safeframe-ad-fix`. All v7.432 theming is retained unchanged; this build expands the diagnostic architecture so the next UI fix can be based on the actual inner renderer rather than inferred iframe ownership.

## What changed

- **Cross-origin SafeFrames are now inspectable.** A dormant document-start bridge is injected into every Web document frame. On an explicit FULL or VIEWPORT trigger, each child frame inspects its own DOM/computed paint and returns sanitized technical results to native code. This avoids the browser security boundary that prevents the main frame from reading `iframe.contentDocument` across origins.
- **FULL and VIEWPORT remain universal.** Main-frame Web DOM, child/SafeFrame DOM, shadow roots, UIKit/React views, media metadata, scroll geometry, technical classes/IDs/test IDs, backgrounds, borders, text foreground/fill colors, filters, and pseudo-elements are included.
- **Contrast diagnostics.** Text-bearing Web nodes now include an effective-background/foreground luminance diagnostic and a `dark-on-dark`, `light-on-light`, `contrast-ok`, or `unknown` paint-risk classification. This is specifically intended to expose invisible text over OLED floors.
- **Privacy remains intact.** Visible text is not recorded; only length and FNV hash are kept. URL/src/href values are not recorded. Child-frame origin, path, and referrer are hash-only.
- **No polling architecture.** Normal runtime adds one inert `message` listener per Web document frame. There is no MutationObserver, timer, interval, RAF loop, Web scroll listener, polling loop, or recurring hierarchy scan. Scanning only runs after a screenshot FULL trigger or an armed SIGUSR2 VIEWPORT trigger.

Because the all-frame bridge is a document-start user script, force-close/reopen Amazon after installing v7.433 before collecting the first probe so every existing SafeFrame is created with the bridge present.

FULL, VIEWPORT, and TRANSITION identities are regenerated to v7.433.

See `AUDIT-v7.433.md`, `VALIDATION-v7.433.md`, and `COMMANDS.md`.
