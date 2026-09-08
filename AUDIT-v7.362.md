# AmazonDark v7.362 probe-architecture audit

## Baseline

Direct full-source parent: **v7.361~probed-renderer-paint-fix**.

Parent `src/Tweak.xm` SHA-256:
`3d3ce270405f7b092f1e480517ae18ce701e73a35976a91ba7870b13e16d451c`

The v7.361 source used here is the same generated source artifact corresponding to the current GitHub `main` version checked before this build. No v7.360 or reconstructed older source was substituted.

## Reason for v7.362

The diagnostic architecture had diverged into route-specific engines: Person, Cart, Hamburger/Menu, Alexa/Rufus, Person-submenu, Home-frame and Product Search. Trigger routing could therefore select the wrong probe when one interface was overlaid on another; the Search/autocomplete case could fall through to the selected Hamburger tab and produce a `HAMBURGER MENU UI FORENSICS PROBE` header.

v7.362 removes that routing model rather than adding another Search-only probe.

## New architecture: exactly two UI categories

### FULL — screenshot triggered

- File family: `AmazonDark-v7.362-ui-full-probe-*.txt`.
- Universal: no bottom-tab or route dispatch.
- Discovers every current on-screen `WKWebView`.
- Walks the entire mounted DOM of each WebView, not just the current viewport.
- Records computed paint, pseudo-elements, media, SVG/masks/filters, technical IDs/classes/testids/component attributes, style-owner summaries, open shadow roots, same-origin frames and viewport hit stacks.
- Walks the full mounted UIKit/React hierarchy of every visible UIWindow, including offscreen/hidden descendants, with frame, background/tint, text-run metadata, image/control state, borders and direct CALayer paint.
- No auto-scroll or offset mutation is required to obtain the DOM inventory.

### VIEWPORT — armed command triggered

- File family: `AmazonDark-v7.362-ui-viewport-probe-*.txt`.
- `scripts/ui-probe.sh arm` writes `AmazonDark-v7.362-ui-viewport.arm` into Amazon's app Documents container and immediately sends one `SIGUSR2` to the running Amazon process.
- The arm is consumed once and rejected if stale.
- Captures only screen-intersecting native views and DOM nodes in each on-screen WebView.
- Includes pseudo/media paint and a viewport `elementsFromPoint` stack grid for overlay ownership.
- Does not scroll or modify native/WebKit offsets.

## Removed divergence

The following old capture engines/output families are removed from `src/Tweak.xm`:
- Person UI probe
- Cart UI probe
- Hamburger/Menu UI probe
- Alexa/Rufus UI probe
- Person submenu hybrid probe
- Home frame probe
- Product scroll probe
- historical `AmazonDark-v7.309-*` UI-probe filenames

The previous tab decision tree (`home`, `meTab`, `cartTab`, `menuTab`, `rufusTab`) and Product-scroll-first special case are gone. Search/autocomplete therefore no longer depends on whatever bottom tab remains selected underneath it.

## Trigger/runtime discipline

Normal runtime retains exactly:
- one `UIApplicationUserDidTakeScreenshotNotification` observer for FULL UI capture;
- one SIGUSR2 dispatch source for the armed VIEWPORT capture and the pre-existing skeleton recorder.

When the transition/skeleton recorder is armed, `ADSkelTrigger7339()` still gets first refusal, preserving its behavior.

The new UI probe code adds no:
- `MutationObserver`;
- timer or polling loop;
- `requestAnimationFrame` loop;
- web scroll listener;
- recurring DOM scan;
- recurring native hierarchy scan.

## Privacy contract

Neither probe records visible strings, accessibility-label/value strings, typed queries, URL/src/href values, network request/response bodies or clipboard data. Text is represented as length plus a local FNV hash so repeated paint owners can still be correlated. Technical class/id/testid/component metadata is retained because it is needed to build narrow selectors/owners.

## Production-preservation proof

After normalizing only the runtime version/header comment, the entire `Tweak.xm` prefix before the old probe subsystem is byte-identical to v7.361. The entire source tail after the old probe subsystem is also byte-identical.

Old route-specific probe implementation removed from `Tweak.xm`: **156,530 bytes**.
New `Tweak.xm`: **8,536 lines / 544,245 bytes**, down from v7.361's **9,739 lines / 700,590 bytes**.
The new universal implementation is isolated in:
- `src/ADUniversalUIProbe7362.inc`
- `src/ADUniversalUIProbe7362.js.inc`

No v7.361 visual CSS/TWB owner was intentionally changed.

Critical unchanged parent hashes:
- `src/AmazonDarkSB.xm`: `1453e4efc45cfe95af044668234c0b6c25ea8e50ca51e3e66033f0d5161e111e`
- `src/ADSkeletonProbe7339.js.inc`: `1fbf2ea9d404d6bc96832ce8c2933094717008dec3e403db93baa261d2aeb1df`
- `Makefile`: `3a6253d2430426bd0cc156dae40591e8b7bed7c00805506169cdd2ea133edbe6`
- `.github/workflows/build.yml`: `e3e886241ff13aa23b567c9b396958c3c90a241a2e47041caddb49b45f0b6b82`
- splash logo: `4d5ab25256f6badd0649b23cfef385b9700e529762474bb463d81f43a5bc9fff`

## Validation completed

- All Python regression scripts pass after updating inherited probe-architecture assertions.
- `tests/test_v7362_universal_ui_probes.py` verifies there are exactly two current UI probe categories and that all seven route-specific capture families are absent.
- Universal Web probe JavaScript reconstructs byte-for-byte from the shipped C string include, compiles as adjacent literals under `gnu++98`, and passes `node --check`.
- No recurring web-probe machinery is present in the universal JavaScript.
- `scripts/ui-probe.sh` and `scripts/skeleton-probe.sh` pass `sh -n`.
- Skeleton probe C-string embedding still compiles under C99 and GNU++98 and retains the inherited payload hash.
- Skeleton helper handoff tests pass, including v7.361/v7.360 upgrade-receipt discovery and Amazon-only container targeting.
- `scripts/lint-logos.sh` is run in the final packaging pass.

## Build limitation

This environment does not contain Theos/iOS SDK headers, so a local tweak compile/link/package cannot be truthfully claimed here. GitHub Actions remains the authoritative iOS compile/package check after push. Device testing is still required to confirm the two universal scanners behave as intended against Amazon's live native/WebKit renderers.
