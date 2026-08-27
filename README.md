## v7.139 search-results regression repair probe

- Restores stock v7.136 Heart/More-like-this action controls by excluding their exact subtrees from the v7.137 Search structural/text owners.
- Removes the proven parent-level `sf-rib30-dropdown-pill-icon` compositor filter that turns authored orange ReviewStarIcon.svg art into white boxes; Prime and review-star pill artwork are explicitly left unfiltered.
- Stops treating the `puis-product-insight-prompt-alexa-plus-logo` semantic logo span as a structural floor, preserving its authored Alexa artwork.
- Adds exact, geometry-gated ownership for the compact native `ANXVisualSubNavViewController` / `ANXSubNavContainer` delivery strip: OLED-black floor, existing light text, and light templated image glyphs. The older warm-color detector remains only as a fallback.
- Retains the successful v7.137 Overall Pick lane and Search-result OLED/TWB changes.
- The screenshot/SIGUSR2 probe now captures the top native band plus parent chains for ribbon art, Alexa logo and More-like-this controls.

## v7.138 search-results regression fix probe

- Removes all v7.137 Heart / More-like-this quick-action styling.
- Restores Amazon-authored Prime and review-star sprite/SVG imagery in the Search filter ribbon while keeping ribbon floors dark.
- Excludes Rufus/Alexa/research icon families from generic neutral-glyph filtering so the Researched by Alexa mark keeps its authored color/detail.
- Retains v7.137 OLED Search/result floors, Overall Pick black lane, Search-result TWB, and verification probe.

# AmazonDark v7.137~search-results-pane-fix-probe — Search results + Researched by Alexa dark parity

Directly based on v7.136. This pass targets the current `/s` search-results surface shown in the supplied spider-wood screenshot. The existing v7.136 GWM spinner-center fix, v7.135 third-party-video restore, Search transition/keyboard work, Privacy Mode, Sponsored handling, borders and Home/PDP theming are retained.

The Search results document now has a dedicated static documentStart CSS lane. Structural Search/result/Alexa-for-Shopping shells are OLED black, neutral copy is light, the location/delivery strip is a medium neutral gray, and the filter ribbon/pills are dark with light neutral glyphs. Prime branding and star/rating accent painters are explicitly excluded from generic recolor/filter ownership so Prime stays blue and rating stars stay orange. Add-to-cart/button, deal/coupon and Sponsored families are also excluded from the broad neutral owners.

The historical exact `spider wood` search probe identifies the product-card control families used here: `.puis-status-badge-container` for the Overall Pick lane, `.lists-framework-action-button.puis-heart-icon-container` for the heart, and `.mlt-icon-container` / `.mlt-image-icon` for More like this. v7.137 forces the Overall Pick status lane black and gives the heart/More-like-this circular shells a light-gray fill while preserving their actual artwork. Search-result/category imagery gets TWB through a declarative `#search img` lane with Prime/star/logo/icon/glyph exclusions, so the new Researched-by-Alexa thumbnails are tamed without dimming brand/rating accents.

The former spinner verification probe is removed from the installed path and replaced by a screenshot/SIGUSR2 Search-results verification probe: `AmazonDark-v7.137-search-results-pane-fix-probe.txt`. It records only class/id/geometry/computed paint for Search/result/filter/location/Alexa/badge/action/media families and bounded hit stacks; typed query text, element text and outerHTML are deliberately not captured. No MutationObserver, interval, RAF, scroll listener, touch listener, or recurring DOM scan is added.

# AmazonDark v7.136~spinner-wheel-fix-probe — exact GWM white-center repair

Directly based on v7.135, preserving the v7.135 AT&T/Flashtalking video restore, Search fixes, Privacy Mode behavior, TWB, Sponsored handling, and all existing dark-floor rules. The v7.135 screenshot probe was captured directly on the visible white-filled wheel and identified a third current Home loader family that was not covered by the existing `_hp-mosaic-container_style_loadingSpinner...` rule.

The visible painter is `div#gwm-CardLoadingIndicator.gwm-LoadingIndicator` (about 45x45 pt). Its element background is transparent while its rotating outer artwork is a light linear gradient; `::before` is also light and belongs to the rotating ring. The defect is isolated to `::after`, which computes to a solid white `rgb(255,255,255)` circular center. v7.136 adds one documentStart CSS rule only for `#gwm-CardLoadingIndicator.gwm-LoadingIndicator::after`, forcing that center disc to OLED black while leaving the outer gradient, `::before`, geometry, and Amazon's existing 1-second rotation untouched.

This is independent of Privacy Mode. The captured failing frame reported `privacyMode=1`, but the white fill is directly owned by the loader's CSS pseudo-element and predates the Privacy Mode work. No privacy/network behavior is changed.

The screenshot/SIGUSR2 probe is retained for one verification pass and renamed to `AmazonDark-v7.136-spinner-wheel-fix-probe.txt`. A fixed-state capture should show the same `#gwm-CardLoadingIndicator.gwm-LoadingIndicator` with `::after` background black instead of white. The probe remains manual-only; no MutationObserver, timer, interval, RAF, scroll listener, or recurring scan is added.

# AmazonDark v7.135~att-video-restore-probe — third-party video compositor restore

Directly based on v7.134. The supplied v7.133 screenshot/probe shows the blank large Sponsored slot still has its full 430x358 `ape_gateway_dynamic-2-1_mshop_iframe` / `ape-placement` geometry mounted. Historical v7.106/v7.107 device evidence identifies the matching large third-party path as an Amazon SafeFrame containing `#mobile-third-party-ad` -> Flashtalking -> a nested 300x250 AT&T creative. That means the current failure is inside the creative/compositor path, not a collapsed Home layout or missing APE placement.

v7.135 removes AmazonDark's whole-subtree `filter:brightness(...)` ownership from `#mobile-third-party-ad` in both TWB owners. A filter on the outer host forces the entire cross-origin HTML5/video subtree through a filtered compositing surface; the current symptom is exactly a fully black creative while the outer APE iframe remains visible. The final `*.flashtalking.com` creative document is now also excluded from AmazonDark floor/standalone/TWB injection, so its own video/canvas/HTML renders stock while the surrounding Amazon SafeFrame and separate Sponsored feedback row keep normal AmazonDark treatment. No geometry, iframe size, display, visibility, opacity, autoplay, media URL, or hit target is changed.

This deliberately favors a visible stock third-party video over applying TWB to the entire video subtree. First-party standalone ads, compact/medium/large product ads, 300x250 Swiper cards, ordinary Home media, Sponsored text/glyphs, Search fixes, keyboard fixes, and spinner theming are unchanged. Privacy Mode is not weakened in this build; the retained spinner screenshot/SIGUSR2 probe now records `privacyMode=0/1` so a still-blank ad immediately tells us whether the optional ad-measurement blocker is active.

The v7.134 white-spinner diagnostic remains installed, with output renamed to `AmazonDark-v7.135-spinner-wheel-probe.txt`. It remains screenshot/SIGUSR2-only and adds no recurring scan, observer, timer, RAF, or scroll listener.

# AmazonDark v7.134~spinner-wheel-probe — white-filled loading wheel capture

Directly based on v7.133. This is a diagnostic-only build for the intermittent white-filled loading wheel. The existing v7.133 Search transition-backing fix is preserved, but the temporary Search probe is removed and replaced with a screenshot/SIGUSR2 spinner probe. The current spinner theming is intentionally not changed so the report captures the failing painter exactly as rendered.

Historical v7.0.78/v7.0.80 evidence identified two different Home loading renderers: the `_hp-mosaic-container_style_loadingSpinner...` ring whose `::after` can paint a white center, and `span.a-spinner.a-spinner-medium`, an AUI sprite-backed wheel. Current v7.133 already retains the first renderer's black-center rule, but not the later v7.0.80 AUI sprite replacement. v7.134 therefore inventories both known families plus current spinner/loader/loading/progress semantics and bounded lower-center `elementsFromPoint()` stacks before any new fix is attempted.

The probe runs only when an iOS screenshot is taken or SIGUSR2 is sent. It inspects up to six visible tracked WKWebViews, performs one bounded semantic `querySelectorAll` per captured WebView and 13 fixed `elementsFromPoint()` stacks, and records native activity/loading/progress classes. There is no MutationObserver, timer, interval, RAF, scroll listener, touch hook, or recurring scan. Output: `AmazonDark-v7.134-spinner-wheel-probe.txt`.

# AmazonDark v7.133~search-gap-floor-probe — Search opening/release white-gap floor

Directly based on v7.132. The v7.132 screenshot probe caught a persistent full-screen stock-white plain `UIView` underneath the already-black Search autocomplete WebView and keyboard host. Search normally covers that plane, but its height changes while Search opens and when a held row is released, briefly exposing the white underlay. v7.133 does not add a broader scan: it marks only exact plain `UIView` candidates already discovered by the existing bounded v7.129 transition-wrapper pass, then uses the already-present `UIView` lifecycle/background setter hook to keep those marked backing planes OLED black if Amazon writes white later.

The Search row fix from v7.132, v7.130 loading/platter fixes, v7.126 keyboard ownership, Deals-for-you, Privacy Mode, Sponsored handling, TWB, product-image protections, and all other visual behavior remain unchanged. The screenshot/SIGUSR2 probe is retained as `AmazonDark-v7.133-search-gap-floor-probe.txt` and now reports `transBack=1` for a backing plane owned by this exact lane. No MutationObserver, timer, interval, RAF, recurring DOM/native scan, new global hook, or keyboard compositor change is added.

# AmazonDark v7.132~held-query-row-fix-probe — held Search query-row floor

Built directly from v7.131. The v7.131 screenshot/probe confirms the visible Search autocomplete WebView itself is already OLED black, while the `YOU MAY BE INTERESTED` query-row family is separate from the older `.s-suggestion-container` rules. The exact row geometry is 430×38 via `.s-query-row`, with `.s-query-row-container` and `.s-query-row-link` structural descendants. During a long press Amazon paints that row-state surface white; the inner `.s-query-row-text` remains black, which is why the screenshot shows a full-width white strip with a black rectangle immediately behind the label.

v7.132 gives only those exact query-row structural surfaces an OLED-black background in normal and pressed/focused states and disables their tap-highlight overlay. No generic DOM floor sweep, MutationObserver, timer, RAF, polling loop, touch listener, or recurring scan is added. Existing keyboard, transition, Deals-for-you, Sponsored, product-image, and microphone behavior is unchanged.

The one-shot screenshot/SIGUSR2 probe is retained as `AmazonDark-v7.132-held-query-row-fix-probe.txt` and now explicitly captures `.s-query-row`, `.s-query-row-container`, `.s-query-row-link`, `.s-query-row-text`, plus a hit point through the third query row.

# AmazonDark v7.130~transition-floor-probe — exact loading overlay + platter + keyboard placeholder owners

Directly based on v7.129. The new Home→Cart screenshot/probe proves the v7.129 generic transition shells and destination WebKit backings are already OLED black while the visible white screen remains. Hit testing lands at every sampled content point on `AWLoadingIndicatorWidgets_BkgView <- AWLoadingIndicatorFullScreenModalBar`, so v7.130 owns those exact Amazon loading surfaces as OLED black and adds a black backing sublayer beneath their child content. The yellow loading/progress strip remains Amazon-owned. `AWLoadingIndicatorWidgets_LoadingText` is explicitly light.

The held autocomplete row fix is corrected rather than broadened globally. The previous gate incorrectly required `_UIPlatter*` to be an ancestor/descendant of `WKContentView`/`WKWebView`; the probe shows UIKit portal-mounts the platter alongside WebKit compositing views. v7.130 gates exact `_UIPlatter*` classes in `AppCXWindow` by row-sized geometry, paints the platter backing black, and intercepts only bright-neutral plain `UIView` children that actually live under a platter. No general bright-UIView repaint is added.

The lower white block exposed when the keyboard disappears is now owned at the two exact lower keyboard surfaces seen in the probe: `UIInputSetHostView` and `_UIRemoteKeyboardPlaceholderView`. `UIInputSetContainerView` remains untouched. Unlike the failed v7.121/v7.122 compositor experiment, v7.130 applies no color-matrix/filter and no full-screen text-effects paint. The lower host/placeholder are allowed to take OLED backing only while their local `UIKeyboardDockView` is actually hidden, so normal keyboard presentation stays on the existing v7.126 OledKeyboard path.

All v7.127/v7.128 microphone geometry edits remain absent. No MutationObserver, polling loop, recurring timer, RAF, interval, or web scroll listener is introduced. The screenshot/SIGUSR2 probe remains and writes `AmazonDark-v7.130-transition-floor-probe.txt`.

---

# AmazonDark v7.129~transition-floor-probe — OLED transition backings + held-row platter

Directly based on v7.128, with **all v7.127/v7.128 microphone/dock-item geometry edits removed**. The keyboard implementation is back to the unchanged v7.126 OledKeyboard-derived ownership model: no `UIKeyboardDockItemButton` hook, no microphone image inset, and no edit to the left/right dock glyph geometry.

The v7.128 held-row probe identifies two independent stock-white owners. First, the long-pressed autocomplete row is covered by WebKit's UIKit text-selection platter: `_UIPlatterSoftShadowView` contains a plain `UIView` painted pure white. v7.129 owns only bright neutral, raster-free plain-UIView backing children inside a WebKit platter and removes the platter's bright shadow; selected text/portal content is left alone.

Second, the large white region below autocomplete is **not the v7.126 keyboard floor**. The keyboard dock is already OLED black but hidden while `_UIRemoteKeyboardPlaceholderView` remains transparent. The exposed app hierarchy contains large stock-white `UILayoutContainerView` / plain-`UIView` transition backing planes. v7.129 owns only large primary-Amazon transition/container/wrapper shells plus their shallow large plain-`UIView` backing children as OLED black. It does not add a global `UIView` painter and does not paint `UITextEffectsWindow`, `UIInputSetContainerView`, `UIInputSetHostView`, or `_UIRemoteKeyboardPlaceholderView`.

WebKit first-frame ownership is also hardened without a runtime scan: a `WKWebView` is primed on init and `didMoveToSuperview`, later white `backgroundColor`/`opaque` assignments are intercepted, the exact `WKScrollView` backing is held black, and transition-live tracked WebViews are considered active when they have either a window **or a superview**. This ports the lightweight pre-attachment lesson from the v6.0.160-era anti-flash work without bringing back Dark Reader, MutationObserver, timers, RAF, polling, or document-wide rescans.

The one-shot screenshot/SIGUSR2 diagnostic is retained as `AmazonDark-v7.129-transition-floor-probe.txt`.

---

# AmazonDark v7.128~search-ui-probe — press-stable keyboard microphone alignment

Directly based on v7.127. The Search photo/camera top-seam correction, OledKeyboard-derived OLED keyboard ownership, Search heading/location/glyph treatment, Privacy Mode, launch cover, 120 Hz, JIT, standalone-ad handling, and TWB behavior are unchanged.

The v7.127 before/during/after device probe proves both `UIKeyboardDockItemButton` hit-target frames remain fixed across the microphone press. The visible jump is therefore inside the right button's rendered microphone content. v7.127 applied the measured 5.5pt downward `imageEdgeInsets` correction only from `layoutSubviews` and only after `ADKeyboardDark7126()` resolved true; the first mounted frame can miss that gate, then the touch-triggered layout can apply the inset late and visibly move the glyph.

v7.128 makes this geometry correction independent of dark-trait timing. The same 5.5pt inset is applied to only the right, stock-size dock item on `didMoveToWindow` and `layoutSubviews`, then reasserted after highlighted/selected state transitions. The dock button frame/hit target is never moved, the left emoji is untouched, and Apple's normal white pressed-state circle is intentionally untouched.

The one-shot screenshot/SIGUSR2 Search probe remains as `AmazonDark-v7.128-search-ui-probe.txt` and now records each dock item's highlighted/selected state plus `imageEdgeInsets`, making any remaining state-specific displacement directly visible in the diagnostic. No recurring keyboard scan, observer, timer, polling loop, RAF, interval, or Web work is added.

---

# AmazonDark v7.127~search-ui-probe — Search seam + keyboard dock alignment

Directly based on v7.126. The OledKeyboard-derived OLED keyboard ownership, Search heading contrast, location/delivery treatment, v7.125 glyph-sprite preservation, Deals-for-you treatment, Privacy Mode, launch cover, 120 Hz, JIT, and all established ad/TWB behavior remain intact.

This pass fixes only the two remaining native quirks shown in the current Search screenshot/probe. The bright full-width hairline is exactly coincident with the top edge of `A9VSScanItSearchWidget` (the probe places that 60pt native widget at y=526, with its photo/camera buttons beginning at y=534), so the widget now owns an invisible OLED-black 1pt root border and zero shadow rather than altering the WebKit Recent-row separators. The keyboard probe shows the left/right `UIKeyboardDockItemButton` frames already aligned within 0.3pt, while screenshot pixel geometry places the right microphone artwork about 5.5pt above the left emoji artwork. v7.127 therefore leaves both hit-target frames untouched and applies a 5.5pt downward `imageEdgeInsets` translation only to the right dock item while disabling clipping on its button/image view.

The one-shot screenshot/SIGUSR2 Search probe is retained as `AmazonDark-v7.127-search-ui-probe.txt` for this final geometry verification. Normal use still adds no DOM observer, polling loop, recurring timer, RAF, interval, or scroll listener.

# AmazonDark v7.126 — OledKeyboard UIKit port + Search UI probe

- Direct base: v7.125 Search UI probe. Search glyph-sprite preservation, Deals-for-you OLED/TWB rules, Privacy Mode behavior, launch cover, 120 Hz, JIT, and the screenshot Search probe are retained.
- Keyboard implementation now follows dayanch96/OledKeyboard's proven UIKit ownership model rather than AmazonDark's earlier UIInputSet/compositor experiments.
- Search still requests `UIKeyboardAppearanceDark`; once the keyboard is in dark mode, AmazonDark paints the real keyboard floor OLED black through `UIKeyboard`, clears the keyboard blur backing through `UIKBVisualEffectView`, paints `UIKeyboardDockView`, and handles the prediction, emoji-search, and autofill input surfaces.
- These hooks are confined to the Amazon process by the existing `com.amazon.Amazon` filter; there is no SpringBoard-wide or system-wide keyboard injection.
- No full-screen `UITextEffectsWindow`, `UIInputSetContainerView`, `UIInputSetHostView`, or `_UIRemoteKeyboardPlaceholderView` painting/filtering is reintroduced.
- The existing v7.126 Search UI screenshot probe writes `AmazonDark-v7.126-search-ui-probe.txt`.

Source basis: https://github.com/dayanch96/OledKeyboard (public source; README reports testing through iOS 17.4.1).

---

# AmazonDark v7.125 — Search glyph sprite preservation + Deals-for-you OLED

- Search/autocomplete glyph root cause: the broad Search floor selector matched `icon-*-suggestion` `<i>` leaves and its `background:#000 !important` shorthand reset Amazon's stock `background-image` to `none`. Later light `background-color` rules therefore produced 20x20 boxes; making those backgrounds transparent produced invisible glyphs. v7.125 excludes icon/glyph leaves from that structural shorthand, preserves Amazon's original sprite/pseudo artwork, and uses leaf-local filters/colors only.
- Recent-history clock is subdued gray; delete X, interest magnifier, and right-side Search row chrome are light without rectangular backplates.
- Exact `ufs_tiles_card_widget` Search Deals-for-you family now uses an OLED-black structural floor and light neutral text. Its `ufs_tiles_card_widget-sug-image` rasters are added to the existing TWB brightness owner.
- Keyboard compositor experiments remain removed; this build does not revisit keyboard theming beyond the existing stock dark-keyboard request.
- Screenshot/SIGUSR2 probe is retained and upgraded to capture exact glyph background-image/pseudo/font state plus the `ufs_tiles_card_widget` family if anything remains wrong.

# AmazonDark v7.123~search-visibility-probe

Built directly from v7.122 Search UI. v7.121/v7.122 proved that directly painting/filtering the local remote-keyboard host can make the keyboard look OLED while causing the full Search interface above it to disappear behind the keyboard/effects composition. v7.123 therefore rolls back only that experimental local keyboard compositor ownership to the known-safe v7.120 keyboard path: Search still requests iOS dark keyboard appearance, but AmazonDark no longer paints or filters `UIInputSetHostView`, `_UIRemoteKeyboardPlaceholderView`, or any full-screen text-effects container. The v7.121 Search mask-glyph fixes, focused search pill, Back arrow, OLED Search floors, and photo/camera controls remain unchanged.

A new Search-specific visibility probe replaces the stale privacy diagnostic. It is triggered by an iOS screenshot while the broken Search screen is visible, with SIGUSR2 as a fallback. The probe captures the live window/view/controller stack, full-screen/large overlays, hit-test ownership at several screen points, layer filters/backgrounds, tracked WKWebView geometry, and the exact `Autocomplete_Webview_Identifier` DOM state. It never records typed search text, clipboard data, request bodies, or headers. Probe work is one-shot only: no MutationObserver, polling loop, recurring timer, RAF, interval, or scroll listener is added. Privacy Mode itself remains unchanged; only its old manual diagnostic is replaced.

Expected behavior: Search content and Back navigation should return. The keyboard remains dark through `UIKeyboardAppearanceDark`, but this probe build intentionally does not force the risky OLED compositor filter. If Search is still blank, take one iOS screenshot on the broken frame and export `AmazonDark-v7.125-search-ui-probe.txt`.

# AmazonDark v7.122 Search UI

Fixes the v7.121 Search keyboard overlay regression without changing the keyboard appearance or Search glyph work. The full-screen `UIInputSetContainerView` is no longer painted; only the bottom keyboard host/placeholder remain OLED-owned. This restores the Search UI and back control while keeping the OLED keyboard.

# AmazonDark v7.121~search-ui — Search mask glyph + OLED keyboard follow-up

Directly based on v7.120. Fixes two v7.120 Search follow-up regressions: (1) Recent clock/X mask glyphs disappeared because their actual CSS-mask ink host was made transparent; v7.121 restores ink on the exact 20px mask leaves while keeping surrounding hosts/image backdrops transparent, and also restores the Search-suggestion magnifier mask lane. (2) UIKeyboardAppearanceDark only requests Apple's stock dark-gray keyboard. v7.121 retains that request, paints the local remote-keyboard backing OLED black, and applies one Search-only Core Animation color-matrix filter to the local UIInputSetHostView composite to push the stock dark floor to OLED while retaining differentiated gray keys/light labels. The host owner remains active across background/foreground to suppress the brief blank-white re-entry composite. No keyboard-process injection, DOM scan, observer, recurring timer, RAF, interval, or scroll worker is added.

The known v6.0.87 Search host painter that produced literal light clock/X squares is removed. The proven v5.446/v6.0.116 transparent Search/nav image-backdrop rule is restored, while Search glyph-like leaves receive light ink/filter treatment and the Recent-history glyph uses the same 0.91 neutral-light filter as the established arrow/chevron lane. No MutationObserver, DOM polling, recurring timer, or Web scroll listener is introduced. The only new native traversal is bounded to the exact 60pt `A9VSScanItSearchWidget` subtree on its own mount/layout so its two controls can be recolored without a window-wide sweep.

Privacy Mode behavior from v7.118 is retained. The Privacy footer wording remains exactly: “Blocks known Amazon analytics, crash telemetry, and ad-measurement endpoints. Late NSURLSession configuration and WebKit pixel blocking. May slightly reduce background network/CPU work.” The retained manual SIGUSR2 diagnostic remains functionally unchanged; only its filename/banner are relabeled for the current Search UI work.

# AmazonDark v7.119~search-probe

Directly based on v7.118~privacy-probe. No Search visual fix is applied yet: this diagnostic captures the currently broken Search pane exactly as rendered, including native top search chrome/back control, visible keyboard view hierarchy, and the current Web Search suggestion/photo-camera DOM. Privacy Mode functional blocking remains unchanged. The Privacy footer text is updated exactly to the requested wording.

# AmazonDark v7.118~privacy-probe

Privacy Mode follow-up built directly from v7.117~privacy-probe / v7.116 production visuals. Fixes the failed WKContentRuleList compilation with a simpler documented WebKit regex subset, reasserts the privacy NSURLProtocol at NSURLSession construction time and when protocolClasses are overwritten, and adds counters to verify Minerva coverage. All v7.116 visual/theming payloads remain unchanged.

# AmazonDark v7.117~privacy-probe

Built directly from v7.116 production. Adds an opt-in **Privacy Mode** preference (default OFF) that conservatively sinks known Amazon analytics, diagnostics, and ad-measurement traffic while preserving shopping/media/ad-creative hosts. Web `sendBeacon`, `fetch`, and XHR calls to the known telemetry set receive local synthetic success; WebKit pixel/resource telemetry is covered by a narrow content rule list; native Foundation requests are answered locally through a narrow `NSURLProtocol`. A manual SIGUSR2 probe reports only metadata/counters so on-device coverage and residual telemetry can be verified. No visual theming payload was intentionally changed.

# AmazonDark v7.116 — SpringBoard post-ready settle guard

Production build based directly on v7.115. The v7.115 event-driven app-side launch handoff is kept intact: no DOM polling, no `querySelector()`, no app-side `dispatch_after`, and no recurring launch timer is restored. The brief stock-white Amazon loading/splash flash seen just before Home was caused by the ready lifecycle event arriving a few frames before Amazon's final splash-to-Home composite was visually settled.

The fix stays entirely on the SpringBoard cover side. When Amazon posts the existing one-shot ready signal, SpringBoard now waits until **both** conditions are satisfied before beginning the existing 0.55 s fade: (1) the historical 1.40 s minimum cover time, and (2) a 0.40 s post-ready settle window. If the ready signal arrives early enough, the existing 1.40 s minimum absorbs some or all of that settle window; otherwise the maximum additional hold is 0.40 s. This keeps the cover opaque across the fragile final composite without reintroducing WebKit queries, polling, app-process timers, observers, or extra dispatch work.

All v7.115/v7.114 theming code is unchanged, including OLED floors, standalone ad families, store-image/product-image TWB, compact border geometry, transparent Limited-time-deal plate, 300x250 Swiper ads, third-party video/display TWB, Prime blue, orange rating stars, red deal accents, Sponsored paint, native TWB, search/top/bottom chrome, 120 Hz, and JIT. No probe ships in v7.116.

---

# AmazonDark v7.115 — event-driven launch handoff / performance cleanup

Production build based directly on v7.114. No visual theming selector, standalone-ad rule, TWB media lane, border geometry, text ownership, Sponsored paint, Prime blue, rating-star orange, or deal/coupon accent rule is changed.

The old launch-cover readiness system polled visible WebViews every 125 ms for up to 64 attempts and evaluated JavaScript containing two `querySelector()` calls, then used a second delayed handoff before posting the SpringBoard ready signal. v7.115 removes that polling path completely. Readiness is now event-driven from the existing visible WebView / primary Amazon controller lifecycle and the two known Amazon splash controllers disappearing. A small native splash-controller tree check prevents an underneath-splash lifecycle event from releasing the cover early. SpringBoard still owns the existing 1.40 s minimum presentation and 0.55 s fade.

The runtime refresh path is also consolidated so launch and preference refreshes share one guarded main-thread handoff instead of stacking main-queue dispatches. App-side `src/Tweak.xm` now contains 0 MutationObservers, 0 `querySelectorAll`, 0 `querySelector`, 0 TreeWalker, 0 web scroll listeners, 0 intervals, 0 RAF loops, 0 timeouts, 0 `dispatch_after`, and 2 `dispatch_async` call sites (JIT utility request + guarded main-thread refresh). No probe ships in v7.115.

---

# AmazonDark v7.114 — standalone store-image TWB parity

Production build based directly on the device-confirmed v7.113/v7.112 visual code. Existing captures already identify the standalone store/brand image precisely: the raster lives under `data-acei-id="brnd-logo"`, with the 414x125 renderer also exposing a `data-testid="logo"` wrapper and an `img[alt="Brand logo"]` leaf. v7.114 adds that exact identity raster to the same TWB brightness factor already used for standalone product imagery, in both the document-start TWB sheet and the constructable/adopted standalone survivor sheet. This covers the known compact, medium, large/dynamic, and first-party standalone renderer variants without reopening the generic logo/icon lane.

Prime blue, orange rating stars, red deal/coupon accents, Sponsored text/glyphs, ordinary page/store logos, badges, UI icons, geometry, borders, and the successful compact 320x50 fixes remain unchanged. The v7.113 compact diagnostic WKUserScript, SIGUSR2 handler, background observer/task, and probe file writer are removed from this production cut; no probe ships in v7.114. No MutationObserver, `querySelectorAll`, TreeWalker, web scroll listener, interval, RAF loop, or timeout is added.

---

# AmazonDark v7.113~probe — reliable background compact-ad capture

Built directly from v7.112~probe with the **visual/theming code unchanged**. The compact standalone parent-owned APE border and exact `lfstyl-img` / `prod-img` TWB selectors are preserved byte-for-byte. The only runtime change is probe delivery: backgrounding Amazon once now starts a short iOS background task, captures the currently visible WebKit frame, waits for the existing 450 ms child-frame replies, writes `AmazonDark-v7.113-compact-standalone-probe.txt`, then ends the background task. Manual SIGUSR2 remains as a fallback. No MutationObserver, querySelectorAll scan, TreeWalker, scroll listener, interval, RAF loop, or recurring timer is added.

# AmazonDark v7.112~probe — compact standalone parent-border + live media-host repair

This build is based directly on v7.111~probe and changes only the two compact standalone failures proven by the v7.111 SIGUSR2 capture.

- **Border:** removes the child `#ad::after` ring. The compact main-frame `.ape-placement` already owns the correct 1 px rounded border geometry, so v7.112 only recolors that existing transparent border to `#3b4043` when its wrapper is `--ad-height:50` and the placement is `aspect-ratio: 320 / 50`. The separate Sponsored feedback row stays outside the border.
- **TWB:** the live compact raster is under `data-acei-id="lfstyl-img"`, not only `prod-img`. v7.112 tames the media leaves under either known compact host, scoped behind `#ad:has(#dynamic-bb)`, in both the first-paint TWB sheet and constructable standalone survivor sheet.
- Existing compact OLED floor, transparent Limited-time-deal plate, medium/large standalone treatment, 300x250 standalone carousel treatment, third-party display/video TWB, Prime blue, rating-star orange, deal accents, and Sponsored paint remain unchanged.

The manual SIGUSR2 probe remains available as `AmazonDark-v7.112-compact-standalone-probe.txt`. No recurring observer, querySelectorAll scan, TreeWalker, scroll listener, interval, RAF loop, or timer is added.

---

# AmazonDark v7.110~probe — compact standalone geometry + floor parity

Built directly from v7.109~probe using the two manual current-frame captures made on the visible compact standalone variants.

The dark 394x62 `#dynamic-bb` creative is already OLED and TWB-tamed, but v7.109 moved its gray outline to the taller main-frame APE wrapper. That wrapper also contains Amazon's separate Sponsored feedback row, so the outline now incorrectly extends below Sponsored. v7.110 removes that wrapper outline and draws the established 1px `#3b4043` / 8px-radius outline as a zero-layout `::after` overlay on the exact `--ad-height:50` `.ape-placement`. The placement is the creative-height owner above `.ape-feedback`, so the bottom edge stays above Sponsored while remaining in the main frame where the child iframe cannot clip it.

The same `#dynamic-bb` capture also exposes the remaining white `Limited time deal` plate: it is a classless direct child of `[data-testid=deal-badge]` with an inline `background-color: rgb(255, 255, 255)`. v7.110 clears only that inline-white plate and leaves the red `% off` badge and red deal text authored.

The separate 430x67 renderer-factory capture proves that `html`, `body`, `#ad`, `renderer-factory-ad-container`, and `main-content` are already OLED. The sole surviving light plane is `[data-testid=content]`, whose inline white background wins because it was not part of the constructable survivor sheet. v7.110 adds that exact structural floor to both the first-paint and adopted standalone sheets, without changing its radius/layout or the already-correct Sponsored/border geometry.

The manual SIGUSR2 probe is retained as `AmazonDark-v7.110-compact-standalone-probe.txt`. All three corrections are declarative CSS only: no MutationObserver, querySelectorAll, TreeWalker, scroll listener, interval, RAF loop, timeout, or recurring probe work is added. Existing compact/medium TWB, 300x250 Swiper carousel treatment, third-party display/video TWB, Prime blue, orange rating stars, deal accents, and Sponsored ink/glyph behavior are preserved.

---

# AmazonDark v7.109~probe — compact standalone full-wrapper border

Built directly from v7.108~probe using the manual current-frame capture made on the visible Hill's Science Diet compact standalone ad. The probe resolves the remaining border defect: the compact creative itself is a 396x62 child iframe, but Amazon renders its `Sponsored` feedback chrome as a separate 398x20 main-frame sibling beneath that iframe. Both live inside the same 398x84.19 `.ape-wrapper` (`--ad-height:50`). The feedback row is already transparent; it was not covering the border. v7.108 simply put the border on the wrong ownership level — the child `#ad` — so the border necessarily ended before the Sponsored row.

v7.109 removes that child-frame border and gives the exact compact main-frame `.mobile-ad-container > .ape-wrapper[style*="--ad-height:50"]` the established 1px `#3b4043` / 8px-radius neutral border. This encloses both the creative and Amazon's Sponsored feedback row without changing either row's ink or adding any runtime DOM work. The compact product-image TWB from v7.108 remains unchanged, as does the exact 300x250 Swiper standalone-carousel repair and the third-party display/video TWB path.

The manual SIGUSR2 probe is retained as `AmazonDark-v7.109-compact-standalone-probe.txt` so the finished wrapper geometry can be verified on-device. No MutationObserver, querySelectorAll, timer, RAF, scroll listener, or recurring probe work is added.

---

# AmazonDark v7.108~probe — compact standalone + exact 300x250 Swiper repair

Built directly from v7.107~probe from the two device captures in the same probe run. For the compact 396x62/320x50 AdaptiveRenderer, the probe identifies the full-size `#ad` + `#dynamic-bb` shell, which is already OLED black but has no border, and `[data-acei-id=prod-img]` as the dedicated product-raster host. v7.108 gives that exact shell the established 1px `#3b4043` / 8px-radius standalone border and applies the existing TWB brightness factor only to its product raster.

The same v7.107 probe also proves why the previous rare `Featured by BEULT` carousel fix missed: this 430x250 child does **not** expose any class or `data-testid` containing `carousel`. Its stable renderer signature is `#ad[data-html-dimensions="300x250"]` with `[data-testid=gridContainer]`, `.swiper-wrapper`, and `.swiper-slide`. The surviving light plane is exactly `gridContainer` (`rgb(255,255,255)`), the active and next slide frames use `border-gray-500`, and both the product image and neighboring custom-image slide expose their raster as `[data-testid=pictureHighQuality]`. v7.108 therefore targets that exact Swiper signature in both the first-paint sheet and the constructable standalone survivor sheet: the grid floor becomes OLED black, slide structure stays transparent, existing slide borders become `#3b4043`, ordinary copy becomes v185 light, Sponsored becomes subdued light gray, and only `pictureHighQuality` rasters receive TWB. Prime/rating-star/badge/deal/glyph paint is explicitly excluded so Prime blue and orange stars remain authored.

The manual SIGUSR2 probe is retained as `AmazonDark-v7.108-compact-standalone-probe.txt` for verification and remains idle until triggered. No MutationObserver, querySelectorAll, timer, RAF, or scroll listener is added.

# AmazonDark v7.107~probe — standalone ad parity + Outlet ink

Built directly from v7.106~probe, retaining the zero-observer/adopted-sheet performance pass and the manual compact-standalone SIGUSR2 probe. The device capture identifies the bright AT&T creative as a nested Flashtalking 300x250 under the exact `#mobile-third-party-ad` host, so v7.107 restores TWB on that one outer third-party creative host rather than reopening the generic standalone-media lane. It also adds a below-fold Home neutral-ink fallback for standard Amazon product-title/price semantics outside the historical card roots. The revised v7.107 additionally covers the rare large first-party standalone sponsored carousel shown as a white `Featured by ...` panel: carousel structural floors become OLED, ordinary carousel copy becomes v185 light, and carousel product media receives the current TWB strength while Prime, rating-star, logo, badge, deal/coupon and Sponsored-feedback accent paint stay Amazon-owned. The same lane is present for both a child safe-frame renderer and the already-known main-document `mobile-mshop-ad` / `mobile-ad-container` form. The manual probe now records carousel/Featured/Prime/rating/star nodes, light planes, and dark-neutral text only when SIGUSR2 is triggered; it remains idle otherwise.

# AmazonDark v7.106~probe — compact standalone capture + zero-observer performance pass

Built directly from v7.105 production. The current standalone child-frame CSS payload is unchanged, but its shell-survival owner now uses `document.adoptedStyleSheets` instead of a direct-child MutationObserver. The legacy semantic Sponsored glyph learner is removed because the currently proven NPACK, Hybrid, product-carousel, and APE families already have deterministic static CSS owners. This probe adds a manual SIGUSR2 snapshot for the still-light compact standalone ad family; it performs no diagnostic traversal until triggered.

# AmazonDark v7.105 — production standalone survivor + transparent deal-message plate

- Production cut of the device-confirmed v7.104 standalone child-shell survival repair; the temporary lifecycle/UCC/SIGUSR2 probe runtime is removed.
- Retains the document-start standalone owner and its single direct-child `documentElement` MutationObserver so Amazon's late HEAD/BODY replacement cannot restore a white standalone card.
- Ports the existing Home `badgeMessage` treatment to the exact standalone Responsive eCommerce host exposed by the v7.104 device capture: `[data-testid="message-container"]` inside `renderer-factory-ad-container` now has a transparent background and no box shadow.
- The new rule does **not** recolor the `% off` badge, `Limited time deal` text, deal/coupon accent colors, product media, borders, geometry, links, or hit targets.
- No probe, recurring timer, RAF, scroll listener, subtree observer, or DOM scan was added.

# AmazonDark v7.104~probe — survive Amazon child-shell replacement

**Direct lineage:** v7.103~probe, whose production visual base is exact v7.96.

The v7.103 device capture finally identifies the standalone-ad failure precisely. In the visible 414x125 safe-frame, `ad7-static-theme`, `ad7-twb-static`, and `ad7-standalone-7103` are all present at document end / load / pageshow. One millisecond later Amazon removes both `HEAD` and `BODY`, adds replacements, and all three AmazonDark style owners disappear. The renderer then paints its stock inline `background: rgb(255,255,255)` and stock dark navy `rgb(0,0,17)` headline/product text. This exactly explains both symptoms: white cards and apparently missing text on dark cards.

v7.104 replaces the document-end standalone backstop with a document-start **shell-survival owner**. It observes only the direct children of the standalone child document's `HTML` element (`childList:true`, no subtree). If Amazon replaces `HEAD`/`BODY` or removes the owner itself, it immediately reattaches the standalone stylesheet directly to `HTML`. There is no document scan, scroll listener, interval, RAF, timer, or subtree observer.

The surviving stylesheet owns only the already-probed standalone renderer families: OLED floor; existing border color; 414x125 brand/product/price ink; 320x50 product-description/Subscribe & Save ink; large dynamic-product neutral copy; and the exact standalone product-raster TWB lanes at the current user strength. Geometry, padding, radius, flex/grid, positions, links, Prime, stars, colored deal/coupon accents, and outer Sponsored feedback chrome remain untouched.

The v7.104 probe adds the one thing previous probes did not have: the production repair's own bounded state (`installs`, `repairs`, `shells`, event timestamps, final style connectivity, HTML identity, and constructable-stylesheet support) alongside the final computed renderer paint. A successful failing-card capture should show `shells>=1`, `repairs>=1`, `connected=true`, medium layout background `rgb(0,0,0)`, and brand/product text `rgb(232,230,227)`.

---

# AmazonDark v7.96 — Disney hero-style product plates

- Production build based directly on v7.95; no probe runtime ships.
- Keeps the v7.95 Disney / Amazon Shopping Guides visibility fix, then gives its four product-image tiles the same OLED-black contain plate used by the seasonal NPACK hero cards.
- Only the Shopping Guides `_colored-background_` shell changes from Amazon's light `#f7f7f7` plate to OLED black. The product raster, sizing/contain behavior, padding, radius, position, links, labels, and card geometry are untouched.
- TWB continues to act on the actual product raster at the user's selected strength; the new black backdrop itself is never dimmed.
- No MutationObserver, recurring timer, RAF, scroll listener, or probe runtime.

# AmazonDark v7.95 — compact standalone + Disney media repair

- Production build based on v7.93 production plus the v7.94 viewport-probe findings; no probe runtime ships.
- Compact renderer-factory standalone ads keep their stock geometry while the actual responsive layout floor stays OLED black, the existing 1px border becomes `#3b4043`, primary copy becomes `#e8e6e3`, and secondary metadata becomes `#b1aaa0`.
- TWB now reaches the compact renderer's real `data-testid=image` / `data-acei-id=lfstyl-img` raster lane as well as the large dynamic-product lane.
- Standalone APE Sponsored text and info glyph are both fixed at `#b1aaa0`; the legacy glyph learner no longer overwrites the standalone glyph with the black parent control color.
- The Disney / Amazon Shopping Guides quad card keeps its product images visible by neutralizing only Amazon's `darken` / `multiply` blend modes on that renderer; layout and image geometry are untouched.
- No MutationObserver, recurring timer, RAF, scroll listener, or probe runtime.

# AmazonDark v7.93 — standalone dynamic-product ad theming

- Built from v7.91 production; the v7.92 probe runtime does **not** ship.
- Owns the probed standalone APE dynamic-product creative as OLED black while preserving Amazon blue/colored accents and orange rating stars.
- Primary standalone-ad copy uses `#e8e6e3`; secondary review/list-price metadata uses `#b1aaa0`.
- TWB skips generic standalone-child media and dims only the dedicated product-picture raster.
- Standalone APE Sponsored text + info glyph now use the same subdued `#b1aaa0` contrast as the corrected Home carousel Sponsored badges.
- No MutationObserver, recurring timer, RAF, scroll listener, or probe runtime.

# AmazonDark v7.91 — Sponsored gray + functional TWB range

- Home carousel Sponsored text and info glyphs now use the same subdued secondary gray (`#b1aaa0`) instead of pure white.
- Tame Light Backgrounds now maps the full 0–100 slider to an effective dimming range: 10% black-equivalent at 0 through 58% at 100. The toggle is the true off switch.
- The currently loaded web surface refreshes once when the TWB preference changes; native image overlays recalculate through their existing layout hooks.
- The upper TWB bound is slightly darker than v7.90's former 50% maximum.
- No probe ships in v7.91.

# AmazonDark v7.90 — Home carousel Sponsored parity

- Production build based on the v7.89 probe lineage; all temporary viewport-probe runtime has been removed.
- The v7.89 capture resolved the carousel mismatch as separate text-fill and masked-glyph paint lanes inside Amazon's product-carousel Sponsored badge shells.
- Only `[class*=widget-sponsored-badge-container]` / `[class*=asin-sponsored-badge-container]` Sponsored feedback rows are normalized to pure white text and a pure white 12x12 info-mask glyph.
- Covers the observed NPACK, GWM asin-tile, and blended/p13n (`_cXVhZ`) carousel renderer variants without changing Sponsored styling elsewhere.
- No MutationObserver, timer, scroll callback, or new runtime scan is added; the correction is static document-start CSS.
- No probe ships in v7.90.

# AmazonDark v7.89~probe — restored proven manual probe I/O

- Directly based on v7.88~probe; production theming behavior is unchanged.
- Keeps the manual SIGUSR2 one-shot trigger.
- Restores the proven probe I/O model: Amazon writes inside its own sandbox Documents directory; NewTerm finds that file and copies it to the shared AppGroup Documents folder.
- Removes the invalid v7.88 behavior that tried to write directly from the sandboxed Amazon process into NewTerm's shared AppGroup path.
- Viewport capture remains fixed-current-frame only: no auto-scroll, no auto-tap, no MutationObserver, no recurring timer.
- Two identical runs are intended: GOOD carousel state, then BAD carousel state.

# AmazonDark v7.88~probe — manual viewport snapshot

- Direct base: v7.87~probe, with **no production theming changes**.
- Replaces the unreliable screenshot-notification trigger with an explicit one-shot **SIGUSR2** trigger.
- The capture remains viewport-only: no scrolling, no tapping, no MutationObserver, no recurring timer/RAF, and no whole-document `querySelectorAll("*")`.
- Run the exact same trigger twice: once after leaving the good carousel state on screen, then again after leaving the bad state on screen.
- Captures Sponsored text/glyph paint plus local chevron/SVG/path/pseudo-element state inside card/header roots found in the current viewport.
- Output appends to `AmazonDark-v7.88-viewport-probe.txt` in the shared AppGroup Documents folder.

# AmazonDark v7.86 — isolate Hybrid carousel Sponsor glyph color

- Built from clean v7.83 production. The v7.84/v7.85 standalone-ad probe/overrides are not carried forward.
- Root cause of the carousel inconsistency: the legacy `ADSPG7070` learner emits a literal color into a CSS selector built from Amazon's shared hashed Sponsor-glyph classes. Multiple sibling carousel cards reuse those same classes, so whichever card is sampled during hydration can overwrite the glyph color for another card; refresh changes the sampling/order and makes the bug appear random.
- v7.86 prevents that learner from owning Hybrid `ad-feedback-sprite-mobile` glyphs. Those glyphs are now handled entirely by a declarative direct-family rule that converts the stock info PNG to a mask and paints it with `currentColor`, inherited from that glyph's own adjacent Amazon-owned Sponsored label.
- Sponsored text is never recolored. No standalone-ad work or standalone-ad probe ships in this build.
- No MutationObserver, timer, interval, RAF, or web scroll listener is added.

# AmazonDark v7.83 — Sponsor glyph inherits Amazon label color

- Built directly from v7.82 production, preserving the v7.0.79 white-scrollbar baseline and the v7.82 deterministic Hybrid Sponsor-glyph ownership.
- v7.82 correctly prevented late hydration from making Hybrid Sponsor glyphs dark, but hard-coded every captured Hybrid glyph to `#e8e6e3`.
- v7.83 keeps the same high-specificity glyph-only selector and changes its paint to `color: inherit` + `background-color: currentColor`, so each masked info glyph follows the adjacent Amazon-owned Sponsored label whether Amazon renders that label gray or white.
- Sponsored text is never recolored. No MutationObserver, timer, interval, RAF, web scroll listener, or probe runtime is added.

# AmazonDark v7.82 — deterministic Hybrid Sponsored glyph paint

- Built from the v7.0.79 production/scrollbar baseline through the v7.81 inventory probe.
- v7.81 proved the intermittent dark Sponsor glyph is Amazon's Hybrid NPACK/GWM `ad-feedback-sprite-mobile` renderer: the visible text is Amazon-owned, while the masked 12x12 glyph can hydrate to `rgb(17,17,17)`.
- Adds one declarative, high-specificity CSS rule anchored to `data-ad-feedback-label-id` so Amazon's late two-class Grey-theme rule cannot win by stylesheet order.
- Paints only the Sponsor glyph light; Sponsored text remains fully Amazon-owned.
- Removes the v7.81 screenshot probe/runtime. No MutationObserver, timer, interval, RAF, or web scroll listener.

# AmazonDark v7.0.79

- Pre-release refresh: themes Amazon's ad-feedback bottom sheet with cheap documentStart CSS only.
- Feedback sheet structural floor is OLED black; headings/body/labels are light; issue textarea uses the same #303335 gray as the current search field; buttons and checkbox chrome are dark/neutral.
- The sheet rule is scoped to `adFeedbackBottomSheet` / `mobile-ad-feedback-container`; the existing Sponsored-glyph fix is otherwise unchanged.
- No MutationObserver, timer, scroll listener, interval, RAF, or probe runtime is added.

- Built directly from the clean v7.0.70 production source.
- Fixes the remaining Deals-for-you Sponsored info glyph by recognizing Amazon feedback controls exposed as `aria-label="Leave feedback on Sponsored"`, even when their visible label has no `ad-feedback-text` / `sponsored-label` class.
- Reads the exact visible Sponsored text leaf's computed color and applies it only to the adjacent stock info glyph through the existing persistent Amazon-class CSS renderer lock.
- No MutationObserver, retry timer, scroll listener, interval, RAF, or probe runtime. Sponsored text remains Amazon-owned.

# AmazonDark v7.0.70

## v7.0.79 — Sponsor persistence + exact Home spinner center

- Adds a permanent CSS-only paint for late-hydrating NPACK / sponsored-products Sponsored info glyphs so Amazon replacement nodes cannot revert dark after the one-shot Sponsor pass. Sponsored text remains Amazon-owned.
- Fixes the actual Home mosaic load-more spinner identified by the v7.0.78 screenshot probe: its `::after` pseudo-element was the opaque white center disc, so only that center is changed to OLED black while the rotating light ring remains intact.
- Retains the white native scrollbar on the exact `WKScrollView` runtime class and leaves `WKChildScrollView` carousel descendants alone.
- No MutationObserver, timer, interval, RAF, web scroll listener, or probe runtime ships in this production build.

## v7.0.70 — complete Sponsored glyph template coverage

- Direct source base: v7.0.69 production.
- Fixes the remaining dark Sponsored info glyph in the Recommended deals / Deals for you sponsored-products-mobile card.
- Historical device evidence shows this template uses a distinct 12x12 background-image glyph class beginning `_sponsored-products-mo`, while the GWM/NPACK badges use other families.
- The v7.0.69 learner only searched `ad-feedback` / `spr` families, so it never learned this renderer and therefore never emitted the persistent CSS rule for it.
- v7.0.70 keeps the existing exact computed-color behavior, but extends only the local glyph lookup around an already-identified Sponsored label to accept the known sponsored-products-mobile family or another 5–36 px nearby background/mask/vector painter.
- Once learned, the rule targets the real Amazon glyph selector, so later hydration/replacement remains matched automatically.
- Sponsored text is never recolored.
- No MutationObserver, retry timer, scroll listener, interval, RAF loop, or page-wide runtime scan is added.

## What five failed chevron builds have actually established

- v7.0.63 removed `brightness(0.5)` from the SVG dimming chains. **Confirmed on device**:
  the v7.0.63 sweep reports `filter=none` where it previously read `brightness(0.5)`.
  That fix landed and the chevrons were still dark.
- v7.0.64 ported the v6.0.185 rule for `.a-icon-next-rounded` /
  `.a-icon-previous-rounded` verbatim. Still dark, so those leaves are not present in
  this Home build either.
- Every rule so far — mine and v6.0.185's — sets `fill`/`color`/`filter` on the **svg
  element**.

The sweep reports `fill=none stroke=none` on those SVGs. That is the *svg's* computed
value. **A `<path>` carrying its own `fill` attribute ignores anything set on its svg
ancestor.** Every rule written to date targets the wrong node, which is consistent with
the chevron staying dark through all of them.

This build paints the path itself:

    [class*=header-icon], [class*=header-icon] path, [class*=header-icon] use,
    [class*=header-link] svg path, [class*=cardui-header] svg path, ...
    {fill:#e8e6e3!important;stroke:#e8e6e3!important;color:#e8e6e3!important;}

Harmless if `header-icon` is not the chevron. Decisive if it is.

## Sweep: outerHTML 220 -> 700 characters

The 220-character cap truncated every capture at `<path d="M7.0422 22C6.83522…` —
exactly before the `fill` attribute. That is why five builds went by without anyone
seeing whether the path carries its own colour. The next capture will show it.

## Honest status

I have made five wrong calls on this chevron and asserted several of them confidently.
The path-vs-svg distinction is the first explanation consistent with *all* the evidence
rather than just the latest capture, but it is still an inference until the widened
capture confirms it.

If the next sweep shows `<path fill="#0F1111"` or similar, this build fixes it. If the
path has no `fill` attribute, then `header-icon` is genuinely not the chevron and the
element is something the sweep has never matched — in which case the probe needs to walk
card-header subtrees by structure rather than by class.

## Verification

- Path-vs-svg tested in a real engine: the svg-level selector does **not** match the
  path, the path-level selector does, and a path with its own `fill` attribute keeps it
  against an svg-level rule. 3/3.
- Balance 0/0/0; `scripts/lint-logos.sh`.


## v7.0.73 — Sponsored feedback focus-ring cleanup

Amazon's ad-feedback text control applies its own rounded focus outline. After closing the feedback sheet, that control can remain focused, leaving a gray box around `Sponsored`. v7.0.73 suppresses only the focus outline/box-shadow/tap highlight for Sponsored/ad-feedback trigger families. Sponsored text and glyph color ownership from v7.0.72 is unchanged. No observer, timer, scan, scroll hook, interval, or RAF was added.