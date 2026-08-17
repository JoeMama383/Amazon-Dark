# AmazonDark v6.0.81 Probe

## v6.0.81 — lightweight Home text probe trigger correction

Diagnostic-only correction to v6.0.80. The previous build registered a UIKit lifecycle notification with `CFNotificationCenterGetLocalCenter()`, but `UIApplicationDidBecomeActiveNotification` / `UIApplicationWillEnterForegroundNotification` are delivered through `NSNotificationCenter`, so the intended trigger could silently never run. v6.0.81 attaches the probe to the already-existing `UIApplicationDidBecomeActiveNotification` observer: the cold-launch active event only arms it; the next return to Amazon runs one 350 ms delayed snapshot. The probe is also much lighter: it selects only the largest visible `WKWebView`, scans at most 1,000 visible candidate text elements, records at most 90 dark-text leaves, and performs no native hierarchy walk or iframe recursion. It writes the report header before JavaScript evaluation so trigger success is observable even if WebKit evaluation fails. No recurring timer, scroll handler, MutationObserver, layout hook, or production painter is added.


## v6.0.78 — restore missed Home product-copy ink

Built directly from v6.0.77 after screenshots showed a split on Home: classic/seasonal product-card families rendered titles and prices light, while newer recommendation-card families could leave the product description and price near-black on the already-dark card. The root cause is the v6.0.15 native-ad isolation boundary: those Amazon-owned islands are deliberately excluded from broad Dark Reader/contrast repair, so current product-card descendants inside the same family can also be skipped. v6.0.78 keeps that isolation intact and adds a narrow bridge inside the existing bounded contrast traversal. Only dark-neutral direct text belonging to a geometry-confirmed product card (real /dp/ or data-asin product link + product image, dark effective background, and no overlap with product artwork/CSS background art) is lifted to the configured foreground, including -webkit-text-fill-color. No new DOM traversal, MutationObserver, timer, scroll callback, requestAnimationFrame, or dispatch_after is added. v6.0.77 light native scroll indicators and v6.0.75 voice-sheet microphone repair are unchanged.


Built directly from v6.0.75. AmazonDark already requested `UIScrollViewIndicatorStyleWhite` from `didMoveToWindow`, but that was only a one-time assignment; Amazon, WebKit, or React Native could set the indicator style again after mount and return the thumb to dark. v6.0.76 makes the existing public `UIScrollView` style owner authoritative by forcing later `setIndicatorStyle:` assignments to `UIScrollViewIndicatorStyleWhite` while native recoloring is active. It does not paint private scrollbar views and does not alter native indicator geometry, opacity, fade timing, scrolling, or content behavior. No probe, timer, observer, scan, scroll callback, or display-link work is added.

## v6.0.75 — restore voice permission microphone bitmap glyph

Built directly from v6.0.72. The v6.0.74 ownership probe identified the remaining dark microphone as a 44x44 `RCTUIImageViewAnimated` bitmap, not an RNSVG root. The streamlined v6 glyph gate rejected non-chrome images above 40x40 before pixel classification, while v5.446's measured native-glyph lane treated neutral glyphs through 52x52 as normal glyphs. v6.0.75 adds only a semantic exception for the 36-52pt RCT image under the `Allow microphone access` + `Shop faster with voice` sheet header, then reuses the existing dark-glyph measurement, template conversion, tint, and convergence path. No probe code or global size expansion ships.


## v6.0.72 — restore hydrated voice-permission text repair

Built directly from v6.0.69. Ports the proven v5.350 private TextKit repair into the existing native UIView sweep rather than adding a second window traversal or relying on early RCT lifecycle hooks. Only matching RCTTextView voice-permission copy is inspected; dark neutral attributed runs are lifted while cyan links are preserved.


## v6.0.69 — fix tab-bar image hook recursion

Crash-only correction: guards AmazonDark's internal tab-bar template-image write so `UITabBarSwappableImageView` cannot recursively re-enter the global `UIImageView setImage:` hook. Video-control behavior is unchanged from v6.0.68.

Built directly from v6.0.66.

- Keeps the v6.0.65/66 matched compact play/pause + mute color and Amazon's native glyph artwork.
- Stops trying to discover another parent backing layer. Instead, the actual compact control host and selected shell are clipped to a circle, so rectangular child/pseudo paint cannot show in the corners.
- Intermediate wrappers are still cleared only; they are not clipped, avoiding unnecessary changes to layout/hit regions.
- The large center play overlay remains outside the compact-control pairing path.
- Reuses the existing ad observer and media/click lifecycle; no new MutationObserver, scroll listener, interval, or RAF loop is added.
- Settings wording from v6.0.62+ remains unchanged. All other behavior remains on the v6.0.56 performance baseline.

## v6.0.56 — render-critical-path / infinite-scroll performance pass

Built from the confirmed-faster v6.0.55 baseline. This pass targets the remaining work that can compete with Amazon/WebKit while Home is hydrating new cards and showing its loading spinner. It does **not** try to use JIT as a native-code accelerator or run theme work at 120 Hz; instead it protects the render/main-thread budget so ProMotion can actually present frames smoothly.

- Dark Reader + document-start CSS remain synchronous first-paint owners, but generic contrast/seasonal fallback repair is deferred behind `requestIdleCallback` when available (short timeout fallback otherwise) instead of blocking the current hydration/mutation turn.
- Mutation-local contrast repair is capped at 360 elements; the one full-document fallback is capped at 1,400 and is deferred rather than run on the critical path.
- Native-ad isolation no longer walks up to 700 descendants, inspects every attribute/style, and repeats the whole cleanup 40 ms later. It queries only nodes carrying actual `data-darkreader-inline-*` / `--darkreader-inline-*` ownership markers and removes only those markers.
- The checkbox/dot MutationObserver no longer schedules an expensive whole-document checkbox pass for every generic Home `class`/`src` mutation. It wakes only for mutations that can actually contain checkbox/Compare/pagination-dot state.
- Generic symbol/checkbox/dot reapply is idle/deferred. Post-scroll symbol repair deliberately omits the whole-document checkbox pass because checkbox state already has its own targeted observer.
- The native 12×12 TWB image-lightness classifier is unchanged mathematically, but first-time pixel draw/decode now runs on a utility queue and re-enters the existing owner on the main thread when ready. Cached and forced semantic decisions remain immediate.
- The v6.0.51/52 Person rendered-peer fix, v6.0.55 negative peer cache, Home carousel/video/media ownership, seasonal cards, JIT toggle, 120-Hz forcing, carousel dot, checkbox/symbol behavior, splash, and general theming are preserved.

## v6.0.55 — Home scroll performance recovery

Built from the confirmed-working v6.0.54 feature set after direct on-device A/B testing showed v6.0.30 scrolls the heavy Home feed materially faster. This revision preserves all later theming/TWB coverage while removing repeated recovery work added after v6.0.30.

- Replaces v6.0.33's 160-descendant Home creative recovery with a leaf-only local pass over actual IMG/VIDEO/CANVAS and known background leaves (max 36 targets). Normal Home media returns to direct load/media-event ownership; ancestor background recovery remains only for hero child frames.
- The existing v6.0.15 ad observer no longer re-scans an entire enclosing creative plus up to 24 card roots on each lazy insertion. It repairs only the changed subtree and at most four newly discovered ad roots.
- Seasonal/mosaic cards still get one complete initialization, but later mutations inside an already-owned seasonal pane repair only the changed branch (max 64 descendants) instead of revisiting up to 360 descendants of the whole pane.
- Person/Alexa semantics remain intact but compact-wrapper results are cached, positive carousel context skips the redundant local walk, React images no longer immediately perform a second duplicate sibling-text walk, and a zero semantic result gets only one delayed hydration retry instead of two.
- The proven v6.0.51 rendered-peer fix remains. Negative peer consensus is now cached until the image/geometry changes or a new positive RCT peer appears; peer enumeration no longer re-runs the full UI-chain classifier for every already-registered peer.
- No splash/JIT/120-Hz/carousel-dot/checkbox/glyph/theme functionality is intentionally changed.

## v6.0.54 — compile-only correction

- Fixes the ten Objective-C accessibility-ID string literals in `ADNativeTWBUIChain6027()` that were accidentally emitted as C strings during the v6.0.53 cleanup.
- No runtime ownership, TWB, theming, scheduling, peer-consensus, JIT, 120-Hz, splash, or UI behavior is changed from v6.0.53.

## v6.0.53 — streamlined core / TWB hot-path cleanup

Built directly from the confirmed-working v6.0.52 behavior. This is a performance/organization pass, not a theming expansion.

- Removes the production-disabled v5.446 web/native TWB scanner and its dead A/B branches while retaining the direct semantic helpers still used by production.
- Removes the failed v6.0.44 Person heading registry and its text-hook overhead. The working v6.0.51 rendered-peer ownership is the only sparse Person fallback.
- Removes the disabled TWB `UIScrollView setContentOffset:` recovery hook entirely.
- Narrows `CALayer setContents:` TWB work to actual `UIImageView` delegates.
- Caches the production TWB web payload until preferences change.
- Streamlines rendered-peer consensus to one candidate validation / one peer enumeration and avoids allocating `allObjects` snapshots.
- Adds a settled-image fast path: already-owned RCT images only maintain their existing overlay on layout rather than re-running semantic classification.
- Avoids redundant CALayer writes by updating frame/corner/shade/z-position only when needed.
- Preserves v6.0.52 Person Buy Again / Keep Shopping coverage, Your Interests semantics, JIT, 120 Hz, carousel dot, checkbox/symbol, glyph, Home/ad, Dark Reader, top chrome, splash, and all other theming behavior.

Person-tab TWB correction built directly from the v6.0.44 functional baseline. The remaining Buy Again / Keep Shopping misses no longer depend on section-heading discovery. Product-sized `RCTUIImageViewAnimated` views are weakly registered as they naturally enter/reparent/layout; an otherwise untamed image may inherit TWB only when at least two same-sized RCT peers on the same rendered row already carry the real TWB overlay. Positive peers wake unresolved same-row peers once, removing React load-order dependence without a page scan, raw-layer owner, scroll callback, or recurring timer. `AmazonDarkSB.xm` is byte-identical to v6.0.44.

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