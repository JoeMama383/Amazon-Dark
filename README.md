# AmazonDark v7.212~person-rounded-border-media-parity-probe

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