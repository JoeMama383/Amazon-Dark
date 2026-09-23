# AmazonDark v7.455 — PDP-safe manual FULL probe

Parent: `v7.454~carousel-probe-order`. Source handoff; compile/device verification remains required.

## Root cause

The Product Detail page is not behaving like Cart/Search under probe-driven scrolling. The supplied captures make the split clear:

- **R3 Cart / v7.454:** the automatic root walker completed 10 real scroll steps, from `y=0` through `y=2392`; mounted nodes grew from 2,383 to 5,637. The generic walker works.
- **R2 PDP / v7.453:** the PDP serializer started, but the app was backgrounded while it was running. It ended `document-backgrounded`; the later automatic walk never initialized and ended `root-init-failed totalSteps=0`.
- Older PDP evidence already established a second, independent product-only hazard: driving Product Detail scroll state can collapse its WebKit renderer. v7.450 documented historical PDP documents around 11k–13k px becoming a 779 px renderer after active sweep mutation.

So this is not a generic FULL failure and it is not caused by Cart having a smaller DOM. Product Detail needs a different diagnostic transport: **the probe must not drive its scroll position and must not begin with an exhaustive full-DOM style serialization.**

## v7.455 correction

- Non-PDP menus keep the v7.454 automatic root/vertical-owner walker unchanged.
- Product Detail is classified by `/dp/`, `/gp/product/`, `/gp/aw/d/`, with `#dp` fallback.
- PDP FULL never calls the generic Web scroll writer and still skips native scroll driving.
- PDP FULL installs one temporary probe-only scroll listener. **You scroll the product page normally.** After scrolling idles for 220 ms, the probe records a bounded detailed snapshot of the visible scene.
- The PDP snapshot is hit-test/visible-semantic bounded (`460` unique visible elements max); it does not TreeWalk/style the entire product DOM.
- When the user reaches the document bottom, the probe records the final checkpoint, removes the temporary listener, and marks FULL terminal. Backgrounding early stops it as partial so it never traps the app waiting on a hidden document.
- The temporary listener exists only during an explicitly triggered PDP FULL capture. Production theming still has no scroll listener, MutationObserver, polling loop, RAF loop, or recurring hierarchy scan.
- The v7.454 exact carousel OLED fix is retained unchanged.

## FULL workflow

**Cart/Search/other menus:** take one screenshot and leave Amazon foregrounded. The probe scrolls automatically and restores the starting offset.

**Product Detail:** start near the top, take one screenshot, then manually scroll through the product page to the bottom. Pause briefly at anything important. The probe captures the initial visible scene and each manual scroll-idle checkpoint. It does not programmatically move the PDP.

After the probe reaches a terminal state, run `sh scripts/ui-probe.sh status`, then `sh scripts/ui-probe.sh export full`.

VIEWPORT and TRANSITION remain separate and unchanged in behavior.
