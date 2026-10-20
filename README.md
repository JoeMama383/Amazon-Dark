# AmazonDark v7.644~static-style-delivery

Production cleanup based on v7.643. Search/product pages use document-owned constructed stylesheets instead of inserting theme STYLE nodes into Amazon's live DOM. The review ownership observer is removed; static review selectors handle DOM changes. Medical, business, checkout, advertising-preference and account classifiers are excluded from the two affected routes. Other menu themes retain their existing behavior. This is not a claim that the entire tweak is CSS-only or that phone input delay has been eliminated.

Editable stylesheet blocks are in `styles/`, with non-style templates in `runtime/`. `scripts/build-style-sources.py` expands them into the committed compiler inputs and CI verifies they agree. Python is build/test tooling, not installed Amazon runtime. See `styles/README.md`, `DIFF-v7.644.md`, `VALIDATION-v7.644.md`, and `COMMANDS.md`.

# AmazonDark v7.643~startup-isolation

Diagnostic follow-up to the v7.642 phone capture, which still recorded substantial Search/product delays. Normal mode retains the production theme. Explicit `arm isolate-css` captures omit intercepted AmazonDark CSS before a fresh Search/product document loads, retain a simple black root floor, and restore the saved CSS at session end. Base-only and follow-up-only partitions are also available. The report records eligibility, withheld styles, residual rules and restoration; late or incomplete evidence is not treated as successful isolation. The existing review ownership observer now receives armed callback timing. No new production observer, polling loop or DOM traversal is added. This is not a verified production latency fix. See `DIFF-v7.643.md`, `VALIDATION-v7.643.md`, and `COMMANDS.md` for evidence, limitations, the short existing-clone push and separate probe commands.

# AmazonDark v7.642~review-owner-cache

Production performance candidate based on v7.641 and its normal on-device capture. On main Search/product documents, repeated document-wide review CSS conditions are replaced with one cached ownership state. The state follows review insertion, removal, ID changes and body replacement through a single observer using at most three ID lookups per delivery. It does not scan the DOM, read layout, poll, or write unchanged state. Authored review declarations and selector priority are preserved, as are the v7.641 route pruning and startup sheet recovery. Other routes and child frames keep their original CSS. See `DIFF-v7.642.md`, `VALIDATION-v7.642.md`, and `COMMANDS.md`. This is a production change, not a probe expansion; phone latency still needs verification.

# AmazonDark v7.641~hot-route-css-trim

Production performance change based on v7.640 and its ordinary on-device capture. Main Search/product documents now omit additional dedicated full-page menu rules and four unrelated complete sheets before installation. Shared overlays, authored controls, image taming, non-hot routes and startup sheet recovery are retained. No recurring scan, observer, geometry change or additional runtime probe work. The offline performance report now separates uniquely matched Search/product timings. See `DIFF-v7.641.md`, `VALIDATION-v7.641.md`, and `COMMANDS.md`. This reduces stylesheet work; the remaining phone input delay still requires on-device verification.

# AmazonDark v7.638~render-work-queue-repair

Repairs the Search/PDP feedback lifecycle guard, removes duplicate forced child-frame CSS, and serializes child repairs through JavaScript completion. Paint rules are retained. Performance diagnostics now include child-frame round trips and explicitly armed adopted-sheet cost trials. See `DIFF-v7.638.md`, `VALIDATION-v7.638.md`, and `COMMANDS.md`. On-device latency verification remains required.

# AmazonDark v7.619~handoff-regression-repair

Fixes GitHub strict-CI handoff headings, retains v7.605–v7.613 UI modules, and adds source-delivery audit coverage. See `DIFF-v7.619.md`, `VALIDATION-v7.619.md`, `COMMANDS.md`. Device painting and a successful Theos build still require verification.

# AmazonDark v7.618~native-compiler-error-repair

Fixes the exact two compiler errors diagnosed from the v7.617 GitHub build artifact and the independent format-string warning. No UI/probe algorithm changes. Read `DIFF-v7.618.md`, `VALIDATION-v7.618.md`, and `COMMANDS.md`; GitHub Theos package verification remains required.

# AmazonDark v7.617~probe-handoff-contract-repair

Repairs the frozen v7.392 probe-helper contract without discarding v7.616 installed-runtime capture discovery. Synchronizes versioned probe/CI handoff markers and adds a current/older-installed FULL TAR regression. See `DIFF-v7.617.md`, `VALIDATION-v7.617.md`, and `COMMANDS.md`. Full strict CI and Theos compile remain to be confirmed by GitHub Actions.

# AmazonDark v7.615~native-live-compile-repair

Fixes the v7.612 Amazon Live Objective-C++ forward-declaration and C-string class argument errors discovered at the first full Theos compile after multiple UI source changes. No runtime UI styling changes. v7.614 probe-sync and all source UI work are preserved. See `DIFF-v7.615.md`, `VALIDATION-v7.615.md`, and `COMMANDS.md`. On-device build verification remains pending.

# AmazonDark v7.614~ci-regression-repair

CI/probe-version synchronization of v7.613; retains its UI patches and the earlier 7.605–7.612 iterations. See `COMMANDS.md`, `DIFF-v7.614.md` and `VALIDATION-v7.614.md`.

# AmazonDark v7.611~your-saves-oled-followup

Builds on the complete v7.610 codebase. Exact WebKit Your Saves/Lists & Registries theming from r8 VIEWPORT: OLED section and card floors, medium gray filter pills retaining blue selected stroke, white neutral product text/prices/buttons/icons, gray dividers, and preference-controlled image taming. A FULL probe diagnostic now explicitly logs interruptions when Amazon goes into the background. No global observers, scans or layout rewrites. See DIFF-v7.611.md, VALIDATION-v7.611.md and COMMANDS.md; device verification remains pending.

# AmazonDark v7.610~profile-and-notification-followup

Based on v7.609, restores updated native Shopping As profile picker ownership under `UIWindow/AMSModalLayoutOverlay`. Adds guarded notifications palette/media fallback, pending a probe from the actual notification feed. See `DIFF-v7.610.md`, `VALIDATION-v7.610.md` and `COMMANDS.md`.

# AmazonDark v7.609~review-photo-and-sort-popup

Based on v7.608. Restores the authored CSS-backed inline customer review photos lost to v7.593/7.594 background-image resets and darkens the recovered media using the existing preference-controlled brightness factor. Styles the probe-identified review sort dropdown OLED with white text/close glyph and preserved blue selected border. No new scans or geometry changes. See DIFF-v7.609.md, VALIDATION-v7.609.md and COMMANDS.md.

# AmazonDark v7.608~review-filter-menu-buttons

Based on v7.607. Recolors the review filter secondary-view menu buttons and option cards to neutral dark-mode treatments while preserving existing sprites, selected indicators and geometry. Floors were already correct; this release only normalizes button fills, borders, dividers and neutral text within the exact `#reviews-filter-options-view` popover.

See DIFF-v7.608.md, VALIDATION-v7.608.md and COMMANDS.md. CI/device verification remains required.

# AmazonDark v7.599~alexa-owner-full-recovery

Based on v7.598. Restores Alexa-for-shopping native OLED ownership after Amazon moved its `navigation-root` from AppCXWindow into the main-window AppCX bottom sheet. Reuses the historical card, suggestion-pill, SVG and input control rules with an exact new host gate; fixes Person Forgot-something React text rehydration; prioritizes the correct Alexa native FULL probe route over the underlying hamburger. See DIFF-v7.599.md, VALIDATION-v7.599.md and COMMANDS.md. CI and on-device verification remain required.

# AmazonDark v7.597~live-thankyou-completion

Based on v7.596. Completes the probe-captured Amazon Live page and missed checkout music cards, sponsored continuation images and Add to cart backing floors. Search glyphs match placeholder/typed text; native Live back/search glyphs are white. Preserves semantic colors and the existing performance recorder/runtime fixes.

See DIFF-v7.597.md, VALIDATION-v7.597.md and COMMANDS.md. This is a source handoff: CI must build the installable package, and final visual confirmation requires a phone run.

# AmazonDark v7.596~performance-probe-runtime-audit

Based on v7.595. Adds a bounded, opt-in performance recorder, removes redundant native/Web work, corrects preference-dependent script caching and restores a dropped address theme module. Themes the probe-captured order-confirmation page with OLED floors, neutral buttons, preserved semantic colors and preference-controlled artwork dimming.

See DIFF-v7.596.md for changes and recorder limits, VALIDATION-v7.596.md for verification, and COMMANDS.md for push and separate probe commands. This is a source handoff; CI/device build and on-phone measurements remain required.

# AmazonDark v7.592~probe-backed-ui-completion

Built from the supplied v7.591 source. Completes the captured medical/authentication, coupon, thumbnail, review and Shop the Show owners while retaining v7.591's recovered Person/Home image behavior and universal FULL dispatcher.

FULL now gets bounded background finalization time. A current unfinished capture can also export as explicitly partial evidence; that does not certify complete coverage. See DIFF-v7.592.md, VALIDATION-v7.592.md and COMMANDS.md for the audit, validation limits and phone push/probe commands.

# AmazonDark v7.567~health-raster-map-details

Based on origin/main 16df804e (v7.566). The Health AI banner remains exempt from the taming overlay. Its raster conversion now removes pale translucent edge pixels that previously escaped the alpha threshold, and raises dark cyan title pixels to readable cyan while preserving channel ratios and already-bright glyph colors. This is a raster contrast correction, not another dimming overlay.

The postal-code pin inner SVG Shape now has a white stroke. The map attribution wrapper and button have transparent background colors with the existing black information artwork retained. No geometry changes or recurring scans are introduced.

See COMMANDS.md for the existing-clone push and separate probe handoff. Native compilation and phone rendering verification remain pending.

# AmazonDark v7.566~store-locator-health-art

Based on origin/main 1737a658 (v7.565). The captured APLF store locator now uses OLED floors and action buttons, white neutral text/symbols, gray filter pills and gray existing divider/button borders. Green status copy, blue links and teal selection/pin colors are preserved. The entire map receives the configured brightness factor once; its child canvas/images are exempted from duplicate dimming. The exact map-marker inset shadow is cleared without changing the pin artwork or geometry.

Ask Health AI is lettering and glyph artwork, so its native taming overlay is now removed on image/mount/layout commits. Its OLED raster-floor correction and neutral lettering repair remain; other large service images still use the configured taming policy.

CI now installs the CSS matcher dependencies so cascade regressions run instead of being skipped. See COMMANDS.md for the existing-clone push and separate probe commands. Native package compilation and on-device verification remain pending.

# AmazonDark v7.565~service-sheets-countdown

Based on origin/main 7dd4ad9e (v7.564), preserving the compiler fixture repair and prior UI/probe changes.

The three supplied v7.564 VIEWPORT captures identify the new Home stripe countdown digits and the native Health/Grocery React sheets. Countdown boxes now use OLED black and white digits while retaining the blue banner and stock geometry. The two sheets receive OLED floors, white neutral text and close/chevron glyphs, gray existing borders and gray health action pills. Semantic links and colored logo pixels are preserved. Neutral dark lettering baked into the captured logo/banner rasters is lightened; the large Health banner and Grocery map use the existing preference-controlled image taming.

Sheet discovery uses exact captured leaf witnesses and a single bounded pass after positive identification; mount, layout, text and image commits maintain the styling without recurring scans. No frame, bounds, padding or radius changes are introduced. See VALIDATION-v7.565.md and COMMANDS.md for validation and the existing-clone build/probe handoff. Native Theos compilation and device verification remain required.

# AmazonDark v7.564~compiler-fixture-repair

Based on origin/main e9ca91db (v7.563). This release repairs the isolated Returns/PDP Objective-C++ preflight: it now extracts the complete Pharmacy, Seller, Returns and New Menus helper definitions in their production order. The previous fixture included calls without their declarations and failed before the native build. Compiler errors now appear in assertion output.

The Refunds help-note regression also uses a stable block marker instead of an outdated version comment. Strict validation passes all 217 tests, including isolated compiler checks. All v7.563 Pharmacy styling, image taming, and prior UI/probe behavior remain unchanged. Native Theos build and device verification remain pending.

# AmazonDark v7.563~pharmacy-oled-media

Built from origin/main d021464c (v7.562), retaining its Seller Messaging, keyboard, Filters, Settings, Interests and probe changes.

The supplied v7.562 FULL Pharmacy capture identifies the native teal chrome controllers and the Pharmacy LEGO/PUI web families. This update makes structural floors OLED, neutral headings and copy white, secondary copy legible gray, benefit pills and search fields gray, and action buttons OLED with gray borders. The blue Prime promotion, semantic links, logos and authored layout remain intact.

Large Pharmacy artwork uses the existing configurable brightness-taming strength, with one image-level filter and no container dimming. Declarative styles cover late-loading images without timers, observers or repeated scans. Native chrome is restricted to the three captured controller owners and their exact teal color.

See COMMANDS.md for the existing-clone update and separate FULL, VIEWPORT and TRANSITION commands. Native build and device verification are still required.


## v7.562 Seller Messaging Assistant dark-mode completion

Builds on v7.561. The supplied v7.556 VIEWPORT archive is the earlier Refunds help-article capture rather than the Seller Messaging Assistant screen shown in the screenshot, so v7.562 does not pretend that archive exposed Seller Messaging DOM owners. Instead the new production owner is strictly route-gated to Amazon's Seller Messaging Assistant contact-seller family (`/gp/help/contact-seller/contact-seller.html`) and child frames whose referrer is that route.

Within that route only, structural page/card/container floors are OLED black, chat bubbles and controls use neutral dark gray, neutral dark copy is lightened, authored interactive/dynamic colors remain currentColor, borders are standardized gray, and product-sized non-logo images receive the existing configured TWB brightness. The image pass is finite and route-local: it inspects only `document.images` immediately/once at page load and adds no MutationObserver, timer, RAF, scroll listener, polling loop, or recurring hierarchy scan.

v7.561 Refunds help-note OLED, v7.560 Returns-success alert ownership, v7.559 order-item theming/count geometry, and v7.558 Filters/probe-routing work are retained.
