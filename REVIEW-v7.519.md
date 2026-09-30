# v7.519 — Person deep scan + stock Returns border geometry

Direct parent: **v7.518~person-probe-foreground-repair**.

## Why FULL was still failing on Person

The important regression boundary is not v7.500 itself. The generic universal probe implementation in v7.499 and v7.513 is behavior-identical apart from release identity, so rolling v7.517 back to the v7.513 generic engine could not recover a Person-specific transport that the universal scanner no longer had.

The older proven Person probe used an explicit owner: `RCTScrollView` with accessibilityIdentifier `me`, then resolved its actual `UIScrollView` / `RCTCustomScrollView` descendant. It moved that exact scroll owner non-animated, paused for React hydration, captured the mounted hierarchy, and restored the original offset. v7.519 restores that finite route **only when the exact Person wrapper is currently visible**, while leaving `scrollEnabled` untouched. That visible exact Person wrapper is selected before PDP detection so a retained product WebView cannot steal the route. All other non-PDP screens retain the v7.513 generic universal path; PDP retains its DOM-owned route.

The Person route uses a maximum of 40 steps, a 0.58-viewport stride clamped to 320–600 pt, a 340 ms hydration window, requested/actual offset evidence, a three-stall fail-safe, and exact offset restoration without toggling scrollEnabled. It is screenshot-triggered only; no recurring hierarchy walk, MutationObserver, timer, requestAnimationFrame loop, or production scroll listener is added.

## VIEWPORT

v7.519 restores the v7.513 boundary behavior instead of v7.518's native-only busy fallback. If a FULL capture is still running at WillResignActive, VIEWPORT does not consume its arm and does not create a partial substitute file. The one-shot arm remains available for the next eligible foreground-to-background boundary.

## Returns buttons

v7.518 zeroed React border widths on nested candidates and drew a replacement `CAShapeLayer` outline. That changed border ownership and radius geometry, contrary to the goal of retaining Amazon's original button geometry.

v7.519 removes the replacement outline. It never changes Returns border width, edge width, radius, frame, bounds, transform, or mask. It keeps Amazon/React geometry and reasserts only the gray border **color** across general and per-edge React channels when the Returns section mounts/layouts or React rewrites a border color. The OLED floor and existing text rehydration remain.

## Evidence still required

Device validation is still required. A good v7.519 FULL Person capture should contain `PERSON_FULL_ROUTE`, multiple `PERSON_FULL_MOVE` records with changing actual offsets, per-step native snapshots, and `PERSON_FULL_SCAN_END` with the original offset restored. VIEWPORT should export independently after a fresh arm/background boundary. Visual confirmation should show both Returns buttons with their stock-size rounded contours continuously visible before, during and after press.
