# AmazonDark v7.320~icon-tap-cold-bridge

## Verified iOS 17 cold-launch interception

- Direct base: v7.319 launch-discovery probe.
- Device probe proved `SBIconView -tapGestureDidChange:` fires for `com.amazon.Amazon` with gesture state 3 and Amazon PID 0 before the Amazon process starts.
- The independent SpringBoard dark bridge is now presented synchronously at that verified tap boundary, before the original tap handler launches Amazon.
- Warm launches remain stock: if Amazon already has a PID, no bridge is shown.
- No `SBSceneView` hook, scene hierarchy insertion, launch readiness polling, or scene callback mutation exists.
- The broad v7.319 runtime discovery scan and dead private-selector launch hooks are removed.
- Amazon's exact native splash remains dark-owned in-app and removes the bridge through the existing `native-splash-ready` Darwin handoff.
- 4.0-second hard cap remains failure safety only.


## v7.318 compile-only correction

- Fixes the AmazonDarkSB arm64/arm64e linker failure caused by declaring `MSHookMessageEx` with C++ linkage inside an Objective-C++ `.xm` translation unit.
- The declaration is now `extern "C" void MSHookMessageEx(...)`, matching the `_MSHookMessageEx` symbol exported by CydiaSubstrate/ElleKit compatibility.
- No launch behavior, discovery scope, bridge behavior, theming, or probe logic changed beyond v7.320 labels/filenames.

## iOS 17 SpringBoard launch discovery

- Probe-only successor to v7.317; v7.316 visual/bridge behavior is intentionally unchanged.
- Adds a passive `SBIconView -tapGestureDidChange:` trace, because SpringBoard logs show this is the stable icon-tap boundary even when higher-level private launch selectors drift.
- At SpringBoard load, enumerates loaded SB/SBH classes and records launch/activate/open/tap/touch/icon selectors plus Objective-C type encodings, capped at 1400 records.
- Records explicit availability/type encodings for the most likely icon-launch delegate methods.
- No `SBSceneView` hook, no additional window mutation, no observer/timer/RAF loop, and no new production theming behavior.
- IMPORTANT: do not delete the SpringBoard probe file after `sbreload`; its constructor discovery inventory is part of the evidence. Add a run marker instead.

# AmazonDark v7.320~launch-transition-probe

## Probe-only cold-launch transition recorder

- Direct production baseline: v7.316~icon-launch-window-bridge. No intended visual or launch-policy change.
- SpringBoard writes `/var/mobile/AmazonDark-v7.320-launch-sb-probe.txt` with system-uptime timestamps for selector availability, icon-launch entry points, Amazon bundle/PID classification, bridge creation/visibility, window ordering, native-splash-ready receipt, removal, and hard-cap fallback.
- Passive launch-path coverage includes `SBIconController -_launchFromIconView:`, `SBIconController -iconManager:launchIconForIconView:`, `SBApplicationIcon -launchFromLocation:`, and `SBHIconManager -iconModel:launchIcon:fromLocation:context:`. Probe-only hooks call `%orig` unchanged.
- Amazon writes `AmazonDark-v7.320-launch-app-probe.txt` in its Documents directory for process start, foreground/background/scene-connect lifecycle, AXU/Tez splash callbacks, splash visibility/background state, and the exact Darwin ready post.
- Both logs use `NSProcessInfo.systemUptime`, so the export command can merge them into exact cross-process order.
- No screenshot trigger is used because the target event happens before Amazon can receive one.

# AmazonDark v7.316~icon-launch-window-bridge

## Cold launch: independent SpringBoard window, zero SBSceneView hooks

- Direct production base: v7.315 app/UI tree, but the entire v7.312-v7.315 SBSceneView shim implementation is deleted.
- SpringBoard now hooks only `SBIconController -_launchFromIconView:`. It samples Amazon process identity BEFORE `%orig` starts the app launch. Existing process = warm resume => no bridge. No process = cold icon launch => show one independent non-key, noninteractive dark SpringBoard `UIWindow`.
- The bridge window is never inserted into `SBSceneView`, never reads scene KVC, and never executes from a scene/window attachment callback.
- Amazon's exact `AXUSplashScreenViewController` / `TezBaseSplashScreenViewController` remain darkened in-app. Their existing `native-splash-ready` signal removes the independent bridge immediately after the real dark native splash is onscreen.
- Warm-resume splash suppression from v7.307 remains. Normal warm launches therefore return straight to the existing app UI.
- 4-second bridge cap is failure safety only. No Home/WebKit readiness gate, minimum hold, settle, or custom fade is restored.

# AmazonDark v7.315~springboard-async-shim

## SpringBoard watchdog fix — fully deferred scene handling

- Direct base: exact v7.314 source.
- The new 19:55/19:56 SpringBoard watchdog reports reproduce the same failure as 19:41/19:42: SpringBoard main is blocked on a pthread mutex owned by itself, with a second thread waiting behind main.
- v7.314 proved that moving `addSubview:` to after `%orig` inside `willMoveToWindow:` was insufficient. UIKit's outer scene/window transaction is still active after that callback's `%orig` returns.
- v7.315 removes the `willMoveToWindow:` hook entirely.
- `SBSceneView -didMoveToWindow` now performs only `%orig` plus one `dispatch_async` enqueue. No bundle KVC, PID lookup, preference lookup, view property access, associated-object mutation, or UIView hierarchy mutation occurs synchronously inside the scene callback.
- On the next main-queue turn, after UIKit has unwound the attachment transaction, AmazonDark identifies the Amazon scene, reads the current Amazon PID, distinguishes a new process from the remembered warm process, and only then attaches the short first-frame shim.
- `native-splash-ready` now records the ready Amazon PID before removing the shim, preventing a race where Amazon's real dark splash becomes ready before the deferred SpringBoard block executes.
- Same PID remains a true warm resume and receives no SpringBoard transition.
- PID lookup failure fails open (no shim) rather than risking a warm-resume mask or SpringBoard lock.
- App-side native splash ownership and all v7.311 Cart/Menu/Home/Person/Alexa/TWB/standalone/CNM production behavior are unchanged.

# AmazonDark v7.314~native-splash-handoff-deadlock-fix

## SpringBoard watchdog correction

- Direct base: exact v7.313 native-splash-handoff compile-fix source.
- Removes the only unsafe v7.312/v7.313 behavior: attaching the shim to a live `SBSceneView` before `%orig` inside `willMoveToWindow:`.
- Two SpringBoard watchdog stackshots independently show the main thread blocked on a pthread mutex owned by itself, consistent with UIKit hierarchy re-entry while its window-transition lock is already held.
- v7.314 still samples Amazon process identity before `%orig` for deterministic cold/warm classification, but performs no live UIView hierarchy mutation until after `%orig` returns.
- Cold launch still uses the short first-frame shim and immediately hands off on `native-splash-ready`; ordinary warm resumes still receive no SpringBoard shim.
- No Cart, Menu, Home, Person, Alexa, TWB, standalone-ad, CNM, or other production UI logic is changed.

# AmazonDark v7.313~native-splash-handoff-compile-fix

## Compile-only correction to v7.312

- Direct base: v7.312~native-splash-handoff.
- Fixes three malformed Objective-C receiver expressions in `src/AmazonDarkSB.xm`.
- No launch timing, classification, handoff, Cart, Menu, TWB, probe behavior, or other production logic is intentionally changed.
- Internal `7312` launch symbol names are intentionally retained because this is a source-syntax correction only.

# AmazonDark v7.312~native-splash-handoff

## Minimal cold first-frame shim -> Amazon's real dark splash

- Direct production base: v7.311~cold-launch-cart-firstpaint. The v7.311 Cart earliest-paint fixes, v7.310 Hamburger glyph repair, v7.309 dog/footer/XL-brand work, v7.307 warm-resume splash suppression, and all other theming/TWB/probe behavior are retained.
- SpringBoard is no longer the owner of the whole cold launch. It masks only the system-rendered pre-process LaunchScreen interval for a genuine new Amazon process. Same-process warm resumes receive no SpringBoard shim.
- The v7.311 PID identity discriminator is retained, but the shim is now attempted before `SBSceneView willMoveToWindow:` calls `%orig` whenever the Amazon scene identity is already available; post-`%orig` and `didMoveToWindow` lanes are compatibility fallbacks only.
- `AXUSplashScreenViewController` and `TezBaseSplashScreenViewController` remain directly owned dark at `viewDidLoad` / `viewWillAppear` / layout / appearance. Once either exact native splash is confirmed visible in `viewDidAppear`, Amazon posts `com.colindavidr.amazondark.native-splash-ready` and SpringBoard removes the first-frame shim immediately.
- The old Home/WebKit readiness subsystem is deleted: no 120x125 ms launch polling, no three-stable-sample requirement, no 250 ms final dwell, no 1.40 s artificial minimum, no 0.40 s post-ready settle, and no 0.55 s custom fade-to-Home. Amazon owns its real splash-to-Home transition.
- One 4.0-second absolute shim cap remains only as SpringBoard fault containment if the exact Amazon splash callback never arrives; it is not normal launch timing.
- Ordinary warm resume behavior remains stock-like: no SpringBoard logo/cover. If Amazon itself attempts to replay one of the two exact native splash controllers during an ordinary same-scene resume, the retained v7.307 app-side suppression keeps the existing interface visible underneath.
- Normal runtime adds no new MutationObserver, interval, RAF loop, web scroll listener, recurring hierarchy scan, or generic image/glyph rule. Existing explicit probes are retained and versioned v7.313.

---

# AmazonDark v7.311~cold-launch-cart-firstpaint

## Deterministic cold/warm launch classification + Cart earliest-paint completion

- Direct production base: v7.310~cart-transition-recorder-menu-glyph-repair. The v7.310 Hamburger glyph repair, v7.309 dog/Cart/footer/XL-brand corrections, v7.307 warm-resume splash bypass, and all existing theme/TWB behavior are retained.
- Cold/warm launch classification no longer relies on `processState.isRunning` in `SBSceneView didMoveToWindow:`. That flag can become true during a genuine cold launch before `didMoveToWindow` runs, causing the dark cover to be skipped and exposing Amazon's stock white launch screen.
- SpringBoard now remembers Amazon's process identity. The same process identity is a genuine warm resume and receives no AmazonDark launch cover; a new Amazon process identity is a genuine cold launch and receives the existing dark Amazon cover from `willMoveToWindow:` before scene exposure. Existing artwork, readiness gate, 1.40 s minimum, 0.40 s post-ready settle, 0.55 s fade, and 20 s safety cap are unchanged.
- Cart early skeleton completion: the pre-product p13n selector now owns the temporary direct shell itself in addition to its nested placeholder leaves. This closes the selector gap that could leave the large card plane stock white while inner skeleton bars were already themed.
- Cart saved-band ownership is raised to an exact `html body #sc-page-container #sc-saved-cart` first-paint rule with all border channels/outline/shadow/background-image neutralized; only that known 430x26 hydration band and its immediate surfaces are affected.
- The v7.310 explicit Cart transition recorder is retained and versioned v7.311. Its MutationObserver/RAF recorder exists only during the explicit 45-second probe arm window; normal production runtime adds no observer, interval, RAF loop, scroll listener, recurring hierarchy scan, broad image/glyph rule, or global `#a-white` rule.

---

# AmazonDark v7.310~cart-transition-recorder-menu-glyph-repair

## Exact Menu repair + first-paint Cart transition recorder

- Direct production base: the pushed v7.309 commit. Its dog-image taming, Cart document-start rules, footer rows, standalone-ad logo taming, launch behavior, and every other existing theme/image path are retained.
- Hamburger glyph carousel: the v7.309 Menu probe proves the blank rail is present and correctly laid out. Only the anonymous 58x58 `RCTView` wrappers directly beneath `featured-programs-tile-image-container_*` and directly owning one `RNSVGSvgView` have collapsed to 0.06–0.08 opacity. v7.310 restores opacity only on that exact vector wrapper. Raster carousel tiles, category glyphs, SVG paint, image rendering mode, and TWB ownership are untouched.
- Cart: the production Cart CSS is intentionally unchanged. The settled-page scroll probe could not identify a surface that exists only during refresh/transition, so v7.310 replaces that Cart route with an explicit two-stage recorder: trigger once on Cart to arm, reproduce within 45 seconds, then trigger again to export.
- While armed only, the recorder captures frame hit-test stacks; bright/loading candidates and their full computed paint; pseudo-elements; matched CSS rules; stylesheet ownership; DOM mutations; animation/transition events; paint/LCP/layout-shift/long-task entries; ready/load/page lifecycle; and final full-DOM plus native UIKit/WebKit snapshots. Its bounded privacy-safe ring persists through same-origin document reloads.
- Outside the explicit 45-second Cart probe window, the bridge is inert: no observer, timer, RAF, listener, scan, or production paint mutation runs.
- No generic image/logo/glyph selector, TWB expansion, broad Menu traversal, guessed Cart selector, launch change, or unrelated theming change is added.

---

# AmazonDark v7.309~probe-exact-dog-cart-footer-xl-brand

## Four narrow corrections on the v7.307 baseline

- Direct production base: v7.307~warm-resume-bypass-mic-center. Its launch/warm-resume behavior, Alexa microphone geometry, and all existing theming/image-taming paths are retained.
- No-internet dog: removes v7.301's pixel knockout and applies the existing TWB shade only to the probe-proven 640x524 image directly under `UIStackView` inside `CNMErrorView`. The authored raster and white field remain intact.
- Cart refresh: owns only the probe-proven `#sc-saved-cart` 430x26 hydration band and empty/pre-hydration cards below `#p13n-uf-anchor` at document start. Hydrated products and imagery remain excluded.
- Hamburger footer: the exact `account_switcher`, `so`, and `cs` rows keep OLED floors, white text, r16 geometry, and clipping while their visible React border channel is cleared. Category-row borders above remain unchanged.
- XL standalone ads: adds TWB only to the probe-proven `[data-testid=simple-brand-logo-picture] img` company raster, through the existing standalone and child-frame TWB lanes.
- No generic image/logo/glyph selector, broad CNM traversal, pixel rewrite, MutationObserver, timer, RAF, polling loop, scroll listener, or recurring scan is added.

---

# AmazonDark v7.307~warm-resume-bypass-mic-center

## Warm-resume splash bypass + Alexa microphone geometry correction

- Built directly from the exact v7.301 production baseline. `src/AmazonDarkSB.xm` is intentionally unchanged: ordinary warm resumes still receive no SpringBoard cover/logo/animation, while true process launches retain the existing v7.301 cold launch.
- Reverts the complete v7.306 scene-view continuity experiment. No per-`SBSceneView` first-attachment classification and no scene-triggered reset of the cold launch-ready gate remain.
- Tracks Amazon's own app lifecycle instead: after the process has been active once, a background -> foreground cycle with no intervening `UISceneWillConnectNotification` is treated as an ordinary same-scene warm resume. If Amazon attempts to replay `AXUSplashScreenViewController` or `TezBaseSplashScreenViewController` in that state, only that exact splash view is suppressed so the already-existing/saved app interface remains visible.
- A genuine scene reconnection cancels warm splash suppression. The two exact Amazon splash controller floors are still darkened at `viewDidLoad` and `viewWillAppear`, preserving their normal content while preventing an early white floor.
- Does not delete normal warm-resume UI snapshots and does not add a warm cover, timer loop, polling loop, display link, MutationObserver, or recurring scan.
- Alexa probe evidence shows `TextBoxSearchVoiceComponentButton` and its SVG are 32x32 at x=384, while the old AmazonDark voice-circle host is an anonymous 32x32 wrapper at x=386. v7.307 moves only the gray fill/mask/ring to the actual button layer, eliminating the 2pt circle/glyph center mismatch without moving or resizing the microphone SVG.
- Existing explicit screenshot/SIGUSR2 probes are retained and versioned v7.307.

# AmazonDark v7.301~universal-error-screen-dark

## Universal native no-internet / error-screen dark ownership

- Built directly from the user-confirmed v7.300 baseline; the Gift Card heading and Your Orders error-raster fixes are retained unchanged.
- The v7.300 Cart probe proves the bright offline page is native `CNMErrorView`, not Cart DOM: its 430pt root is stock white, its action buttons own white/near-white fills, and the visible hero is a 640x524 UIImage on a transparent UIImageView.
- Owns exact `CNMErrorView` ancestry universally, independent of tab/route, so the same Amazon native connectivity/error renderer is dark in Cart, Home, Person, Menu, Search, or another screen. Neutral/white floors become OLED black; action buttons become OLED black with the established `#494d4d` 1pt border and no light shadow. Existing AmazonDark light-text ownership remains authoritative.
- The probe proves the hero UIImageView itself is transparent while the 640x524 artwork presents with a large white surrounding field. Only that large direct `UIStackView` hero receives a guarded one-time edge-connected near-white backdrop knockout. The transform runs only when the source image edges are substantially opaque near-white; transparent or alternate non-white error art is left unchanged. Because only edge-connected pixels are removed, interior light fur is preserved. The resulting transparent hero sits on OLED black.
- The image operation is cached per assigned hero and runs only on rare CNM error-image assignment/mount. No observer, polling loop, recurring timer, RAF, web-scroll listener, or hierarchy scanner is added.
- All seven explicit-trigger probes are retained and bumped to v7.301 filenames/headers.

# AmazonDark v7.300~person-gift-card-header-error-mask-probe

## v7.300 Gift Card heading + Your Orders error-raster polish

- Built directly from v7.299 and preserves its successful Person offline/error text hydration, exact authored-raster restore, Alexa/Cart/Menu/Search/Home ownership and all seven explicit-trigger probes.
- The v7.299 Person probe proves Gift Card Balance is the only remaining heading outside the normal Person header geometry: its 25pt bold `RCTTextView` is 181x50.7 and is a direct child of exact `RCTView#gctitlettl`, beside a separate reload image. v7.300 adds that exact direct-parent semantic fallback to the existing Person header final-paint owner; the normal wide-header geometry is unchanged.
- The same probe proves the restored Your Orders error asset is an authored 18x20 / 54x60 raster with no UIView/CALayer background. The visible white square is therefore baked into the source pixels, not an AmazonDark floor. v7.300 clips only exact final-raster kind 10 to its own circular 20x20 bounds, preserving the red badge and white exclamation while exposing OLED black outside the circle.
- The circular crop is removed automatically if that recycled raster leaf stops being the exact offline-error owner. No generic Person image rule is widened.
- No MutationObserver, recurring timer, RAF loop, web scroll listener, polling loop, or generic Person hierarchy scan is added.

# AmazonDark v7.299~person-offline-rehydrate-submenu-probe



## v7.299 Person offline/error rehydration parity

- Fixes the exact offline Person fallback state captured by `AmazonDark-v7.297-person-ui-probe-20260903-074257-683-r3.txt`.
- Extends the existing Person heading band only from 410/405pt to 420pt so the probe-proven 414pt offline `*ttl` headings (Buy Again, Your Interests, Lists and Registries) keep the same light final-paint owner as the working 374/390pt headers.
- Adds the exact offline Interests title ID `aiwl_widget_title_errttl` to the existing commerce-section classifier.
- Final-paints only fallback action labels beneath `error-message-container_btn` and `errorListString_btn`, matching the probe-proven working Keep-shopping fallback action gray (`rgb(55,62,62)`) instead of letting them collapse to near-black.
- Restores the probe-proven 18x20 Your Orders offline error raster as authored `AlwaysOriginal` and removes TWB from that exact compact two-child error row; it is no longer misclassified as commerce/product media.
- Retains the v7.298 Person-submenu hybrid full-document probe as the seventh explicit-trigger probe.
- No MutationObserver, recurring timer, RAF loop, web scroll listener, or generic Person hierarchy scan is added.


## v7.298 Person submenu hybrid full-document probe (retained)

- Adds a seventh explicit-trigger probe dedicated to redirected/modal submenus entered from the Person tab.
- Keeps the exact main `RCTScrollView#me` Person probe unchanged; when `meTab` remains selected but that root is absent or physically covered, screenshot/SIGUSR2 routing switches to `AmazonDark-v7.299-person-submenu-hybrid-probe-*`.
- Scans every plausible visible WKWebView (up to six) sequentially, top-to-bottom, with viewport computed-paint snapshots, style-owner inventory, shadow-root/accessible-iframe recursion and a final full DOM inventory; every original WebKit offset/scrollEnabled state is restored.
- Scans every plausible visible non-WebKit native/React scroll root (up to six, ancestry-deduped, excluding the main `#me` root) sequentially top-to-bottom. Full-window snapshots also capture non-scrollable React/native surfaces, layers, borders, SVGs, controls, text-run paint and image/TWB state.
- Uses only the existing screenshot/SIGUSR2 dispatcher. No second trigger source, MutationObserver, timer, RAF, web-scroll listener or recurring runtime hierarchy scan is added.
- The retained v7.298 probe itself changes no production Person/image/WebKit paint ownership; v7.299 production changes are limited to the exact offline/error owners above.

## Alexa Settings + Chat history submenu parity

- Builds directly on v7.295 and retains both Alexa hydration-pill families, durable Plus/Voice circles, Cart fixes, and the frozen v7.280 Person/image subsystem.
- Probe-backed Alexa Settings rows (`conversation_threads.button`, `get_started.button`, `manage_price_alerts.button`) now own every SVG in those exact rows as light, covering the left glyph and right chevron on all three rows without visible-string matching.
- The three dedicated 390x8 Settings separators receive a persistent 1pt `ADBorderGray706()` overlay instead of Amazon's near-white bottom border.
- The Alexa navigation `chevron-down-icon` is now keyed to the stable `MainNavigationHeader-left-button` ancestor rather than one intermediate wrapper, covering the Chat history submenu hydration shown in the screenshot.
- No Person/image, TWB, WebKit ad, Cart, or general React text ownership is changed. No observer/timer/RAF/scroll listener is added.

# AmazonDark v7.295~alexa-hydration2-pills-voice-circle

## Alexa second-hydration parity

- Adds the probe-proven `in-view-wrapper-related_questions_*` / `pillViewStyle` question-pill family to the existing Alexa button owner: gray `#303335` fill, `#747a7c` border, light text.
- Keeps the original `ftuxRuxSuggestionPillList` hydration family unchanged.
- Moves the alternate `TextBoxSearchVoiceComponentButton` physical circle to its exact anonymous 32x32 wrapper using durable fill/mask/ring CAShapeLayers, mirroring the already-working Plus owner.
- Voice SVG background circle remains suppressed; glyph paths remain white.
- Person/native-image ownership and WebKit paint payloads are unchanged from v7.294.

## Saved-for-later swipe-right Move-to-cart text

- Builds directly on v7.293 and retains the Cart p13n refresh anti-flash fix unchanged.
- The v7.292 Cart probe identifies the separate Saved-for-later swipe-right reveal label as `div.swipe-button.swipe-right-button > div`, stock `rgb(17,17,17)` on the AmazonDark black swipe floor.
- Forces only that saved-item swipe-right label to the standard light `#e8e6e3`. The normal gray Move-to-cart AUI button was already correct and is unchanged.
- No observer, timer, RAF, polling loop, web-scroll listener, image/TWB ownership change, or native hook change is added.

# AmazonDark v7.293~cart-p13n-refresh-antiflash

## Cart p13n refresh-transition anti-flash

- Builds directly on v7.292 and retains every Alexa/Person/image fix unchanged.
- Current v7.292 Cart probe identifies the visible refresh-affected recommendation lane as `#p13n-uf-anchor` with 150x249-269 `li.a-carousel-card` slots.
- Hydrated product slots contain `.p13n-uf`; Amazon's established empty loading slots are `.a-carousel-card-empty > .a-loading-static`.
- v7.293 owns the carousel slot itself OLED black from document start and paints only the intermediate non-empty/pre-`.p13n-uf` direct shell `#303335`, eliminating the bright white refresh skeleton without changing hydrated product imagery, text, prices, Prime badges, buttons, or TWB.
- No MutationObserver, timer, RAF, web scroll listener, polling loop, or hydration watcher is added.


## Alexa Plus: durable circular fill

- Built directly from v7.291, where the square backing was eliminated and the Alexa probe fallback was restored.
- The v7.291 Alexa probe proves the anonymous 32x32 Plus wrapper is clipped and retains the gray circular ring, but React later rewrites the wrapper's ordinary background to transparent.
- `PlusMenuButton` remains transparent/glyph-only and its full-size `RNSVGRect` remains hidden.
- v7.292 adds one named `CAShapeLayer` (`AmazonDarkAlexaPlusCircleFill7292`) at the bottom of the exact Plus wrapper's layer stack. It paints the same `ADMenuButtonFill7255()` gray as the microphone and is not owned by React background-color setters.
- Existing wrapper oval mask and standard gray ring remain unchanged.
- v7.291 Alexa screenshot/SIGUSR2 route fallback is retained.
- Person/image architecture is untouched: `UIImageView` and `RCTUIImageViewAnimated` hooks are byte-for-byte v7.291; `ADFloorJS`, `ADTWBJS`, and standalone-ad paint are byte-for-byte v7.291.
- Runtime remains event-driven: no MutationObserver, interval, RAF loop, web-scroll listener, polling loop, or recurring hierarchy scan.

---

# AmazonDark v7.287~v280-person-module-safe-optimizations-alexa

## v7.280 Person module frozen; safe architecture retained around it

- Built from the working v7.286 lineage after confirming v7.286 eliminated the Person bleaching regression.
- The complete v7.280 Person production module is restored byte-for-byte, not only its raster/image helpers.
- The complete v7.280 non-Alexa explicit-trigger probe implementations are restored; only filenames/headers are bumped to v7.287.
- v7.286 safe non-Person architectural improvements remain: optimized build/dead-strip flags, conditional promotion/privacy hook installation, WebKit program/cache consolidation, 120 Hz bookkeeping improvements, non-Person ownership/cache cleanup, keyboard/location/status-bar/runtime cleanup, deterministic Hamburger first-paint repair, async splash-snapshot purge, and preference/SpringBoard cleanup.
- Alexa-specific production ownership from v7.285/v7.286 remains: exact white header glyphs, gray bottom circular controls with white glyphs, gray chat-history border, and lower-two suggestion-image TWB while preserving the top authored glyph.
- No v7.282 shared image writer is present. No MutationObserver, setInterval, RAF loop, or web scroll listener is added.

# AmazonDark v7.286~v285-compile-repair

## Compile-only repair on the v7.285 / v7.280-image-baseline architecture

- Built directly from v7.285.
- Fixes the single GitHub/Theos compile error in `ADMenuRoot7255`: `ADClassNameIs7183` expects a C string (`const char *`), so the Menu compatibility helper now passes `"RCTScrollView"` instead of Objective-C `@"RCTScrollView"`.
- No Person/image classifier, raster writer, rendering-mode owner, TWB decision, `UIImageView` hook, or generic image ownership path is changed.
- Alexa UI ownership and all safe post-v280 optimizations from v7.285 are retained.
- Existing retain-cycle diagnostics in explicit-trigger probes are unchanged; they are warnings and are not part of steady-state production painting.

# AmazonDark v7.285~v280-person-baseline-safe-optimizations-alexa

## Hard v7.280 Person/image baseline + safe post-v280 architecture + exact Alexa UI

- **Hard visual baseline:** the complete v7.280 native Person/image pipeline is retained byte-for-byte. This includes the dedicated image mutation guards, Person-root/media classifiers, final `AlwaysOriginal`/template transactions, native TWB eligibility, and the production `UIImageView` hook.
- The v7.282 generic image-writer consolidation is intentionally **not** ported. `gADImageWriteDepth7271` / `ADSetImageRenderingMode7271` and every post-v280 hunk that changes Person/native-image routing, rendering mode, classifier caching, or final image ownership remain excluded.
- The v7.280 `RCTUIImageViewAnimated` production path is retained exactly except for one Alexa-only suggestion-card side lane. The first 40x40 authored Alexa palette glyph is left untouched; only the second and third 40x40 product rasters receive the configured TWB.
- Exact Alexa controls from the v7.282 probe are ported: header close/overflow/chat-history SVG glyphs render white; Plus/voice controls use a dark-gray circular backing with white glyphs; the `pillViewStyle` chat-history border uses the established gray edge.
- Safe v7.282 architecture is replayed where it cannot alter those image contracts: `-Os`/function-data sections/dead stripping, rootless preference simplification, cached fixed colors/classes/selectors, cursor queues, consolidated document-start WebKit core, positive non-image React ownership caching, typed status-bar IMP storage, 120-Hz bookkeeping reduction, keyboard/location/text/helper cleanup, probe path/append/dispatch compaction, and launch/SpringBoard/preference-bundle cleanup.
- The deterministic Hamburger first-paint owner at the exact React `setBorderRadius:16` commit is retained; v7.280's temporary continuously populated Menu lifecycle diagnostic ring is removed.
- The approved Force 120 Hz behavior/settings wording remains unchanged.
- Runtime stays event-driven: no MutationObserver, interval, RAF loop, web-scroll listener, polling loop, or recurring hierarchy/DOM scan.

# AmazonDark v7.280~wide-forensics-probe

**Diagnostic-only branch from the v7.278 production baseline.** v7.279 production changes are intentionally not included.

- Production theming/ownership is v7.278.
- Hamburger probe retains the full native/WebKit walk and adds a bounded in-memory pre-trigger lifecycle ring for footer-sized RCTView/RNCEKV events.
- Product `/s` probe is widened from four known families to all current/near-viewport DOM nodes (computed paint, pseudo-elements, media, technical attributes, ancestry) plus a painted/rounded candidate inventory and viewport hit grid.
- No observer, timer, RAF, web-scroll listener, polling loop, or recurring DOM scan is added.


## Hamburger first-paint: bridge the actual RNCEKV host attachment

- v7.277 r1 proves all three exact action leaves are already correctly transparent while the 406x48.7 visible surfaces remain stock white.
- The exact physical chain is action `RCTView#account_switcher` / `#so` / `#cs` -> direct `RNCEKVExternalKeyboardView` -> inner RCTView -> 406x48.7 visible surface -> 410x52.7 wrapper.
- v7.277 could still run its exact-leaf ancestor pass before the RNCEKV-hosted subtree had been attached high enough to expose the 406/410 owners. The leaf then need not receive another move/ID event when its wrapper is attached upward.
- v7.278 uses the existing RNCEKV hook as the missing bridge: on wrapper `didMoveToSuperview`, `didMoveToWindow`, and `setFrame:`, it checks direct children only for one of the three exact footer action IDs and reuses the existing <=7 ancestor owner.
- No timer, observer, downward hierarchy scan, scroll listener, RAF, delayed retry, or new hook class is added. Non-footer RNCEKV wrappers perform only a tiny direct-child ID check.
- v7.277 local/root-independent ownership remains; the failed v7.276 2,048-node root scan remains removed.
- All other v7.277 theming, probes, Brands rails, SWV video, avw36 strip, Search fixes, and Force 120 Hz behavior/settings copy remain unchanged.

# AmazonDark v7.277~footer-local-owner

## Hamburger footer first-paint: exact local ownership

- The new v7.276 bad/good probe pair proves the three 406x48.7 footer surfaces are never owned at all on the bad first paint: they remain stock white, unclipped, layer-borderless, and retain Amazon's teal React border while the exact `account_switcher` / `so` / `cs` action leaves are already present and already transparent/gray.
- Re-entry changes those same physical 406x48.7 views to the intended OLED fill, one gray edge, radius 16, and clipping. This rules out a late Amazon overwrite of a successful AmazonDark paint pass; the first pass simply never classifies the visible surface.
- v7.277 removes the remaining dependency between footer ownership and `scrolled-hamburger-view` root timing. The three exact footer action IDs are now locally authoritative. From one exact action leaf, AmazonDark walks at most seven existing ancestors and recognizes only the probe-proven 406x48.7 visible surface and 410x52.7 outer wrapper.
- The visible 406x48.7 surface is OLED black with the established single gray edge/r16/clipping; the 410x52.7 wrapper and 404x46.7 action leaf remain transparent/no-border.
- The local footer role is evaluated before general Menu-root classification and is also used by the existing RCTView background setter path, so a stock white React background assignment can be replaced even if the Menu root has not become authoritative yet.
- The v7.276 depth-14 / 2,048-node downward Menu-root scan is removed completely. No replacement scan, timer, observer, polling, RAF, web scroll listener, or new hook class is added.
- Search Brands-carousel OLED vertical-rail fix, exact SWV video TWB, `avw36` stage strip, Search magnifier/divider repair, and all six probes remain retained.
- **Force 120 Hz** remains behaviorally unchanged. Its settings description now reads: “Forces 120 Hz on supported ProMotion displays for smoother scrolling and animations. Depending on the device or the device’s current thermal state, forcing a higher refresh rate may increase battery use and can adversely affect performance or make it worse rather than improve it.”

# AmazonDark v7.275~brand-rails-menu-first-paint


## v7.275 Brands carousel rails + deterministic Hamburger footer first paint

- Search `/s` Brands-related `_bXVsd` multi-brand cards keep the established OLED floors, TWB media, copy, Sponsored treatment, and outer neutral framing. Only internal left/right border ink is changed from `#494d4d` to OLED black, eliminating the visible gray vertical rails between brand tiles while preserving top/bottom/outer borders.
- The v7.270 Hamburger footer repair remains, but is hardened for the complementary lifecycle ordering: if `account_switcher`, `so`, or `cs` receives its accessibility identifier after mounting, the existing bounded `ADMenuPrimeFooterAncestors7270()` repair runs immediately. Existing move/superview/layout paths still cover ID-before-window construction. No timer, observer, polling, new hook class, or hierarchy scan is added.
- The compact `/s` probe now includes the already-proven `_bXVsd` family so Brands carousel border paint can be verified without restoring the old multi-megabyte Search probe.
- v7.273 exact SWV video TWB and v7.274 `avw36` stage-strip treatment remain unchanged.

Direct production/video baseline: **optimized v7.270**.


## v7.274 compact product-scroll probe + SWV stage strip

- Keeps the v7.273 exact SWV/1m98b video overlay TWB owner.
- Darkens only the SWV navigation strip (`8wyx7 > avw36`) from Amazon's translucent near-white plate to `#4a4f51`; its three button states and authored divider pseudo-elements are left untouched.
- Replaces the oversized product-scroll forensic dump with a compact explicit-trigger current-view inventory for `8wyx7`, `1m98b`, and `avw36`. No cross-frame dump, hit grid, scrolling, observer, timer, RAF, or recurring scan.

## v7.273 exact SWV video repair

- Probe-confirmed current untamed Search-results video is a distinct host family: `_mediaSection_8wyx7_` / `_videoPlayerContainer_8wyx7_` / `_videoWrapper_8wyx7_` containing the reused `_videoContainer_1m98b_` player.
- The captured video leaf is filter-free and the sibling `_videoOverlay_1m98b_` plane is transparent. The captured page does not expose the older `template=FEATURED_ASINS_VIDEO_LIST` host used by the v7.270 rule.
- All v7.271/v7.272 video-selector broadening is removed. The complete v7.270 ADTWBJS video behavior is restored first.
- One exact new TWB selector is added: only an `_videoOverlay_1m98b_` directly inside the `8wyx7` video-player/wrapper path receives the configured TWB shade. The VIDEO compositor remains filter-free and controls remain authored by Amazon.
- Retains the non-video Search magnifier restoration and exact neighboring-button gray divider correction.
- Retains the explicit-trigger product shopping/scrolling probe behind the existing probe dispatcher. No second screenshot observer or SIGUSR2 source is added.
- No MutationObserver, interval, RAF loop, web scroll listener, or recurring production scan is added.

---

# AmazonDark v7.272 — Product-scroll video parity + restored Search-results probe

- Direct base: v7.271 optimized regression repair.
- Restores the historically proven Search `single-video-card` / Video.js (`video.vjs-tech` + `.vjs-poster`) media family to the `/s` TWB lane using the existing configured TWB factor.
- Matches the product-scroll vertical ribbon divider to the adjacent control borders exactly (`#747a7c`).
- Re-adds a dedicated `/s` product shopping/scrolling forensic probe. It is routed through the existing screenshot/SIGUSR2 dispatcher, performs no scrolling, and adds no second listener/signal source or recurring runtime work.
- Home / Person / Cart / Menu / Alexa probes remain retained.

# AmazonDark v7.271~search-video-chrome-regression-fix

Direct base: **v7.270~optimized-exact-probes**.

## Regression repair

- Restores the product-results Search magnifier by retaining both live exact native renderers: `SBSearchBarIconView` in `SBSearchBarLeadingStackView`, plus the bounded leading-image slot under `SBSearchField` / `SBMultilineSearchView`.
- Restores Search sponsored-video TWB without filtering the playback compositor directly: `_c2Itd_videoOverlay_*` and the exact `template=FEATURED_ASINS_VIDEO_LIST` `_videoOverlay_*` roles are now matched independently of transient CSS-module hash suffixes.
- Recolors the exact `sf-rib30-dropdown-main-container` left divider under the Search bar to the standard AmazonDark gray `#494d4d`.
- Retains the optimized v7.270 event-driven architecture and all five dormant probes; no observer, timer, RAF loop, web scroll listener, or recurring scanner is added.

---

# AmazonDark v7.270~optimized-exact-probes

## v7.270 maximal optimization sweep

- Preserves the v7.270 visual contract and all five explicit probes (Home, Person, Cart, Hamburger, Alexa/Rufus).
- Removes the dead Hamburger helper and collapses the three exact footer action IDs behind one predicate. The first-open footer repair now rejects every non-footer RCTView before any Menu ancestry/classification work.
- Makes Search delivery ownership singular: the current probe-proven `GlowIngressView` is authoritative; the old `ANXSubNavContainer` and `nav_packard_bar` alternate owners and their generic `UIView` hot-path checks are removed.
- Makes the main Search magnifier exact to `SBSearchBarIconView` inside `SBSearchBarLeadingStackView`; the old geometry/field alternate path is removed.
- Narrows compact standalone media TWB to the current probe-proven `#dynamic-bb [data-acei-id=prod-img]` lane and removes the broad compact media sweep plus the legacy `lfstyl-img` lane.
- Keeps the active Highlights wrapper-only TWB path but promotes it to an exact owner (recent Person probes still show this renderer). No visual behavior is dropped there.
- Centralizes native TWB overlay creation/update and gives Menu `subtheme_image_*` one exact overlay path instead of a generic-pass-plus-secondary path.
- Person section headings now use only the current probe-proven final text-renderer geometry; the nested `*ttl` alternate hydration path is removed.
- Probe dispatch uses only current native tab IDs: `home`, `meTab`, `cartTab`, `menuTab`, `rufusTab`. No probe is removed.
- Retires the old generic React “bright card near text” heuristic. Person, Hamburger, location, AppCX sheets, and savings sheets now rely on their exact surface owners instead of a seven-ancestor size/color claim on ordinary React text updates.
- Positive Person/Hamburger surface classifications are cached on the view until normal React move/reuse invalidation, avoiding repeat root walks on stable views.
- Hamburger raster classification now rejects every non-`RCTUIImageViewAnimated` leaf before Menu-root/ancestor work; the current Menu probe shows these are the actual raster leaves for featured programs and expanded subthemes.
- Footer IDs are compared directly with no temporary lowercased string allocation.
- Production remains event-driven: no MutationObserver, interval, RAF loop, web scroll listener, polling loop, or recurring hierarchy scan.

## v7.270 hamburger footer first-paint repair + retained Alexa/Rufus comprehensive probe

- Fixes the Menu first-open race where `Switch Accounts`, `Sign Out`, and `Customer Service` can show stock white inner surfaces until leaving and re-entering the tab.
- Bad/good probe diff shows the exact 406x48.7 footer surfaces are present in both states. In the bad first render their UIKit paint is still white/uncommitted; in the good re-entry they are OLED black with the intended single gray edge and r16.
- Root cause is lifecycle ordering: the footer parent can run its paint hook before the identifying `account_switcher` / `so` / `cs` descendant exists, so it is not classified as the footer surface on that pass. A later re-entry/layout supplies the missing pass, explaining why the second state is correct.
- v7.270 uses the already-hooked lifecycle of those three exact action leaves to re-own only their local footer ancestors as soon as the hierarchy is complete. No observer, timer, polling, scroll hook, or document scan is added.
- Keeps the v7.269 outer standalone-ad border de-duplication and the comprehensive Alexa/Rufus probe unchanged.

- Fixes the newly introduced double-border regression on structured 414x125 standalone Home ads. The v7.268 Home probe shows the top-level `ape_gateway_dynamic-…_mshop_placement` is 430x129.8 and carries a 1px `#3b4043` edge, while the child `modern-414x125-layout-container` independently carries the correct rounded 1px `#3b4043` edge. The outer APE edge is therefore duplicate renderer chrome.
- Removes only that top-level structured 414x125 APE placement border/outline/shadow. The child renderer border remains unchanged and is the sole visible ad frame. Full-raster borderless handling, medium/XL divider removal, Sponsored feedback, TWB, and compact-price parity are retained.
- GitHub history review found v7.162 (`54a8764`) as the clearest earlier Alexa/Rufus paint reference: Search Rufus surfaces were explicitly owned OLED black with gray borders, and the `nice-widget-container-inline-slot` Alexa surface required both its normal background and `::before`/`::after` painters to be neutralized. That evidence is used to shape the new probe, but this build does not guess at or change the current Alexa-tab visuals yet.
- Adds an Alexa/Rufus probe gated to the selected native `ANXTabBarButton#rufusTab`. It scores every visible WKWebView for Rufus/Alexa/assistant/conversation/chat/Nile signatures, inventories stylesheet owners and AmazonDark injected owners, performs finite viewport snapshots plus a final full DOM inventory, recurses through open shadow roots/accessibly reachable iframes, and records computed text/fill/background/image/mask/border/radius/outline/shadow/font/SVG/filter/transform/pseudo-element/media state.
- The same Alexa trigger also inventories native UIKit/React ownership: all native scroll candidates, complete view ancestry/geometry, backgrounds/tints/layer borders, sublayer samples including shapes/gradients, RCT border properties, attributed-text runs, controls, image/TWB state, and a finite top-to-bottom native scroll walk. WebKit/native offsets and `scrollEnabled` are restored after capture.
- The Alexa probe records no visible strings, accessibility-label text, aria-label/alt/value contents, URLs, or network payloads; it retains technical identifiers and privacy-safe text lengths/hashes only.
- No MutationObserver, interval, RAF loop, web scroll listener, or recurring hierarchy scan is added. All probe work remains screenshot/SIGUSR2-only.

## v7.268 compact standalone current-price text parity

- Fixes the compact structured/non-full-raster standalone ad current price painting stock dark on the OLED card.
- The v7.267 Home probe proves this compact renderer uses `#dynamic-bb` and an exact `data-acei-id="prc"` current-price lane rather than the medium/large `data-testid="price-container"` contract.
- Only `#symbolOne`, `#price-integer`, and `#price-fraction` directly under that `prc` lane are forced to the normal light neutral text.
- The authored discount percentage remains red, and the struck-through list-price metadata remains secondary gray. Product title, images, Sponsored chrome, borders, and raster/full-raster classifiers are unchanged.
- Retains both v7.267 fixes: XL full-raster divider removal and OLED-black Home hero backdrop planes.
- No MutationObserver, timer, RAF loop, scroll listener, or recurring scan is added.


## v7.267 XL full-raster divider + Home hero backdrop OLED lock

- Fixes the XL/300x250-style standalone full-raster white strip captured in the v7.266 Home probe. The probe proves it is the same authored `DIV.border-enforcement` chrome (`430x2`, `1px solid #ccc`) seen on the medium raster case, but this XL renderer lives directly in the main Home document rather than a standalone child frame.
- Adds a narrow Home-only structural selector for `creative-container` instances with a direct `IMG.ad-background-image.mrc-btr-creative`, hiding only their `.border-enforcement` (plus pseudo-elements). No raster pixels, TWB strength, Sponsored feedback, or structured product-ad borders are changed.
- Locks both Home hero-derived backdrop planes — `#wd-backdrop-overscroll` and probe-confirmed `#wd-color-image-backdrop` — to OLED black. Actual hero images/video/cards remain untouched.
- Retains all v7.266 fixes, including medium full-raster divider removal, structured standalone gray border parity, one-shot full-raster parent proof, and repaired Home current-frame probe.
- No MutationObserver, interval, RAF loop, scroll listener, automated scrolling, or recurring full-document scan is added.

## v7.266 Home standalone border parity + full-raster divider + hero overscroll + Home probe repair

- Restores the established gray edge on structured/non-full-raster 414x125 standalone ads. v7.265 removed the broad medium placement rule while making raster ads frameless, which allowed Amazon's stock white renderer border to show again.
- Keeps every structurally-proven full-raster standalone ad frameless at every size. A full-raster child sends a one-shot proof message to its exact parent iframe/APE placement so outer parent chrome is cleared without guessing from size.
- Hardens the medium full-raster separator repair: `.border-enforcement` is hidden, its pseudo-elements are suppressed, and the proven full-raster child clears renderer/container borders using inline `!important` ownership.
- Locks the dedicated Home `#wd-backdrop-overscroll` plane to OLED black, so pulling past the top cannot expose the active hero card's average campaign color. The normal `#wd-color-image-backdrop` and hero artwork remain Amazon-owned.
- Repairs the v7.265 narrow Home probe regression. `removeAllUserScripts` cleared the actual script but v7.265 left the probe association set, so the bridge was not re-added and captures returned `bridge-missing` / `collector-missing`. v7.266 resets that association and self-heals the main-frame bridge at explicit trigger time.
- No MutationObserver, interval, RAF loop, scroll listener, automated scrolling, or full Home-document scan is added.

## v7.265 Person refresh text + borderless full-raster + narrow Home probe

- Keeps v7.263's Person refresh/remount image recovery and v7.264's standalone raster taming.
- Fixes Your Orders card headers after Refresh/Retry. Historical Person evidence identifies the exact leaf as `RCTTextView#ImageWithTextViewTextComponent` under `yo_btn` / `YoAsinCarouselItem*`; v7.265 reasserts only that lane at final draw so the delivery-date header cannot revert to stock dark text during React rehydration.
- Full-raster standalone ads are frameless at every size. The previous `.ape-placement.is-image-oo` outline is removed; the historical `.border-enforcement` 430x2 medium strip has its actual border removed, not merely recolored; dominant-raster child frames also clear renderer/container chrome. Structured Swiper/product-card borders are retained because those are not full-raster creatives.
- Adds a Home current-frame probe: no scrolling and no full-document DOM inventory. It records only native views intersecting the current screen plus DOM branches intersecting the current viewport, and requests the same bounded snapshot from child frames.
- All probes remain screenshot/SIGUSR2-only. The Home all-frame bridge is dormant except for a probe request and performs no normal-runtime scanning.

## v7.262 Hamburger footer inner-surface parity

- The v7.261 Menu probe proved the three footer actions are nested: a 410x52.7 outer border wrapper contains a 406x48.7 React surface, which contains the 404x46.7 action leaf.
- The visible white fill and stock teal edge belong to the 406x48.7 middle surface. v7.262 makes that exact surface OLED black with the standard #494d4d 1pt/r16 treatment.
- The 410x52.7 wrapper and 404x46.7 action leaf are transparent/no-border so they cannot create duplicate edges or square fills.
- Text/glyph behavior remains the same as the surrounding Menu cards; no SVG/RNSVG taming behavior changed.


## v7.263 Person refresh image re-tame

- Probe-backed root cause: refreshed Buy Again product raster leaves are `ANXFastImageView` nodes at depth 31 below the Person `RCTScrollView#me` root. The old Person classifier stopped after 24 ancestors, so refreshed leaves fell out of Person scope, were marked media-blocked, and lost TWB.
- Extends only the finite Person ancestor budget from 24 to 48. This remains lifecycle/event driven; no observer, timer, recurring hierarchy scan, web scroll listener, or global React sweep is added.
- Clears the cached React-surface classification when image views receive a new image or move between window/superview owners, including the `RCTUIImageViewAnimated` override path. This prevents recycled refresh leaves from inheriting stale non-Person scope.
- Leaves the TWB strength, media eligibility rules, authored-image exclusions, Person text/glyph fixes, Cart fixes, and v7.262 Hamburger footer ownership unchanged.


## v7.297
- Fixes the Alexa Chat history upper-left back glyph using the probe-proven `chevron-left-Variant-icon` owner under `MainNavigationHeader-left-button-back`.
- Retains the existing `chevron-down-icon` owner for the other Alexa header hydration.
- No Person/native-image/WebKit paint architecture changes.
