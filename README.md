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
