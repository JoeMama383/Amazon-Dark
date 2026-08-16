# Amazon Dark

True dark mode for the Amazon Shopping iOS app — a real dark theme, not a colour inversion.

Rootless jailbreak (Dopamine / ElleKit), arm64 + arm64e, iOS 15+.
Built against Amazon Shopping **27.11.8**.

---

## Why v5 is a rewrite

Every v3.x build applied a `colorInvert` CAFilter to the top-level `UIWindow`, then
tried to *counter-invert* image layers back to normal. That approach fails for a
reason no amount of tuning fixes: an inversion cannot tell a background from a
photograph. Every image class must be enumerated and exempted by hand, the
counter-filters land a layout pass late, and anything missed ships as a negative.
The binary only defines **8** image-view classes, and the tweak was chasing them
one regression at a time.

v5 stops inverting anything.

| Surface | Method | Images |
|---|---|---|
| Web views (Home, Cart, product, search) | Bundled **Dark Reader** engine | Untouched by design |
| Native chrome (tab bar, nav/search bar) | Amazon's **own** native dark theme | Amazon's own assets |
| Native content (cells, sheets, RN views) | **Dark Reader colour algorithm, ported to Obj-C** | Never on the code path |

Images are safe *structurally*, not by exemption. The colour engine intercepts
colour **declarations** — `backgroundColor`, `textColor`, `tintColor`, `borderColor`.
It never touches `layer.contents`, never installs a `CAFilter`, and never sees a
`CGImage`. A photograph is not a colour, so it is never modified. There is no
allowlist left to maintain.

---

## How the colour engine works

`src/ADColor.m` is a port of Dark Reader's dynamic-theme algorithm
(`modify-colors.ts` + `matrix.ts`). Each colour is converted to HSL and re-mapped
along a curve chosen by its role:

- **Backgrounds** fall toward the dark pole (default `#181a1b`), clamped so a light
  surface lands under 40% lightness.
- **Text and tints** rise toward the light pole (default `#e8e6e3`), floored at 55%
  lightness so nothing goes muddy. Blue hues are nudged toward 220° so links stay
  readable.
- **Borders** compress toward the middle so dividers stay visible without glowing.

Hue and saturation survive the transform, so Amazon orange stays orange and link
blue stays blue — they just sit at a lightness that works on a dark surface. The
brightness/contrast/grayscale/sepia sliders are applied afterwards as a 5×5 colour
matrix, deliberately **without** Dark Reader's invert term.

The port is differential-tested against a direct transcription of the upstream
TypeScript: **bit-identical across 2,187 colour/role combinations**.

Tinting is treated as foreground, which is what keeps tab-bar glyphs visible once
the bar behind them goes dark — the exact failure that broke v3.2.1.

---

## Build

CI builds the rootless `.deb` on every push (`.github/workflows/build.yml`) and
attaches it to releases. Locally, with Theos installed:

```bash
make clean
make package FINALPACKAGE=1 THEOS_PACKAGE_SCHEME=rootless
```

The Dark Reader engine is vendored at `Resources/darkreader.js` (MIT) and installed
beside the dylib as `AmazonDark.bundle`. To refresh it:

```bash
npm pack darkreader && tar -xzO -f darkreader-*.tgz package/darkreader.js > Resources/darkreader.js
```

## Install

```bash
ssh root@<device> "rm -f /var/mobile/*.deb"
scp packages/*.deb root@<device>:/var/mobile/
ssh root@<device> "dpkg -i /var/mobile/com.joemama383.amazondark_*.deb"
```

Then **force-quit and relaunch Amazon**. No respring — the tweak injects per-app.
Dopamine/ElleKit tweak injection must be enabled for Amazon, or the dylib never loads.

## Verify

```bash
ssh root@<device> "find /var/mobile/Containers/Data/Application -name 'AmazonDark.log' 2>/dev/null | head -1 | xargs cat"
```

Logging goes to `$TMPDIR` because a sandboxed app cannot write to `/var/mobile`.

## Settings

Settings → AmazonDark: master toggle, per-surface toggles, brightness / contrast /
grayscale / sepia, and hex background/text poles. Set the background pole to
`#000000` for OLED black. Changes apply on next foreground.

If a native screen ever looks wrong, turn off **Recolor native content** — web and
native chrome keep working independently.

---

## Notes

- `Info.plist` of the app hard-pins `UIUserInterfaceStyle = Light`. That is why every
  earlier attempt to force the trait alone kept getting clawed back; the window-level
  override in `ADForceWindowsDarkTrait` is what actually sticks.
- Amazon ships a complete native dark theme gated behind one Weblab
  (`NAVX_DARK_MODE_IOS_1283655`, default treatment `C` = off). v5 flips it client-side
  for the chrome. Server-driven SSNAP content will not return dark colour tokens for
  accounts outside the cohort — which is precisely why the local colour engine exists.
- Zero Obj-C runs in `%ctor` (raw `write()` only); all work is deferred to the main
  queue. Every hook body is wrapped in `@try/@catch`. No auto-`killall` in `postinst`.

## Credits

Colour algorithm ported from [Dark Reader](https://github.com/darkreader/darkreader)
(MIT, © Dark Reader Ltd.) — see `Resources/DARKREADER-LICENSE`.

High-FPS display-link forcing pattern adapted from [PoomSmart/CAHighFPS](https://github.com/PoomSmart/CAHighFPS) (MIT).


## v6.0.47

Splash-only correction on v6.0.46. Restores the v5.446/v6.0.1 first-frame philosophy while preserving the now-confirmed centered geometry: the cold-launch dark surface still follows SpringBoard's native scene transition, but the packaged Amazon wordmark is placed immediately in stable SpringBoard window coordinates with an explicit centered frame instead of being hidden behind a scene-settle timer. Warm/resume launches now receive a short opaque SpringBoard-space dark Amazon mask so a cached/native white splash cannot be exposed before the already-running Amazon process repaints; Amazon posts a dedicated foreground-ready signal and the mask retains the 0.55-second fade with a bounded fallback. The exact donor SplashBoard snapshot deletion semantics (including per-file deletion) are restored at process start and retained around background/foreground transitions. No TWB/Person, JIT, 120-Hz, carousel, glyph, top-chrome, or Home-card logic is changed.

## v6.0.46

Deterministic launch-transition + Person TWB precedence fix on v6.0.44. The SpringBoard cover still rides the stock icon-to-fullscreen scene transform, but its Amazon wordmark stays hidden until the scene/ancestor presentation geometry has settled; the zoom therefore carries only the dark launch surface and can no longer drag our logo from the Home Screen icon position. Ready release is now immediate — the custom 1.40-second minimum hold and 0.55-second fade are removed. Reduced Motion uses a shorter settle floor, and the bounded launch-only settle probe self-cancels when the cover is dismissed. Person TWB now gives the existing narrow Keep Shopping / Buy Again heading-band a positive precedence before a broad `ctx==1` exclusion can return, and plain `UILabel setText:` participates in heading registration. The band still only promotes individual 60–190pt `RCTUIImageView` product photos in the existing bounded live-heading region; no raw card/CALayer owner, page scan, scroll listener, recurring timer, or delayed TWB retry lane is added.

## v6.0.44

Person-tab heading-band completion build on v6.0.43. On-device v6.0.41 diagnostics proved the remaining Keep Shopping / Buy Again misses are ordinary `RCTUIImageViewAnimated` photos, while the real `Amazon.com: Keep shopping for` heading is a separate UIKit `UILabel` outside the React image subtree. v6.0.44 removes the unsuccessful v6.0.43 peer fallback and instead weak-registers only the real **Keep Shopping for** / **Buy Again** heading views as their text is assigned or attached. A missed 60–190pt RCT product image can inherit forced-product ownership only when it lies within a bounded 460pt vertical band below one of those live headings. No whole-view/CALayer ownership, scroll scan, timer, or recurring traversal is added; Your Interests remains on the confirmed-working v6.0.42 direct owner. Splash behavior is intentionally unchanged in this build.

## v6.0.43

Person-tab sparse-product completion build based directly on v6.0.42. Restores the retained v5.388 `ADWTProductPeers388()` fallback only when the streamlined direct semantic resolver returns ordinary/unknown **and the normal per-image lightness decision would otherwise leave that image untamed**. This targets the proven Buy Again / Keep Shopping pattern where same-size `RCTUIImageViewAnimated` siblings are product images but one sibling falls through individually. The peer fallback runs after the normal UI/template gates and can only promote the individual `UIImageView`; it never overlays a whole tile. A successful peer decision is cached into the existing per-image semantic cache so repeated layout reassertions stay O(1). No raw Fabric/CALayer overlay, observer, scroll scan, timer, or diagnostic instrumentation is added.

## v6.0.42

Person-tab TWB semantic precision build, based directly on v6.0.37 after v6.0.41 diagnostics proved the remaining misses are ordinary `RCTUIImageViewAnimated` product views rather than raw Fabric image layers. Recognizes Amazon's prefixed `Amazon.com: Keep shopping for` heading, adds `Your Interests` and `Buy Again` as forced product sections, and lets a positive compact Person section beat a false broad carousel exclusion. The v6.0.38-v6.0.40 raw-layer overlay experiments and v6.0.41 diagnostic instrumentation are not included.

## v6.0.37

- Keeps v6.0.36 as the functional baseline.
- Pins the seasonal mosaic panel border to the same `#3b4043` gray as neighboring Home cards in the post-Dark-Reader fixes layer, preventing Dark Reader from warming the border to tan after first paint.
- Removes the legacy v5.446 `#181a1b` box behind `badgeMessage` deal/countdown copy (`Ends in …`, `Limited time deal`) while preserving light text and the separate red `% off` `badgeLabel`.
- No new observer, timer, scroll listener, scan, or TWB runtime path.

## v6.0.36

- Promotes Home ad-card titles/prices/deal badges and seasonal mosaic-card chrome into document-start CSS so they paint correctly on first insertion instead of waiting for the contrast lifecycle.
- Replaces the title-dependent Off-to-College structural owner with a campaign-agnostic hp-mosaic/widget owner: background shells, borders, text, prices, arrows and structural effects follow the card family automatically if Amazon changes the seasonal campaign name. Product IMG/VIDEO/CANVAS remains independent and continues to follow TWB.
- Keeps the v6.0.35 package identity transition and all v6.0.34/v6.0.35 performance/JIT/120-Hz/TWB behavior.

## v6.0.35

- Uses v6.0.34 as the exact source baseline.
- Eliminates the **Off to College** green first-paint flash with a document-start rule for Amazon's `_hp-mosaic-container` structural family; the existing semantic College owner still takes over after hydration, and product media remains independently TWB-controlled.
- Renames the Debian/Sileo package identifier from `com.colindavidr.amazondark` to `com.joemama383.amazondark`. The old identifier is declared as Conflicts/Replaces/Provides so installing v6.0.35 cleanly supersedes the old package.
- Keeps the existing `com.colindavidr.amazondark` preference/notification domain internally for compatibility, so current settings and the working JIT broker are not reset by the package rename.
- Updates the install example to the new package filename. No TWB scanner, observer, scroll callback, timer, or cache experiment is added.


## v6.0.34

- Uses v6.0.33 as the exact source baseline.
- Closes the final Home carousel TWB gap for `_canvas-card_` creatives whose visible painter is a solid `canvas-container` rather than an image or URL-backed background.
- Moves **Off to College** structural background ownership out of TWB and into the always-on dark-theme bootstrap, so the pane/card shells stay dark even with TWB disabled.
- College product imagery remains separately eligible for TWB when TWB is enabled.
- Reuses the existing Dark Reader/contrast lifecycle; no new observer, scroll handler, display link, recurring timer, or cache experiment is added.

## v6.0.33

- **Exact base: v6.0.31.** The rejected v6.0.32 cache/frame experiment is not carried forward.
- Finishes the remaining Home-carousel TWB gaps without restoring the old scan-heavy engine:
  - `theming-card-background` and VJS poster leaves now own their tame directly, matching the v5.446 Home background owner instead of requiring a second matching ancestor;
  - NPACK, GWM tile, mosaic, and canvas-container creative families participate in the same direct/event-driven owner;
  - when the existing v6.0.15 ad-island observer sees a lazy/recycled creative, TWB piggybacks a bounded card-local pass (max 160 descendants) rather than adding another observer or scroll recovery path;
  - creative media exclusions are leaf-local, matching the v5.446 hero owner, so an image is no longer skipped merely because a parent wrapper contains a word such as `brand`.
- Restores the v5.446 **Off to College** pane behavior using the streamlined model: an already-classified Home media item can identify its nearby full-width College section, pin the section/large structural fills to the live app background, and keep its text light. The donor's structural geometry guards are retained; product/media backgrounds are not flattened.
- TWB remains event-driven: **0 TWB MutationObservers, 0 TWB `querySelectorAll`, 0 TWB scroll listeners, 0 intervals, and 0 RAF loops**. The existing v6.0.15 ad observer is reused.
- JIT, 120 Hz, carousel-dot, checkbox/symbol, top-chrome, Person/Alexa TWB, and first-class VIDEO ownership remain otherwise unchanged from v6.0.31.

## v6.0.31

- Completes the streamlined TWB port for v5.446's small Person/Alexa media families without restoring the old window-wide heading scan.
- Native `Shop previously watched`, `Lists and registries`, `Alexa for Shopping`, Subscribe & Save / Keep Shopping / Best Deals / Returns / gift-card media reuse v5.446's retained compact-section/carousel semantics only at direct image assignment/reparent time, then cache ownership; no scroll-driven TWB discovery is restored.
- `Your reviews` gets the donor's photo-only small-image owner; Help/Customer Service, Medical Care, and Amazon Highlights remain explicit no-TWB sections.
- Named product/Alexa sections may tame small image/glyph artwork even when it is not mostly-light, matching v5.446's forced-section precedence; generic UI glyphs keep the normal exclusion gate.
- Web Person-section ownership adds `Lists and registries`, `Alexa for Shopping`, Best Deals, gift-card and `Your reviews` semantics to the local media classifier.
- Home carousel creative coverage adds direct canvas ownership plus background/pseudo-image ownership for single-creative, single-video, theming, canvas, video-card, sbv-video, APE, hybrid-sponsored, ad-feedback and sponsored-products families. CSS-background recovery is driven only by the loaded media's short ancestor chain (or declarative inline-background selectors), not a DOM background scan.
- Keeps v6.0.30 first-class VIDEO ownership and v6.0.28 fixed top chrome. No TWB scroll listener, MutationObserver, recurring timer, or page-wide heading/background traversal is reintroduced.


## v6.0.30

- Makes web `VIDEO` a first-class TWB-owned media type instead of merely classifying it.
- Reasserts video TWB directly from media lifecycle events (`loadedmetadata`, `loadeddata`, `canplay`, `playing`) with no observer, scroll scan, or timer.
- Uses `videoWidth` / `videoHeight` for video eligibility when layout/cached media dimensions are not yet sufficient.
- Home `vjs-tech`, single-video/video-card, `sbv-video`, and video component families receive declarative first-paint ownership.
- Product/search demonstration videos are not rejected by the static full-frame-raster guard; TWB applies to the `VIDEO` element only, leaving surrounding ad text/controls independently owned.
- Keeps v6.0.29 targeted image/creative coverage and v6.0.28 top-chrome lock unchanged.


## v6.0.28

- Locks Amazon's adaptive `ANXTopNavBackgroundView` to the configured dark background so Home hero/ad-carousel colour sampling cannot recolor the search/header chrome while scrolling.
- The lock intercepts both UIView and direct CALayer background assignments, including nil/transparent clears, rather than restoring a broad scroll-time hierarchy sweep.
- Built directly on v6.0.27; TWB direct-ownership experiment, JIT, 120 Hz, carousel dots, symbols/checkboxes, and WebKit floor remain unchanged.

## v6.0.27

- Replaces production TWB recovery scans with a direct ownership experiment built from v6.0.24.
- Native TWB classifies an eligible UIImageView once when its UIImage is assigned, caches the decision for that exact image, and maintains one overlay layer.
- Native TWB no longer runs the React/horizontal-scroll descendant recovery in production mode.
- Web TWB is declarative CSS over known Amazon product-image selectors; no TWB MutationObserver, idle full scan, or special media scheduler runs in production mode.
- The v5.446-derived legacy TWB engines remain in source behind `kADLegacyTWB6027 = NO` for A/B fallback, but are not executed.
- Product-image lightness sampling remains 12x12 and cached per UIImage.
- Based directly on v6.0.24; discarded v6.0.25/v6.0.26 experiments are not included.

## v6.0.24

- Restores v5.446's late native-glyph convergence for small search/action icons so recent-search clock/X and similar controls do not fall back to black after Amazon/React repainting.
- Restores the v5.446 PDP `.ssf-share-trigger` white-glyph owner for the share action next to the product carousel.
- Restores the donor's view-aware glyph-size/content gate while keeping v6 performance scheduling.
- Narrows the Dark Reader carousel-dot ignore selector to `ul.a-pagination.a-dots li.dot-selected-t2`; the selected-dot owner itself remains unchanged.
- Preserves v6.0.23 TWB restoration, Dopamine JIT, 120 Hz, checkbox and carousel-dot behavior.

## v6.0.23

- Restores v5.446 Tame White Backgrounds media coverage without restoring its expensive scroll/document scheduling.
- Restores the v5.446 Home creative/video background owner plus Home media, hero-frame, compact sponsored-frame, and product-strip media lanes.
- Allows qualifying photographic/video media inside v6 native ad islands to be tamed while structural ad chrome/backgrounds remain Amazon-owned.
- Adds an idle/throttled full TWB recovery pass using v5.446-scale media/background budgets; mutation work remains subtree-scoped and coalesced.
- Extends native settled-scroll recovery to geometry-confirmed horizontal image carousels with a 72-view budget; the existing React recovery remains unchanged in scope/budget.
- JIT, 120 Hz, v5.446 carousel-dot ownership, checkbox/symbol fixes, and v6.0.19 PDP performance scheduling remain otherwise unchanged.

## v6.0.22

- Promotes Dopamine per-app JIT from diagnostic to the minimal production path proven on-device: a clean Amazon launch goes 0→1 only when AmazonDark JIT is enabled.
- Removes the failed live 1→0 revocation path. Settings already use the normal respring workflow, so JIT OFF is passive and the next Amazon launch stays clean.
- Removes duplicate normal-vs-raw csops diagnostics, live-toggle JIT handling, the request enable bit, and verbose transition reporting. Production verification now reads only raw kernel CS_DEBUGGED before/after the one launch-time enable request.
- SpringBoard's broker remains narrowly scoped to a PID whose executable path ends in `/Amazon.app/Amazon`; it always performs only the proven Dopamine enable call.
- Renames the settings switch from **Enable JIT (Experimental)** to **Enable JIT**.
- Preserves the v5.446 carousel-dot owner, v6.0.19 PDP performance work, and existing 120 Hz implementation unchanged.

## v6.0.21

- Fixes Dopamine per-app JIT ownership after on-device diagnostics proved that `jbclient_platform_set_process_debugged` is visible inside Amazon but its Platform-domain request is rejected from a normal App Store process.
- Routes the single set/clear request through the existing SpringBoard component, which is a platform process and therefore an authorized Dopamine Platform-domain caller.
- Broker accepts only a PID whose executable path ends in `/Amazon.app/Amazon`; arbitrary PIDs are rejected.
- Darwin notify state carries PID + nonce + requested state + result. No helper daemon, process scan, SpringBoard polling, or recurring timer.
- Amazon verifies both normal `csops` presentation state and raw `SYS_csops` kernel state off the main thread.
- JIT OFF is passive on a clean process, but if AmazonDark previously enabled JIT live it requests `fullyDebugged=false` and verifies a raw 1→0 transition.
- Preserves the v6.0.20 v5.446 carousel-dot port and all v6.0.19 performance work unchanged.

## v6.0.20

- Ports the v5.446 product-carousel selected-dot owner so the selected pagination dot stays light on the dark PDP. The original semantic class/ARIA detection and Dark Reader inline-marker cleanup are retained, while recovery stays inside v6.0.19's coalesced scheduler.
- Introduced the **Enable JIT** preference for Dopamine on iOS 17.0–17.3.1. Current Dopamine builds are requested through `jbclient_platform_set_process_debugged(getpid(), true)`; the older `jbdswDebugMe` symbol remains only as a compatibility fallback.
- JIT ON calls exactly one available Dopamine backend once and records the backend return code plus both normal `csops` and raw-kernel `SYS_csops` state before/after the request. The raw syscall prevents Dopamine's own userspace `csops` presentation hook from masking the kernel `CS_DEBUGGED` result.
- JIT OFF calls no backend and reports only the raw baseline. For a clean per-app ownership test, disable Dopamine's global **Allow JIT in Apps** option before launching Amazon.
- No SpringBoard helper, `ptrace` fallback, process scan, timer, retry loop, or recurring monitor is used. Enabling JIT grants JIT-capable process state but does not itself recompile Amazon or guarantee a speedup.
- Preserves v6.0.19 PDP performance work, the v5.446 visual ports, and the existing reversible 120 Hz implementation.

## v6.0.19

- Restores the v5.446 long-review/description expander-fade fix: Amazon's white read-more scrim is neutralized before it can paint over long copy.
- Uses CSS-only paint suppression on the known expander fade elements/pseudo-elements; no observer, timer, DOM scan, or scroll-time work is added.
- Deliberately does **not** revive the old broad `[class*=gradient]` suppression that historically hid real content.
- Preserves the confirmed-working v6.0.16 store/avatar protection, v6.0.15 native ad islands, checkbox, chrome, fast-scroll floor, and reversible 60/120 Hz behavior.

## v6.0.16

- Restores v5.446 protection for small circular content images so store/shop logos and review/profile avatars are not claimed by the generic monochrome glyph repair.
- Uses only candidate-local checks: content ancestry, meaningful image alt text, and circular display geometry backed by a larger natural bitmap. No new observer, timer, DOM sweep, or pixel analysis.
- Preserves v6.0.15 native ad islands and all known-good 6.x performance, checkbox, chrome, fast-scroll, and reversible 60/120 Hz behavior.

## v6.0.15

- Treats Home promotional/sponsored carousel cards as **Amazon-native ad islands**: generic contrast, glyph, TWB, and backdrop painters skip those subtrees.
- Restores the v5.446 web-image backdrop policy: no blanket `img { background }`; only explicitly opted-in `img[data-adbackdrop]` can receive a dark backing. This removes the rectangular black plates behind transparent brand/logo artwork.
- Adds the v5.446-style Dark Reader escape path in a leaner form: ad roots are marked before Dark Reader starts, ignored by inline-style processing, and any Dark Reader inline ownership metadata/custom properties are stripped without deleting Amazon's original inline CSS values.
- Ad-only DOM churn no longer schedules a full contrast-repair sweep.
- The proven checkbox, dark top chrome, reversible 60/120 Hz force, fast-scroll dark floor, and v6.0.13 runtime cleanup are otherwise unchanged.

## v6.0.14

- Fast-scroll white-floor follow-up: darkens the inner `WKContentView` root canvas so recycled/unpainted WebKit tiles cannot expose the stock white content backing during aggressive flings.
- Adds a root-only documentStart floor for `html`, `body`, `#a-page`, `#gwm-PageContent`, and `main` before Dark Reader parses.
- No per-scroll repaint loop. v6.0.11 live 60/120 Hz toggle behavior and the working v5.446 checkbox/top-chrome owners are unchanged.

## v6.0.11

- Keeps the v5.446 checkbox first-paint CSS, `sym413`, and `stockCheckbox434` owner byte-identical to the working donor.
- Restores the missing v5.446 dependency in the broad glyph-repair pass: native checkbox/Compare subtrees are excluded **before** generic inversion, and generic glyph writes are tagged `gfix1` / `gfix2` so `stockCheckbox434` can remove them if they ever collide. This is the path that produced the white-box regression.
- Preserves the confirmed-good v6.0.6 dark top chrome and the bounded v6.0.7 launch/performance architecture.
- Changes the refresh-rate option to **Force 120 Hz**. AmazonDark still exposes both ProMotion bundle opt-ins, but now also attempts the private per-process `CADisplay` minimum-frame-duration policy before every display-link request.
- Uses the open-source CAHighFPS high-FPS pattern for the public-facing display-link setters: `frameInterval=1`, `preferredFramesPerSecond=0` (highest available), and a `30...120` range with 120 preferred/max on a 120-Hz panel. Amazon attempts to lower these values are intercepted while the preference is enabled.
- Does not inject a new hook into `backboardd` or force SpringBoard system-wide. The first private-force test stays scoped to Amazon so a bad private selector cannot destabilize the rest of the UI.
- The one-shot verifier now reports private-force API/hook availability plus display refresh, display-link maximum/actual FPS, minimum frame duration, requested range, and measured target timing.


## v6.0.11
- Makes Force 120 Hz truly live-toggleable: OFF restores tracked display links to 60 Hz and private CADisplay duration 4; ON reapplies the proven v6.0.10 120-Hz force immediately.
- Bundle high-refresh opt-ins now report enabled only while the preference is enabled.
- The one-shot verifier now runs in both ON and OFF states so an old 120-Hz report cannot be mistaken for a fresh disabled result.
- Adds a constant-time dark backing floor to WKWebView/WKScrollView so fast 120-Hz flings reveal the dark theme rather than WebKit's default white backing while lazy tiles/content catch up.
- Checkbox and v5.446 top-chrome logic are unchanged from v6.0.10.
