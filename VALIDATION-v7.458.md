# AmazonDark v7.458 validation

## Evidence reviewed

v7.458 was built from the exact v7.457 source after directly reviewing `AmazonDark-v7.457-ui-full-probe-20260923-062724-074-r1.tar` and the paired originals `IMG_7093`, `IMG_7095`, `IMG_7097`, and `IMG_7099`. The probe established the exact owners used by this patch rather than relying on screenshot-only guesses.

Confirmed evidence: the Shop Books strip is the `mshop-subnav-*` family; Book Details artwork is `#rich_product_information .rpi-icon` background-image sprites; Frequently Bought Together product images are loaded/tamed but hidden by the parent `_p13n-mobile-sims-fbt_*_image-display__` `mix-blend-mode:multiply`; the FBT button uses a dark `.a-icon-supplemental`; the review search glyph is `#dpx-rex-nice-widget-container .a-icon-search`; the five white feedback controls are the `_shopping-cx-feedback-widget_style_mobileRatingButton__` family; bright divider owners are the captured Product Details/review/solicitation families; the compact child ad exposes exact brand/description/Sponsored/info-icon owners; and the probe recorded `AXFScreenshotToastPresenter -didDetectScreenshot:` as the screenshot-triggered Share presenter.

## v7.458 changes

- Restores **Hide Share Sheet for Probes** (`disableShareSheetForProbes`, default OFF) and suppresses only `AXFScreenshotToastPresenter -didDetectScreenshot:` when enabled. Blanket `NSNotificationCenter` registration hooks and the v7.457 diagnostic header are removed. Manual Share is untouched.
- Darkens the Shop Books subnav, restores Book Details icon visibility, releases FBT images from multiply blending, lightens the FBT chevron and review-search magnifier, darkens the shopping-experience rating buttons, and standardizes the captured bright divider families.
- Restores compact child-ad brand/description visibility and keeps rating/star content visible. Sponsored text and the outer info-glyph path share the same neutral tone while the inner path remains OLED black.
- Extends brightness-only taming to the probe-captured `filter:none` image families: PDP main/alternate gallery, `sp_phoneapp_detail*` image containers, review avatars, Product Details bullet art, and compact child-ad rasters.
- Keeps the fixes declarative/event-driven. No production MutationObserver, polling timer, RAF loop, web scroll listener, recurring hierarchy scan, or new document walker was added.
- Keeps `src/Tweak.xm` below the pre-existing 856,000-byte performance gate: 855,825 bytes.

## Regression validation

`bash scripts/lint-logos.sh`: PASS.

All 136 `tests/test_*.py` regression scripts: PASS in a single parallel run. This includes the v7.458 screenshot-handler test, probe-backed PDP ownership test, SafeFrame emitted-JS syntax test, checkout golden-hash guards, FULL/VIEWPORT probe tests, and the unchanged performance/source-size gate.

`prefs/Resources/Root.plist`: parsed successfully with Python `plistlib`.

Theos/Logos toolchain is not installed in this execution environment (`THEOS` unset and no `logos` executable), so an iOS package compile/install was not claimed here. Final visual behavior still requires the normal on-device build and probe pass.
