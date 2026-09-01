# AmazonDark v7.227~media-ownership-stability-production

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
