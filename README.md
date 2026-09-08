# AmazonDark v7.362 — universal dual UI probes

Direct source base: **v7.361~probed-renderer-paint-fix**, the current GitHub `main` source at the start of this build.

v7.362 does **not** change AmazonDark's visual theming. It replaces the accumulated route-specific UI probe architecture with exactly two universal probe categories that work across Home, Search/autocomplete, product Search, Cart, Person/submenus, Hamburger/Menu, Alexa/Rufus, sheets and other current app surfaces.

## Probe 1 — FULL

**Trigger:** take a screenshot inside Amazon.

Output: `AmazonDark-v7.362-ui-full-probe-...txt`

The FULL probe captures:
- every current on-screen `WKWebView` without route assumptions;
- the entire mounted DOM for each WebView, including offscreen and hidden DOM nodes;
- computed foreground/background/border/outline/shadow/filter/mask/SVG/pseudo-element/media paint;
- open shadow roots and same-origin frame DOM;
- viewport hit-test stacks;
- the complete mounted native UIKit/React hierarchy from every visible app window, including offscreen/hidden descendants and direct CALayer paint.

It does not log visible text strings, accessibility-label/value strings, URL/src/href values, network payloads or clipboard content. Text is represented only by length and a stable local hash.

## Probe 2 — VIEWPORT

**Trigger:** while the exact bad state is visible, run:

```sh
cd /var/mobile/Amazon-Dark-phone && sh scripts/ui-probe.sh arm
```

Output: `AmazonDark-v7.362-ui-viewport-probe-...txt`

The helper writes a one-shot arm in Amazon's own Documents container and immediately sends `SIGUSR2`. The VIEWPORT probe then captures only the current visual screen frame:
- screen-intersecting UIKit/React views and layer paint;
- every current on-screen WebView;
- only DOM elements intersecting the visual viewport, plus painted pseudo-elements;
- media/computed paint and a viewport `elementsFromPoint` hit grid.

No scrolling or content offset changes occur in VIEWPORT mode.

## Architecture cleanup

The old Person, Cart, Hamburger/Menu, Alexa, Person-submenu, Home-frame and Product-scroll probe dispatchers are removed. There is no longer a `menuTab`/`cartTab`/`meTab`/`rufusTab` decision tree and no historical `AmazonDark-v7.309-*` UI-probe filename reuse.

Normal runtime keeps only one screenshot notification observer and one SIGUSR2 dispatch source. Probe scans run only on an explicit trigger. No probe `MutationObserver`, timer, RAF loop, web-scroll listener, polling loop or recurring native/DOM scan was added.

The existing launch/transition/skeleton recorder remains separate and unchanged in behavior; its versioned helper identity advances to v7.362 and still takes precedence when that recorder is armed.

See `COMMANDS.md` for the short device commands and `AUDIT-v7.362.md` for validation details.
