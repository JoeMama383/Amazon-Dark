# AmazonDark v7.0.56~probe

Exact visual base: v7.0.50~probe. This intentionally restores the v7.0.50 Sponsored-glyph behavior and removes every v7.0.53-v7.0.55 Sponsor observer/persistence experiment.

## Minimal chevron point probe

This probe is deliberately tiny. There is no PID/SIGUSR trigger, no MutationObserver, no DOM scanner, no viewport grid, no timer, no RAF, and no probe WKUserScript.

- Navigate until the dark chevron is visible.
- Tap the dark chevron once.
- On `UITouchPhaseBegan`, before Amazon handles the tap, the tweak resolves only the WKWebView containing that touch.
- It runs exactly one `document.elementsFromPoint()` call at that normalized touch coordinate.
- It records only that point stack (max 18), the top element's local ancestry (max 10), computed paint/background-image/mask/filter/fill/stroke/pseudo paint, and the touched UIKit ancestor chain.
- The result immediately overwrites `AmazonDark-chevron-point-probe-7056.txt` in Amazon's Documents sandbox.
- Every later touch simply replaces the file, so the chevron should be the last touch inside Amazon before export.

## Sponsored glyph

Unchanged from v7.0.50. AmazonDark reads the rendered Sponsored label color and applies it only to the adjacent stock feedback glyph. No Sponsor MutationObserver is present.

## Runtime shape

- New probe MutationObserver: 0
- Probe querySelectorAll: 0
- Probe TreeWalker: 0
- Probe scroll listener: 0
- Probe setInterval: 0
- Probe requestAnimationFrame: 0
- Probe setTimeout: 0
- Probe dispatch_after: 0
- Probe DOM work: one `elementsFromPoint()` on touch-began only

## Previous v7.0.49 notes

# AmazonDark v7.0.49

Built on v7.0.46 (`a6a6d86`).

### Sponsored glyph: painted again, to sheet ink

v7.0.48 removed the paint on the theory that `color-scheme: dark` would make Amazon render its own dark values for this control. It does not — the glyph went dark again. v7.0.49 therefore painted the glyph and label to `#e8e6e3`. v7.0.50 replaces that fixed pair with label-owned text plus glyph-only dynamic matching.

### Chevrons

v7.0.49 broadened the prior Home-scoped `a-icon-dropdown` rule to an unscoped dropdown/chevron fallback. On-device testing still shows dark chevrons, so v7.0.50 probes the actual tapped painter instead of adding another guessed selector.

