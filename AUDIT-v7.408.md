# AmazonDark v7.408 audit — permission/location sheets + durable switcher hardening

## Base
- Direct parent: `7.407~pdp-transition-skeleton-dark`.
- All v7.407 PDP transition, v7.406 Sponsored footer, v7.405 PDP completion, and earlier behavior is retained.

## Probe mapping
The three supplied v7.406 FULL captures are distinct menus:
- r1 (`18:26:09`) — Camera access prompt.
- r2 (`18:26:52`) — Microphone / voice-access prompt.
- r4 (`18:31:05`) — Choose your location.

## Camera access
Exact React `sheet-view` ownership is granted only after camera-specific accessibility markers mount (`inflight-prompt`, `inflight-prompt-allow-button`, `allow-all-CAMERA`).
- white sheet floors -> OLED;
- neutral dark copy -> light; authored blue links stay authored;
- Allow access -> OLED + `#747a7c` border + light text;
- Not now -> `#303335` + `#747a7c` + light text;
- checkbox gets a gray edge;
- close glyph becomes light without broad image filtering.

## Microphone / voice access
Exact `sheet-view` ownership requires the captured `actionButton` + `allowTitle` family.
- white sheet floor -> OLED;
- neutral dark copy -> light while blue privacy/settings links remain semantic;
- Continue -> OLED + `#747a7c` + light text;
- captured monochrome microphone raster is made legible without broadening image taming.

## Choose your location
The existing location-sheet interior was already mostly correct and is preserved, including Amazon blue action links and the orange selected-address outline. The r4 capture exposed one anonymous full-width bright React shell behind the narrower card scroller, visible as white vertical side strips. v7.408 darkens only that exact full-width lower shell after the proven location root is active.

## Why the switcher bug kept recurring
The prior fixes encoded symptoms rather than the invariant:
- v7.389 matched one exact teal checkout shield and required the checkout controller.
- v7.402 matched neutral payment shields but required a live checkout modal, a proven payment bottom sheet, and AMI/SNP payment-controller geometry.
- Static regressions correctly proved those narrow contracts remained present, but therefore could not prove that a *different* Amazon sheet would never mount another inactive neutral shield.

The location sheet runs under `SNPViewController` / `AppCXWindow`, so a new inactive neutral visual-effect shield could bypass both old gates and still make SpringBoard capture a gray/white card.

## v7.408 durable switcher invariant
A new owner handles the common lifecycle behavior instead of route names:
- AmazonDark enabled;
- application is not active;
- exact Amazon `AppCXWindow`;
- `UIVisualEffectView` is near full-window width and at least 78% of window height;
- effect or immediate visual-effect/content child has a neutral gray-to-white tint with meaningful alpha;
- keyboard effects are excluded.

When all of those are true, the transient view is suppressed synchronously by hidden/alpha/layer-opacity ownership without mutating its authored blur/effect object. Re-show/re-alpha writes are rejected only while the app remains inactive. There is no fake snapshot, no SpringBoard painter, no generic app-switcher cover, no timer, and no polling. Chromatic effects and dark dimmers do not qualify. If the same effect object survives into the active app, its original hidden/alpha/layer-opacity state is restored.

The older exact teal owner is retained as a compatibility fallback because teal is intentionally outside the new neutral-tint gate. The old payment owner remains as historical fallback/testing coverage, but neutral shield correctness no longer depends on payment or checkout state.

## Regression strategy change
The new v7.408 regression asserts the invariant itself: inactive + AppCXWindow + large neutral visual-effect shield, with no `AMIWebViewController`, `SNPViewController`, checkout-live, payment-sheet, or bottom-sheet prerequisite inside the generic geometry owner. This is materially stronger than the old color/controller-specific tests.

## Performance
No MutationObserver, interval, RAF loop, Web scroll listener, polling loop, recurring hierarchy scan, fake snapshot, or new WKUserScript family is introduced. Ownership is event-driven through the existing UIView/UIVisualEffectView lifecycle paths.

## Probes
FULL, VIEWPORT and TRANSITION identities are regenerated as v7.408.
