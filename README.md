# AmazonDark v7.264~person-refresh-raster-edge-probes

## v7.264 standalone full-raster separator cleanup

- Builds directly on v7.263 and retains the Person refresh/remount image re-tame repair plus every v7.262 Hamburger footer fix.
- Historical v7.174 full-raster evidence identifies the bright strip as a dedicated zero-content `div.border-enforcement` measuring 430x2 with inline `border:1px solid #ccc`; the captured full-raster image itself is a separate 828x250 authored raster. The retained capture carrying that exact separator is a 414x125 `ape_search_*` placement, while the supplied screenshot shows the same renderer strip on Home, so the defect is renderer-specific rather than Home-only.
- Reviewed compact 320x50 captures do not expose `border-enforcement`; that renderer already owns its separate rounded 1px parent placement border, which remains unchanged.
- The reviewed v7.183 large Home image-only 300x250 / ~430x358 capture does not expose `border-enforcement`; its full-raster TWB path remains unchanged. The retained probe corpus does not establish a separate XL full-raster renderer, so no XL-specific rule is invented.
- v7.264 changes only the exact `.border-enforcement` child-frame separator to OLED black (background/border/outline). It is installed in the general child-frame first-paint floor sheet and repeated in the existing Home standalone shell-survival sheet. It does not touch the raster, Sponsored feedback row, media TWB, dimensions, margins, padding, radius, iframe geometry, or hit targets.
- Cart/Person/Menu probes remain finite and explicit-trigger only, now exported with v7.264 filenames. No MutationObserver, interval, RAF loop, web scroll listener, polling loop, or recurring production hierarchy scan is added.


## Probe-backed Person savings sheet + final Hamburger cleanup

- Builds directly on v7.258 and retains all Cart, Cart Share, Person, and Hamburger fixes already present.
- Uses the corrected v7.258 Person probe's selected foreground `RCTView#sheet-view` / `sheet-inset-view` surface, uniquely gated by `cvm-metab-bottomsheet-titlettl`, to theme the actual visible “Your savings with Subscribe & Save” sheet rather than the hidden AppCX bottom-sheet tree.
- Converts the live sheet's white root (including the exposed top and bottom strips) and its near-white 400x251 savings card to OLED black.
- Converts neutral dark/gray sheet text to AmazonDark light while preserving authored saturated colors, including orange/yellow savings semantics and Amazon blue links. The black close symbol is included in the neutral-text repair; the gray drag handle and authored colored bars remain stock.
- Forces configured TWB at final layout for exact `subtheme_image_*` UIImage-backed Hamburger column artwork. RNSVG/SVG remains completely outside this path and untamed.
- Makes expanded Hamburger subtheme-row borders structural rather than state-dependent: the real 376x50/radius-16 two-child row owns one standard gray border, while same-geometry zero-child border/highlight shells are cleared. This explicitly covers the probe-proven Travel (`sbdlt`) row whose stock primary border width is 0 while neighboring rows report 1.
- Stops AmazonDark from writing any border property on the three Hamburger footer actions (`account_switcher`, `so`, `cs`). Their gray fill/light text remains themed, while Amazon alone owns the surviving stock border.
- Cart/Person/Menu probes remain finite and explicit-trigger only, now exported with v7.263 filenames. No MutationObserver, interval, RAF loop, web scroll listener, polling loop, or recurring production hierarchy scan is added.

# AmazonDark v7.258~menu-single-border-person-sheet-probe

## Menu single-border cleanup + corrected Person savings-sheet discovery

- Builds directly on v7.257, retaining the completed Hamburger dropdown floor/glyph fixes, Hamburger footer raster restoration, and Cart Share product-preview restoration.
- Removes the conflicting Menu border channels responsible for the three gray footer rows looking double/triple outlined. Menu cards/buttons now use one generic React border width/color; all per-edge width/color overrides are explicitly reset and CALayer borders remain off.
- The supplied v7.256 Person probe proves the earlier AppCX snapshot did **not** capture the visible Subscribe & Save savings sheet: it selected an AppCX tree whose React payload contains the Alexa/shopping navigation header and whose bottom sheet only intersects the bottom of the screen. v7.258 therefore does not guess at the savings card/header renderer.
- Refines the Person probe to enumerate every foreground window, discover every `AppCXTouchPassthroughView`, score each candidate by the visible area of its actual bottom-sheet descendants, snapshot the top three AppCX candidates, and also snapshot the top three non-Person modal/presentation candidates. This is designed to capture the real savings sheet in the next run.
- Person probe cap is raised to 64 MiB only for the explicit finite diagnostic so the additional modal snapshots are not truncated. Normal production runtime remains event-driven and unchanged.
- Cart/Share and Hamburger fixes from v7.257 remain in place; no new broad visual rule is applied to Person until the corrected probe identifies the actual savings-sheet renderer.
- No MutationObserver, interval, RAF loop, web scroll listener, polling loop, recurring timer, or production hierarchy scanner is added.

# AmazonDark v7.257~menu-dropdown-share-preview-fix-probes

## Hamburger expanded-row completion + Cart Share preview restoration

- Builds directly on v7.256 and retains its Cart Share sheet, Cart semantic colors, attempted Person AppCX ownership, and final v7.255 Hamburger top-level theming. The later v7.256 on-device Person probe showed that the first AppCX-root probe did not actually select the visible Subscribe & Save savings sheet; v7.258 corrects that diagnostic gap.
- Uses the supplied v7.256 full Hamburger probe to generalize expanded dropdown row ownership to the exact `subtheme-card-view` container plus its repeated 376x50/radius-16 physical row geometry, covering dynamic category IDs that the earlier six-ID list missed. Each expanded row is OLED black with one standard gray React border; duplicate stock border shells are retired.
- Expanded `subtheme_image_*` raster artwork is restored as authored pixels and routed through the configured native TWB strength. This applies only to UIImage-backed dropdown artwork; RNSVG/SVG views remain outside the taming path and unchanged.
- Restores the bottom Hamburger helper row's leading 54x60-source raster from AlwaysTemplate to AlwaysOriginal using its exact 406x~23 two-child footer structure, removing the blank white circle while leaving that authored footer artwork untamed.
- Fixes the only remaining v7.256 Cart Share regression: `#ssf-preview-container` is excluded from the structural `.a-padding-base` floor rule that was clearing its CSS `background-image`. The existing exact preview TWB selector remains authoritative, so the product image is visible and tamed while the OLED preview frame/title styling stays unchanged.
- Cart, Person, and Hamburger finite screenshot/SIGUSR2 probes remain available under v7.257 filenames.
- No MutationObserver, interval, RAF loop, web scroll listener, polling loop, recurring timer, or production hierarchy scanner is added.

# AmazonDark v7.256~cart-person-completion-probes

## Probe-backed Cart + Person completion with v7.255 Hamburger fix retained

- Builds from the final v7.255 Hamburger/Menu source and retains that exact Menu surface ownership: OLED rows/expanded cards, standard gray borders, light neutral text, restored authored category artwork, and featured-program TWB.
- Restores Amazon-authored Cart semantic accents proven by the v7.254 probe: success/stock messaging remains green and the exact Free Returns action remains Amazon blue instead of being flattened to the global light foreground.
- Repairs Saved for Later product-title/price text and the newer `_sp-cart-mobile-carousel` Items-related faceout neutral/price text without recoloring Prime, deal, coupon, success, or other authored accent lanes.
- Themes the Cart SSF Share sheet at document start: OLED structural floors, light neutral heading/title/channel labels, standard neutral preview border, configured TWB on the large CSS-background product preview, and configured TWB on the share-channel glyph rasters.
- Themes the exact AppCX native/React bottom sheet used from Person: neutral near-white floors become OLED, neutral near-black text becomes the standard light foreground, saturated/dynamic Amazon colors remain authored, and the two bright passthrough safe-area/chrome sibling strips are now owned without touching the gray drag handle.
- Retains Cart, Person, and Hamburger/Menu finite screenshot/SIGUSR2 forensics probes, now exporting v7.256 filenames; when the Person AppCX savings sheet is visible, the Person trigger also records one bounded external-sheet snapshot so its chrome/text/image/layer paint can be verified directly.
- Normal runtime remains event-driven: no MutationObserver, interval, RAF loop, web scroll listener, polling loop, recurring timer, or full hierarchy scanner is added.


# AmazonDark v7.254~three-tab-forensics-probes

## Cart + Person + Hamburger/Menu diagnostics restored

- Exact visual/production base is v7.253; finalized Cart and Person theming is unchanged.
- One screenshot or SIGUSR2 now dispatches to the currently selected `cartTab`, `meTab`, or `menuTab`.
- Cart restores the comprehensive finite WKWebView full-document probe from v7.251, now exporting `AmazonDark-v7.254-cart-ui-probe-*`.
- Person restores the comprehensive finite React/native top-to-bottom probe from v7.240, now exporting `AmazonDark-v7.254-person-ui-probe-*`.
- Hamburger/Menu retains the v7.253 hybrid WebKit/native discovery probe, now exporting `AmazonDark-v7.254-menu-ui-probe-*`.
- A single dormant screenshot notification observer and a single SIGUSR2 dispatch source replace three independent trigger registrations.
- No MutationObserver, interval, RAF loop, web scroll listener, polling loop, or recurring native hierarchy scanner is added.

# AmazonDark v7.253~cart-controls-sheet-recs-menu-probe

## Cart controls, long-press sheet, related-item TWB + retained Menu probe

- Builds directly on v7.252 and retains the exact Prime-adjacent Cart recommendation subtext fix unchanged.
- Styles the probe-proven Cart Undo and Clip-to-Save AUI buttons into the same medium-neutral #303335 / #747a7c family as Delete, Save for later, Share and Compare.
- Styles only the Subscribe & Save outer AUI box; the stock switch is preserved explicitly as gray when OFF and Amazon blue `rgb(33,98,161)` when ON, with its stock white thumb.
- Fixes the quantity-stepper `a-icon-small-remove` sprite so the minus uses the same white transform as the adjacent `a-icon-small-add` plus.
- Darkens the exact long-press `p13n-uf-bottom-sheet_*` AUI sheet: OLED floor, checkout-style OLED/gray-border action buttons, light action text, preserved Amazon-blue product title, and configured TWB on the product image.
- Adds configured TWB ownership for the modern `_sp-cart-mobile-carousel` `img.sp-dynamic-image` product lane used by the Items-related-to-cart carousel.
- Keeps the v7.251 dark loading-card placeholder fix and all earlier Cart/Person/Search owners.
- Retains the v7.252 Hamburger/Menu hybrid forensics probe. Screenshot/SIGUSR2 remains the only trigger; normal runtime adds no MutationObserver, interval, RAF, web scroll listener, polling loop, or recurring hierarchy scan.

# AmazonDark v7.252~cart-subtext-menu-ui-forensics-probe

## Final Cart recommendation text + Hamburger/Menu hybrid forensics

- Fixes the exact Cart recommendation `a-size-mini a-color-base` delivery/history lane next to Prime: stock near-black text becomes AmazonDark light while authored Prime blue, star orange, price red, links, success/deal colors and other dynamic colors remain untouched.
- Retains the v7.251 exact `a-carousel-card-empty > .a-loading-static` loading-card treatment and every finalized Cart/Person visual owner.
- Moves the explicit-trigger probe from Cart to the Hamburger/Menu tab. Historical probes identify the stable tab owner as `ANXTabBarButton#menuTab`.
- The Menu probe is renderer-agnostic: it inventories every visible WKWebView and native scroll candidate, performs a full finite WebKit document walk when a Menu-like web surface is present, and performs a finite native/React scroll walk when a native surface is present. Hybrid panes can capture both.
- Each node records technical identity, geometry, paint, borders, text colors/fonts without text strings, image/rendering state, control state and layer/vector details. Original scroll offsets and scrollEnabled state are restored.
- Normal runtime remains event-driven: no MutationObserver, interval, RAF loop, web scroll listener, polling loop or recurring hierarchy scanner is added.

# AmazonDark v7.251~cart-loading-card-placeholder-fix-probe

## Exact Cart loading-card placeholder ownership

- Builds directly on v7.250 and keeps the successful Person top-pill white-text fix unchanged.
- The v7.250 Cart probe finally exposes Amazon's real pre-hydration recommendation placeholder: `li.a-carousel-card.a-carousel-card-empty > div.a-loading-static`, a 120x120 stock `rgb(243,243,243)` loading card with ~#eee borders and an `a-loading-static-inner` background-image sprite.
- Retires the v7.249/v7.250 compositor-TWB experiment and restores the proven v7.248 direct-image TWB path for finished recommendation product images.
- Styles only the exact empty loading card at document start: #303335 floor, #494d4d edge, no stock inset shadow; its small loading sprite is converted to a subdued light-on-dark indicator. No image delay, polling, observer, or hydration watcher is required.
- All completed Cart floors/buttons/text/stepper/refresh fixes and the retained Cart forensics probe remain intact.
- Cart probe remains screenshot/SIGUSR2 triggered and exports `AmazonDark-v7.251-cart-ui-probe-*`.

# AmazonDark v7.250~cart-placeholder-person-pill-text-probe

## Cart placeholder compositor ownership + Person top-pill text

- Builds directly on v7.249; all completed Cart styling, Person borders/floors, Search fixes, universal OLED keyboard, and the explicit Cart forensics probe remain intact.
- Moves Cart recommendation TWB one level farther outward to the probe-proven 150x115 `a-section.a-spacing-mini.aok-relative` image compositor. The failed v7.249 rule owned only its child link, allowing Amazon's pre-image placeholder paint to remain bright.
- The compositor owns a medium-gray loading floor plus the configured TWB brightness. Its child link and finished product IMG stay transparent/filter-free, so the placeholder and final image receive one—and only one—TWB pass.
- Uses the v7.238 Person probe's exact top-pill owners (`bac_yo`, `bac_ya`, `bac_wl`, `bac_aiwl`) to force only their direct 15pt `RCTTextView` leaf to the standard light foreground. Existing pill geometry, OLED floor, and gray React border are untouched.
- No MutationObserver, polling loop, interval, RAF, web scroll listener, or recurring hierarchy scan is added.
- Cart probe remains screenshot/SIGUSR2 triggered and exports `AmazonDark-v7.250-cart-ui-probe-*`.

# AmazonDark v7.249~cart-carousel-placeholder-twb-probe

## Cart recommendation placeholder first-paint TWB

- Keeps the fully fixed v7.248 Cart production styling and retained Cart forensics probe.
- Moves TWB ownership for the exact p13n Cart recommendation image slot from the eventual product IMG to its 150x115 image-link compositor.
- This shades Amazon's bright placeholder raster immediately while the recommendation image is loading, then applies the same configured TWB strength to the finished product image without double-darkening it.
- Scope is limited to `#cart-atf-recommendations`, `#sc-recs-atf-widget`, and `#sc-recs-btf-widget`; recommendation text, stars, Prime badges, prices, Add-to-cart buttons, and non-Cart images are unchanged.
- No observer, timer, RAF, scroll listener, or recurring scan is added.

# AmazonDark v7.248 — Cart buy-box refresh-floor first-paint ownership

## v7.248 delta

- Directly builds on v7.247. All settled Cart theming is unchanged; the quantity stepper, buttons, text, floors, and product/recommendation TWB remain as already fixed.
- The v7.247 probe proves `.sc-cart-spinner`, `html/body/#a-page`, `#sc-page-container`, the native `AWWebCartViewController`/`SMASHWebContainer`, and the settled `#sc-buy-box`/`#sc-mini-buy-box` are already OLED black. The remaining white pill therefore belongs to Amazon's short-lived buy-box refresh/hydration content, not the page spinner or WebView backing.
- Owns every direct Cart page child floor as OLED black from document start, then makes transient descendants/pseudo-elements inside only `#sc-buy-box` and `#sc-mini-buy-box` transparent over that black floor. The established checkout button rule that follows still owns the visible checkout button as OLED black with the existing gray border/light text.
- Disables only CSS transitions on those two buy-box subtrees so Amazon cannot interpolate a temporary stock-light background during refresh. No mutation observer, timer, RAF, scroll listener, or delayed repaint path is added.
- Cart probe remains screenshot/SIGUSR2 triggered and exports `AmazonDark-v7.248-cart-ui-probe-*`.

# AmazonDark v7.247 — Cart refresh transition floor + stepper fill geometry

## v7.247 delta

- Directly builds on v7.246; all successful Cart theming, product/recommendation TWB, Search/Person fixes, and the full-document Cart probe remain intact.
- Corrects the quantity stepper in the requested direction: the 126x32 fieldset shell remains transparent, while Amazon's stock 126x28 inner pill regains its original geometry and alone owns the #303335 fill plus the existing #747a7c border. No border geometry is stretched.
- Uses the probe-confirmed fixed `.sc-cart-spinner` as the Cart refresh transition owner. When Amazon makes that loader visible, it now covers the web viewport with OLED black from document-start CSS; the spinner child itself stays transparent so no white loading floor can show through.
- This complements the existing v7.129 Search-style early WKWebView/WKScrollView/WKContentView OLED backing ownership, which already applies before attachment; no polling or delayed repaint path is added.
- Cart probe remains screenshot/SIGUSR2 triggered and exports `AmazonDark-v7.247-cart-ui-probe-*`.
- No product-image/TWB selectors or already-correct Cart button/text rules are changed.

# AmazonDark v7.246 — Cart separator + quantity-stepper geometry cleanup

## v7.246 delta

- Directly builds on v7.245; all successful Cart theming, product/recommendation TWB, Person/Search fixes, universal OLED keyboard ownership, and the Cart full-document probe remain intact.
- Probe-backed saved-cart separator fix: preserves Amazon's 13px top/bottom spacing on `#sc-saved-cart` but repaints those exact `#eaeded` borders OLED black.
- Probe-backed quantity-stepper fix: removes the duplicate medium-gray floor from the 126x32 fieldset shell and makes the exact inner pill own the medium-gray fill + single gray border at the full stock geometry.
- No product-image selectors, recommendation-image filters, button text rules, or other Cart borders are changed.
- Cart probe remains screenshot/SIGUSR2 triggered and exports `AmazonDark-v7.246-cart-ui-probe-*`.

# AmazonDark v7.245 — Shopping Cart probe-backed first-pass theming + Cart probe

## v7.245 delta

- Directly builds on v7.244; finalized Person/Search/native magnifier and universal OLED keyboard ownership are unchanged.
- Uses the v7.244 full-document Cart probe to move Cart floors to OLED black at document start, while leaving the existing product-image TWB selectors untouched.
- Cart Add-to-cart and Proceed-to-checkout buttons now reuse the Search-result primary-button contract: OLED floor, #747a7c border, light text.
- Cart item quantity/action controls use one medium-neutral #303335 floor, #747a7c border and light text; Rufus/other authored child imagery is preserved.
- Restores light Subtotal, gift, Cart primary/delivery text, Returns header/body, Prime Business primary text, and recommendation headings while preserving authored blue/green/red/orange/Prime accents.
- Adds TWB only to the exact Returns box raster and Prime Business card raster; existing Cart product/recommendation image taming is unchanged.
- Retains the screenshot/SIGUSR2 Cart full-document forensics probe, now exporting `AmazonDark-v7.245-cart-ui-probe-*`.
- No MutationObserver, interval, RAF loop, web scroll listener, polling loop, or recurring hierarchy scanner is added.

# AmazonDark v7.244 — Search leading magnifier regression fix + Cart probe

## v7.244 delta

- Fixes the regressed main Search-bar leading magnifier using the exact semantic owner proven by older Search probes: 24x24 `SBSearchBarIconView` inside `SBSearchBarLeadingStackView`.
- Restores `UIImageRenderingModeAlwaysTemplate` plus the standard light `#e8e6e3` tint on assignment/mount/layout, matching the camera and microphone glyphs.
- Retains v7.243's universal OLED keyboard and Person Orders magnifier fixes unchanged.
- Retains the Shopping Cart full-document forensics probe, now exporting `AmazonDark-v7.244-cart-ui-probe-*`.
- No MutationObserver, interval, RAF loop, web scroll listener, or recurring hierarchy scan is added.

# AmazonDark v7.243 — universal OLED keyboard + Person Orders magnifier + Cart probe

## v7.243 delta

- Keeps the proven v7.242 single-border ownership for Person > Your Orders search unchanged.
- Makes the existing v7.126 OLED keyboard architecture universal inside the Amazon process: every native text responder requests `UIKeyboardAppearanceDark`, while the existing keyboard floor/prediction/dock owners stay OLED black regardless of Amazon's light app trait.
- Fixes the exact Person Orders 20x20 magnifier identified by the v7.240 probe (`RCTUIImageViewAnimated <- RCTImageView`, direct child of the 360x50 inner search shell) by enforcing template rendering plus the standard light glyph tint at final layout.
- Retains the v7.241 Cart full-document forensics probe, with v7.243 output filenames.
- No MutationObserver, timer, RAF loop, web scroll listener, or recurring hierarchy scan is added.


- Keeps the v7.241 Shopping Cart WKWebView forensics probe, but relocates the Logos `%ctor` boundary above the probe implementation so the long JavaScript/Objective-C probe body cannot poison Logos directive-depth parsing.
- Person > Your Orders expanded search now has one gray 1pt rounded outer border; the nested 2pt/1pt React border pair and cached border rasters are retired.
- The exact Person Orders `RCTUITextField` / `RCTSinglelineTextInputView` / `RNCEKVTextInputFocusWrapper` chain now requests `UIKeyboardAppearanceDark`, reusing the existing v7.126 OLED keyboard owner used by Search.
- Person theming otherwise remains the finalized v7.240 production result.
- Cart probe remains screenshot/SIGUSR2-triggered and finite; no MutationObserver, interval, RAF loop, web scroll listener, or recurring hierarchy scanner is added.

# AmazonDark v7.241 — Shopping Cart UI forensics probe

## Cart probe moved from Person to the Cart WKWebView

- Builds directly on v7.240 and does not change finalized Person theming.
- Replaces the explicit-trigger Person forensics target with the Shopping Cart web document.
- Cart targeting follows the project’s established web owners: `#cart-page`, `#sc-active-cart`, `#sc-saved-cart`, `.sc-list-item`, with a cart-route fallback.
- Screenshot/SIGUSR2 performs one finite top-to-bottom WKScrollView hydration walk, captures viewport DOM computed paint/geometry/technical attributes plus native UIKit/WebKit hierarchy, records one final full-document inventory, and restores the original offset.
- Visible text strings, aria-label/alt/value contents, href/src URLs, and network payloads are not dumped.
- Probe remains dormant outside an explicit trigger; no MutationObserver, polling timer, RAF loop, or web scroll listener is added.

# AmazonDark v7.239~person-final-cleanup

## Finalized Person ownership + production cleanup

- Repairs the exact top-row Person primary text leaves under `xopufnv` (greeting) and `calv` (language label) to light text at final draw.
- Makes the persistent 400x108 Lists & Registries viewport the sole section outline owner; recycled 400x106 / 360x95 carousel contents have their border raster and React border widths suppressed.
- Retains v7.238 Buy Again single-border ownership, Highlights arrow cleanup, white Person scroll indicator, authored avatar/badge/flag pixels, and all prior Person theming.
- Removes the completed screenshot/SIGUSR2 Person forensics subsystem and its signal dependency from production.
- No Dark Reader, MutationObserver, timer/polling loop, RAF loop, web scroll listener, or recurring hierarchy scanner.

# AmazonDark v7.238~person-buyagain-highlight-scrollbar-cleanup-probe

## v7.238 final Person cleanup before pane switch

- Repairs deep Buy Again primary/subheader text at final draw through the exact local `tmpWrapperView` / `CardWrapperView` ancestry, even when that leaf sits beyond the older 24-hop Person-root classifier.
- Removes the probe-confirmed anonymous 296x418.7 React border-raster shell under each Buy Again `CardWrapperView`; the corrected 286x416.7 `AmazonDarkPersonBuyAgainOutline7218` is now the sole large-card outline.
- Fixes the Highlights blue-circle arrow by no longer caching unresolved Person raster classifications. Once `tile-image-iconSection-*` mounts, the arrow is rediscovered, its stale TWB square is removed, and only the authored blue circle + light arrow remain.
- Sets the exact Person `RCTCustomScrollView` under `RCTScrollView#me` to the stock white scroll-indicator style, replacing the nearly invisible black 35%-alpha thumb.
- Retains all v7.237 Person fixes and the screenshot/SIGUSR2 Person forensics probe.
- Adds no MutationObserver, interval, RAF loop, web scroll listener, polling loop, or recurring hierarchy scan.

# AmazonDark v7.237~person-post235-completion-probe

## v7.237 complete post-v7.235 Person correction pass

- Audited every user-reported issue after v7.235 against the v7.235 Person forensics capture instead of assuming v7.236 covered them.
- Preserves v7.236's corrected single Buy Again contour on the stock ~286x416.7 geometry and its Buy Again / Subscribe primary-text final-draw repairs.
- Makes Your Interests and Lists & Registries border ownership first-paint deterministic instead of waiting for React's stale bright/square raster to appear.
- Repairs Keep Shopping product title/count text at the exact local card renderer on first draw so recycled rows cannot retain the darker pre-theme color.
- Reveals the already-loaded/tamed Subscribe & Save image by clearing its probe-confirmed empty opaque 60x64 sibling occluder.
- Restores authored stock pixels for the Person avatar, 8x8 notification badge, and country flag; the badge/flag are explicitly excluded from the monochrome top-glyph/right-arrow classifiers.
- Keeps the screenshot/SIGUSR2 Person forensics probe, now with v7.237 owner flags.
- Adds no MutationObserver, interval, RAF loop, web scroll listener, polling loop, or recurring hierarchy scan.

# AmazonDark v7.236~person-buyagain-border-text-firstpaint

## v7.236 Buy Again contour + Person text first-paint correction

- Built directly from v7.235 and preserves every v7.235 Person/UI correction.
- Retargets Buy Again border ownership from the oversized 296x418.7 padding shell to the probe-confirmed ~286x416.7 direct child of `tmpWrapperView`, which is the stock contour with the correct geometry.
- Suppresses that exact stock white raster edge and draws one 1pt standard-gray radius-8 outline on the same physical bounds, eliminating the gray/white double border.
- Adds final-draw text repair for Buy Again and the exact Subscribe & Save `me_tab_delivery_name_a11y_id` delivery wrapper so primary/bold subheaders are light on first paint while normal secondary copy remains secondary gray.
- Updates the Person probe filename/classification path to v7.236 so the corrected border owner and text final-paint lane are explicit in the next capture.
- Adds no MutationObserver, interval, RAF loop, web scroll listener, recurring hierarchy scan, or polling.

# AmazonDark v7.235~person-probe-backed-ui-corrections

## v7.235 probe-backed Person UI corrections

- Built directly from v7.234; all changes below are tied to exact owners visible in the v7.234 Person forensics capture.
- Removes the stale TWB square from the exact Highlights blue-circle arrow leaf without changing Amazon's authored blue circular parent.
- Restores stock pixels at final `RCTUIImageViewAnimated` paint for Subscribe & Save and the three Shop previously watched product leaves, then applies image-only TWB.
- Restores one standard gray rounded border to the two Medical Care cards and each Your Orders `yo_btn` card.
- Makes the non-orange copy in the `$23` savings row light at final draw while preserving the saturated orange savings amount.
- Narrows Buy Again outline ownership to one direct `CardWrapperView` child per carousel page and makes exact empty `undefined-overlay` image occluders transparent, revealing the already-loaded/tamed rasters.
- Replaces the Lists & Registries square cached border raster with one complete 8pt gray rounded outline.
- Replaces the bright empty border-raster plates under `aiwl_widget0/1` with one 6pt standard-gray outline per Your Interests card.
- Retains the screenshot/SIGUSR2 Person forensics probe and adds explicit v7.235 final-raster/card-owner verification flags.
- Adds no MutationObserver, polling loop, recurring hierarchy scanner, RAF, web scroll listener, or recurring timer.

# AmazonDark v7.234~person-stock-raster-restore-fix-probe

## v7.234 Person stock-raster restore fix

- Built directly from v7.233, preserving the v7.232 optimized production architecture and the v7.233 explicit-trigger Person forensics probe.
- The v7.233 Person probe proves the broken Health AI, Prescriptions, compact Reviews thumbnail, and Customer Service leading image all have real CGImage contents but reach final paint as `UIImageRenderingModeAlwaysTemplate` (`mode=2`). That template conversion collapses their authored pixels into the light theme tint, producing the white silhouettes/blank squares visible on device.
- Adds one exact `RCTUIImageViewAnimated` final-render owner for only those probe-backed leaves. It restores `AlwaysOriginal` after React's own image/mount/layout work, so the stock raster/fill survives the late renderer rewrite.
- Medical Care stays fully authored with no TWB. Reviews keeps image-only TWB. The Customer Service/Need Help leading image now also receives image-only TWB after its stock pixels are restored, as requested.
- The exact-leaf owner caches its three-way classification and invalidates on image/superview changes; normal layout reassertion is O(1) and safe for recycled React image leaves. No Person hierarchy scan is added to steady-state rendering.
- The v7.233 screenshot/SIGUSR2 full-menu probe remains available so the corrected leaves can be verified as `mode=1` (`AlwaysOriginal`), with `twb=0` for Medical and `twb=1` for Reviews/Customer Service.
- No MutationObserver, polling loop, recurring hierarchy scanner, RAF, web scroll listener, or recurring timer is added.

# AmazonDark v7.233~person-ui-forensics-probe

## v7.233 Person UI forensics probe

- Built directly from v7.232~production-architecture-optimization; all Person, Search, Home, location, web, launch, TWB, privacy, preferences, and SpringBoard visual ownership remains unchanged.
- Reintroduces diagnostics only as a dormant screenshot/SIGUSR2 probe.
- On the exact Person `RCTScrollView` accessibilityIdentifier `me`, one trigger resolves the real nested UIScrollView, walks the vertical Person menu in bounded overlapping steps, waits briefly for React recycling/hydration, records a deep native snapshot, and restores the original scroll offset/state.
- Captures class/ID/hierarchy/geometry, native and React per-edge border data, CALayer/CAShapeLayer/CAGradientLayer paint, attributed text run colors/fonts (without text strings), UIImage rendering/tint/TWB and Person media/glyph ownership, control/scroll state, and current Person classifiers/overlays.
- Does not record visible text strings, accessibilityLabel text, typed queries, Web DOM, clipboard, URLs, request bodies, headers, or network payloads.
- No MutationObserver, polling loop, recurring hierarchy scanner, RAF, web scroll listener, or steady-state timer is added. Finite dispatch_after calls exist only while the explicitly triggered scan is running.

# AmazonDark v7.232~production-architecture-optimization

## v7.232 production architecture optimization

- Builds directly on v7.231 and preserves its exact Person, Search, Home, location-sheet, web, launch-transition, TWB, privacy, preference, and SpringBoard theming behavior.
- Uses the reviewed Person probe structure to return early for transparent React layout wrappers while retaining every semantic, colored, bordered, raster-backed, and exact-geometry visual owner.
- Caches positive Person/location React-surface ownership and invalidates it on reparent/window transitions, replacing repeated ancestor walks in layout and background-setter hot paths without caching unresolved views.
- Reuses registered React border selectors instead of allocating selector-name arrays for every border correction.
- Makes Person and location-sheet attributed-text repair allocation-free when the requested colors are already present.
- Keeps the exact Highlights wrapper fallback on its dedicated `RCTImageView` hook instead of rechecking it from the generic `RCTView` owner.
- Removes the v7.231 screenshot/SIGUSR2 diagnostic subsystem, signal handler, and file-export code from the production dylib.
- Adds no MutationObserver, timer, RAF, web scroll listener, polling loop, or recurring hierarchy scan. Route CSS/JS and all visual color/geometry contracts are unchanged.

No probe or probe trigger/export command ships in this production build.

## v7.231 Person visible-owner corrections

- Directly based on v7.229; v7.230's sheet-wide Person text change is intentionally excluded.
- Keeps every visible Person right-arrow control in the same light color at final layout and excludes those controls from both native and Highlights TWB overlays.
- Removes the TWB overlays from the authored blue Highlights icon plate and its 24x24 arrow leaf, eliminating the black square while preserving the blue circle and a light arrow.
- Keeps the Health AI and Prescriptions 45x45 icons in AlwaysOriginal mode so their authored multicolor pixels survive React's late rendering-mode rewrite.
- Keeps the Reviews 40x40 compact product image in AlwaysOriginal mode and retains Reviews-only TWB; keeps the 40x40 Customer Service glyph AlwaysOriginal and no-TWB.
- Restores the exact empty Reviews border-plate owner using the guarded v7.229 paint architecture: React's cached bright raster is retired and replaced by one `#494d4d` rounded outline matching neighboring cards.
- Extends the dormant screenshot/SIGUSR2 single-frame probe with exact owner/overlay markers. It captures no visible text strings, typed query, web DOM, or scrolling.

## v7.229 probe-backed visible-frame corrections

- Directly based on v7.228; Person card/border ownership is intentionally untouched.
- Fixes the top Search magnifier from the captured renderer state: the leading 24x24 image was `renderingMode=0` while camera/mic were `renderingMode=2`. The old broad Search subtree walk is removed; only the exact leading magnifier is marked and kept AlwaysTemplate/light on image assignment, mount, and its own layout.
- Fixes captured faint Person text at final draw time only in the proven contexts: Medical Care (`pSec=1`), Reviews (`pSec=3` plus exact `avr_title`), Gift Card action wrappers (`gc0` / `gc1`), and the structurally exact bottom Customer Service row. Prime/link accents remain preserved.
- Fixes the two captured blank white boxes by restoring authored pixels only for the 40x40 Reviews compact image and the 40x40 leading Customer Service image. The Reviews compact image is also allowed through the existing Reviews TWB lane; Customer Service remains no-TWB.
- Reclaims the captured Person section chevrons through their exact footer-wrapper IDs (`yhwftr`, `gpw-footer-idftr`, `gcfooterftr`, `cm_yc-headerftr`) and explicitly excludes them from Person TWB, fixing the dark Highlights/Gift Card/Reviews arrows without broad glyph ownership.
- Fixes the one visible Highlights tile that missed TWB because the probe exposed only its semantic `RCTImageView tile-image-url-*` wrapper (`has=0`) while the neighboring tile exposed an actual `RCTUIImageViewAnimated` raster with `hlTwb=1`. The wrapper receives a TWB overlay only when no raster UIImageView descendant exists, so normal neighboring tiles retain the v7.224 image-leaf owner and are not double-darkened.
- Retains the dormant screenshot/SIGUSR2 single-frame probe and adds markers for the new exact owners. No visible text strings, typed query, web DOM, or automatic scrolling are captured.
- No MutationObserver, polling loop, recurring hierarchy scan, RAF, or web scroll listener is added.

## v7.227 media ownership stabilization

- Built from the stable v7.224 visual base; the unstable v7.225 Person Reviews/chevron experiment is not carried forward.
- Fixes the main-thread recursive background-paint path that could bounce between `RCTView` and `UIView` setters until the stack guard was hit.
- Every AmazonDark-initiated `UIView` background write now goes through one guarded, idempotent writer; exact renderer classes are excluded from the generic UIView owner.
- React lifecycle work is routed once by surface (Person, location sheet, or generic claimed card) instead of running overlapping Person/location ownership on the same view.
- Home visual-category cells now have one exact owner and one uniform medium-gray fill (`#4a4f51`); the old “only gray bright placeholders, preserve colored final cells” split is removed.
- Removes the screenshot/deep-scan runtime, location lifecycle log ring, and unused Home ad-frame diagnostic JavaScript from production.
- Removes redundant layout-time repaint paths for fixed Search, top-nav, bottom-nav, Home-chip, and image surfaces. Image layout now updates overlay geometry only; classification happens on image/mount events.
- Removes mutable `appendFormat:` metadata construction from native image classification hot paths and makes the full location-root first-paint scan one-shot.
- Web ownership is route-exclusive: standalone ad child frames have one dedicated floor/media owner; dead duplicate standalone CSS/TWB selectors in the general Web sheets are removed.
- Retains the first/good v7.222 Person heading draw-time fix and the v7.224 Highlights border/TWB corrections.

No polling loop, MutationObserver, recurring hierarchy scan, screenshot probe, or SIGUSR2 probe ships in this build.

## v7.224

- Keeps the first/good v7.222 Person heading draw-time fix.
- Highlights tile borders now use one topmost exact outline so same-geometry React children cannot cover the straight edges.
- Highlights TWB follows the actual anonymous RCTUIImageViewAnimated raster under `tile-image-*` wrappers.
- Fixes the v7.223 Person deep-probe root: `RCTScrollView` is a wrapper; the screenshot probe now walks its real `RCTCustomScrollView` UIScrollView child.
- Deep snapshots also report image presence/render mode and native RNSVG shape colors for the blank Reviews investigation.


## v7.218 simplified Person visual restore

Uses the v7.217 probes to tighten Person ownership around the actual React cards and media leaves instead of broad panel/raster heuristics. Section-title text is reasserted at the exact hydrated `*ttl` text leaf; Reviews, Interests, Subscribe & Save, Shop previously watched, Buy Again and Highlights image leaves render their authored raster before image-only TWB; Medical Care artwork stays authored; Project Hail Mary regains its outer frame; Highlights keeps one real tile border; and Buy Again owns only the physical ~286pt card host with an OLED floor and one gray rounded outline. No observer, timer, RAF, recurring scan, or web scroll listener is added.

## v7.217 corrective Person visual port

v7.216 is intentionally rolled back at the Person implementation level. Its broad local-section/raster ownership could classify legitimate cards as carousel internals and could suppress arbitrary React `layer.contents`, which caused missing Review content and lost card borders. v7.217 restores the narrower v7.214 Person ownership model, keeps OLED Person floors, prevents the generic React helper from adding a second square CALayer border inside Person, reasserts the exact `*ttl` Person heading bands/section chevrons after React hydration, and adds one narrow Highlights raster/glyph TWB owner for compact tile-widget media plates. No observer, timer, RAF, or scroll scanner is added.


## v7.214 Person carousel ownership + recycled-media TWB hardening

- Person commerce carousels now use one rounded gray outer frame only; recycled page/content views inside the carousel have both React and CALayer borders cleared.
- Tiny 8-10pt carousel indicators are explicitly excluded from Person border normalization so Amazon's authored dot styling is preserved.
- Lists/Reviews forced media invalidates stale native-TWB eligibility when a section becomes positively marked, and positive Person media bypasses an earlier blocked cache.
- Retains v7.213 Home ATF 320x50 compact full-raster standalone-ad TWB coverage and the Person OLED internal-media floor hardening.
- Dynamic native probe adds `pCarouselOuter` / `pCarouselInner` ownership fields.

## v7.212 Person border + media parity

- Removes the v7.211 double-border path on Person: React Native is the sole RCT border renderer; CALayer borders are no longer stacked over rounded React borders.
- Semantic Person cards (top pills, Highlights tiles, carousel image containers) get one standardized gray rounded edge; same-geometry nested wrappers do not get a second square edge.
- Existing authored rounded Person cards retain their radius and receive the standard gray edge, including full-width cards that previously lost an edge.
- Lists & Registries media is marked from the exact `wl_titlettl` section and forced through native TWB without broadening Medical Care.
- Reviews media is marked from the exact `avr_image` owner so the 40x40 secondary review thumbnail is tamed too.
- Highlights `tile-widget-*` / `tile-image-iconSection-*` media is forced through TWB, and the blue 48x48 arrow plate receives the same strength overlay.
- v7.211 Home hero parity / medium-gray Home chip behavior and v7.209 Person crash ABI fix remain intact.
- Dynamic probe now logs both CALayer and RCTView border width/radius to distinguish the two renderers.

## v7.211 compile hotfix + Home hero-row adjustment

- Fixes the v7.210 Theos compile failure by treating `ANXVisualSubNavTextCollectionViewCell` as `UIView *` before reading `window`.
- Escapes literal `100%` CSS values inside the Objective-C `stringWithFormat:` TWB payload (`100%%`) so they are not parsed as format specifiers.
- Keeps the v7.210 Home hero poster/live-media TWB parity correction.
- Changes the Home visual-subnav behavior per device feedback: only bright/white `ANXVisualSubNavTextCollectionViewCell` floors are replaced with medium gray `#4a4f51`. Amazon-authored text, icons, tint, colored chip floors, sizing, corner radii, and interaction are preserved.
- Retains the v7.209 Person crash fix and all v7.208/v7.207 video, Person, Search/location and TWB hardening.
- Screenshot-triggered dynamic probe retained and renamed v7.211.

No MutationObserver, recurring interval, RAF loop, or web scroll listener is added.

---

# Amazon Dark

True dark mode for the Amazon Shopping iOS app - designed to look native instead of simply inverting the screen.

Rootless jailbreak, arm64 + arm64e, iOS 15+.

---

## Install

### Sileo

**[Add Repo](https://joemama383.github.io/add/)**

Tap **Add Repo** to open the repository in Sileo.

If Sileo does not open automatically, add the following source manually:

`https://joemama383.github.io/`

Then find **Amazon Dark** in Sileo and install it.

### Manual Install

**[Download the latest .deb](https://github.com/JoeMama383/Amazon-Dark/releases/latest)**

After installing or updating, respring and relaunch Amazon.

Make sure tweak injection is enabled for Amazon in your jailbreak environment.

---

## Tame Light Backgrounds

Product and advertisement images can contain bright backgrounds that stand out against the dark interface.

Optional **Tame Light Backgrounds** reduces the brightness of these areas to reduce glare, especially when using the app at night.

Taming strength can be adjusted in Settings.

---

## Privacy Mode

Optional **Privacy Mode** blocks known Amazon analytics, crash telemetry, ad-measurement, and related tracking endpoints.

This setting does not need to be enabled for Amazon Dark's visual theming to work.

---

## Dark Launch Screen

Amazon normally displays a bright screen during a cold launch before the app has finished loading.

Amazon Dark replaces this with a dark launch screen for a more consistent dark-mode experience.

---

## 120 Hz

Amazon Dark can optionally request up to **120 Hz** while using Amazon on supported ProMotion devices.

This can make scrolling and animations appear smoother. iOS may still lower the refresh rate depending on Low Power Mode, temperature, hardware, or other system conditions, and higher refresh rates may use more battery.

---

## Settings

Settings → **AmazonDark**

Available options:

- Enabled
- Tame Light Backgrounds
- Taming Strength
- Privacy Mode
- Force 120 Hz

---

## Compatibility

Amazon uses a mixture of WebKit, UIKit, React Native, server-driven UI, advertisements, custom icons, and product media.

Amazon Dark uses targeted fixes for each type of content instead of applying one global visual filter over the entire app.

**The goal: make Amazon look like it actually shipped with a proper dark mode.**

---

## Credits

Amazon Dark is an independent jailbreak tweak and is not affiliated with Amazon.

Maintained by **JoeMama383**.

### v7.227
- Search product media no longer uses multiply blending against OLED black; TWB uses brightness only.
- Person border-only React shells are transparent so they cannot cover sibling media.
- Person image classification gets one post-hydration settle pass plus reparent events, without restoring layout-time scanning.
- v7.226 recursion barrier and global single-owner architecture retained.


## v7.260 compile correction
- Corrected the Person savings attributed-string helper so its lazily-created mutable copy is declared `__block` before assignment from the enumeration block. This is compile-only; there is no UI behavior change from the intended v7.260 build.


## v7.261 Hamburger footer-row parity
- Uses the v7.260 Menu probe’s exact footer hierarchy: each bottom action has a rounded 406x48.7 React shell around a square 404x46.7 action leaf.
- The rounded shell is now the sole visual owner: OLED black fill, 1pt `#494d4d` border, 16pt radius, clipped exactly like the category cards above it.
- `account_switcher`, `so`, and `cs` inner action leaves are transparent so their former `#303335` square fills cannot cover the rounded shell.
- Replaces the stock teal/blue footer edge with the same gray border used by Menu category rows. No extra border layer is added.
- All v7.260 Person savings, Cart Share, Menu column TWB, Travel-row border, stock footer glyph, and SVG exclusions remain unchanged.


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
