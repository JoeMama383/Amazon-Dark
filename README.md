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
