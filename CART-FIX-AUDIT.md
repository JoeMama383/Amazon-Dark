# v7.346 Cart strip and buying-options audit

## Baseline reconciliation

Requested base: **v7.344**, Git commit
`5bf6c356489bef37783fe25cee127799fa4f7578` (`v7.344: restore Cart loader imagery and
preserve shimmer image lane`). A clean worktree was created at that commit.

Remote v7.345 (`79e7171`) was inspected, not used as the base. Its full Tweak.xm
replacement removed v7.343/v7.344 skeleton paint and probe entry points and
reintroduced old launch-readiness code. That was inconsistent with the narrow
Cart patch in the recovered v7.345 handoff. This release applies that narrow,
reviewed Cart patch to v7.344 and repairs the handoff helper. The inherited 7345
suffixes on the new Cart helpers record patch provenance, not the package version.

No code from the unfinished v7.342 working tree was used. No complete replacement
from another baseline was applied. `tests/test_cold_launch_policy.py` removes only
the exact new Cart declarations, CSS and hook additions and then checks **the
entire remaining Tweak.xm** against the actual v7.344 hash. Thus the v7.344 skeleton
rules, authored loading imagery, other UI, geometry and launch behavior are preserved.
`src/AmazonDarkSB.xm`, Makefile, Actions, injection filters, preferences, post-install
script and assets are byte-identical to v7.344.

## Evidence and changes

The returned v7.344 transition capture identifies `AWLoadingIndicatorBarView`
under `AWLoadingIndicatorWidgets_Indicator`, owned by `SMASHWebContainer`:

| Capture uptime | Selected tab | View rectangle | Layer contents |
| --- | --- | --- | --- |
| 91177.137 | home | 0, 161, 430, 5 | present |
| 91181.005 | cartTab | 0, 119, 430, 5 | present |
| 91181.835 | cartTab | 0, 114, 430, 5 | present |

The layer background was null. The position animation remains Amazon-owned. The
same class appears on Home, so class identity alone is insufficient to target Cart.
The existing v7.130 black backing intentionally sits below loading content and
leaves this progress bar above it; changing only the backdrop cannot cover the
bar's own image contents.

The patch adds one opaque black CALayer within the exact loading bar while
`cartTab` is selected. Its bounds follow that view. The layer is hidden on Cart
deselection, view detachment or disabled paint. The bar's original contents,
alpha, animations, layout and lifetime are not changed. The exact tab setter and
bar lifecycle hooks call their originals once. The tracked bar references are
weak. This is not a launch cover, a new window, a timer, or a scene-readiness gate.
Phone rendering is still required to confirm the result and tab gating.

The Cart UI capture has an inherited v7.309 filename but identifies the loaded
v7.344 source. In step 0, node 422 is the recommendation buying-options wrapper:
`#p13n-uf-anchor .p13n-sc-uncoverable-faceout .p13n-sc-sunk-container >
.a-section.a-spacing-base > .a-button.a-button-base.a-button-small.aok-inline-block`.
Its frame is 150x52, background rgb(255,255,255), border rgb(136,140,140), and radius
100px. Node 423 is the inner span; node 424 is the dark `.a-button-text` link.
`IMG_6388.png` shows “See all buying options” white between black Add-to-cart pills.

The new selector is scoped to that exact recommendation structure inside
`#sc-page-container` and excludes `.a-button-primary`. It uses OLED black, border
`#747a7c`, text `#e8e6e3`, and a transparent inner span. It sets no size, margin,
padding, transform or corner radius. Other base buttons retain their prior styling.

## Probe and workflow repair

The v7.344 Git tree still carried helper identity `7.341-helper2`, a v7.341-only
installed-package check and no `transition` command, although the native recorder
already supported combined 45-second transition capture. The new helper and native
file paths consistently use v7.346. A verified v7.344 Amazon startup receipt can
locate the container during upgrade; arming still requires installed v7.346.
Both current and prior receipts are included in exports. Uncompressed `.tar` and
plain-text fallback retain the existing no-Gzip workflow.

The DOM strip scanner formerly counted a bright computed border color even when
its border width was zero. The only JavaScript behavior change requires a painted
border wider than 0.5px before that branch can classify it as a strip. No new probe
listener or animation/lifecycle hook is introduced. The native recorder remains
v7.344 except for capture filenames.

## Validation

- Full-file v7.344 restoration/hash check passes; 79 existing production cold-launch
  decision cases pass. Existing constructor-safety and Logos checks pass.
- Actual injected ADFloorJS rendered in Chromium reproduces the white v7.344
  buying-options button, then makes it OLED black with the new code. Dimensions,
  radius, padding and border width match. Other buttons, skeleton and authored
  loading-image fixture computed styles match v7.344. Late page styles do not
  restore white paint.
- Actual embedded probe executes in the browser: document-start, a single-frame
  white state, later hydrated state, strip/gradient, shadow DOM, cross-origin frame,
  navigation and recording expiry checks pass. Its C string include compiles and
  emits identical current bytes in C99 and C++98.
- Phone-helper tests use real files/tar and emulated package/plist tools: upgrade
  receipt discovery, version checks, transition arming, no Gzip invocation, archive
  contents, text fallback, preserved logs and exclusion of unrelated app data pass.
- Theos rootless source compilation/link/package succeeds for AmazonDark,
  AmazonDarkSB and ADPrefs on arm64 and arm64e with SDK 16.5 and explicit C++98.
  The local Linux toolchain emits its existing arm64e ABI warning. That locally
  built binary is not included for installation; the unchanged macOS Actions
  workflow produces the package used by the established handoff.

These checks establish source preservation, buildability, CSS behavior in the
fixture and export reliability. They do not establish physical iPhone rendering,
absence of every cold-launch flash, or a newly successful Actions run. This release
adds no cold-launch behavior change. Follow COMMANDS.md for installation and capture.

## Reviewed input hashes

- `AmazonDark-v7.309-cart-ui-probe-20260906-104311-877-r6.txt`: `0125822b6bed94be2b30dbf1d19064c5810b25714d0a28d258c0fdb2458d2316`
- `AmazonDark-v7.344-transition-batch-20260906-104758.tar`: `48aded317e70c89ceffd82451e28b32ea42d8cb3efd7a6d216f31c50a36b540b`
- `IMG_6388.png`: `d6dc02bb7cfdc142d924d57986228fa941fbbf698792e24a89bbc08c1deff7e8`
