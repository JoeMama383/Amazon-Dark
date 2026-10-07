# AmazonDark v7.590 diff

Base actually installed/tested by user: `v7.585~medical-auth-probe-followup`

Target: `v7.590~cumulative-ui-universal-full-shop-show`

This source is cumulative. It does **not** require v7.586, v7.587, v7.588, or v7.589 to have been installed first.

## Retained post-v7.585 UI fixes

### Medical / Health AI / authentication
- Health AI neutral dark SVG/icon paint -> white while authored dynamic colors remain authored.
- Ask Health AI send/up-arrow owner -> host gray, with the separately drawn border removed.
- Health AI quick-action / recommendation fades and masks -> transparent where probe-proven.
- Health AI primary/yellow pills -> OLED black, standardized gray border, white text.
- Health AI image/SVG owners are kept visible; recommendation/card floors remain OLED.
- Verification/CVF footer, helper/offset rows, and gradient families -> OLED black.
- Verification help copy above `change your number` -> white while authored links retain authored color.
- Verification Amazon-logo strip -> OLED black; Amazon logo asset inverted for dark presentation.
- One Medical `links-bottomsheet` modal shell/content floors -> OLED black; text stays white and `mobile-kyanite-logo` is inverted.
- ZIP bottom sheet `glowModal` -> OLED black.
- One Medical account-confirm / continue-family control -> OLED black, gray border, white text.

### PDP coupon / media / sustainability
- Exact dual-stage coupon owner `#promoPriceBlockMessage_feature_div` -> dark green on both stages with white descriptive/price text.
- Claimed coupon success icon background -> OLED black; check glyph remains white.
- `#dynamicPackageInfoFeature_feature_div` link/message -> visible blue instead of dark-on-dark.
- Fullscreen product-image thumbnail rail `SNPRootView -> RCTView#thumbnails-view` -> OLED black.
- Exact thumbnail raster leaves under that rail use the existing user-controlled Tame Light Backgrounds strength.

### Person / Orders / Your Review
- Compact 174x50 Search Orders host is recognized separately from the historical ~360x50 host.
- Its 20x20 magnifier raster is owned by the existing Search Orders magnifier path and paints light like the adjacent text.
- Exact `#cr-single-review` review card/body -> OLED black.
- Review title/profile/header dark neutral text -> white.
- Review body copy -> white.
- Edit/Delete review controls -> OLED black, white text, standardized gray border.
- Stars, orange Verified Purchase, gray metadata, and authored semantic colors remain authored.

## v7.590 Shop the Show media

Probe family is native React/AppCX, not WebKit. Exact scope is restricted to ancestry under:
- `RCTView#home-page-banner`
- `RCTView#keep-shopping-the-shows`

### Product image families
- White/near-white floors under exact `product-container-*`, `product-image-*`, `product-image-view-*`, and `keep-shopping-product-button-*` owners -> OLED black.
- Product raster leaves under `product-image-view-*` and `keep-shopping-product-button-*` use `ScaleAspectFill` + clipping so authored white outer canvas/margins are cropped rather than displayed as a white plate.
- These exact product raster leaves are tamed using the existing user-configured TWB strength.

### Hero / show media families
- Raster media under `mosaic-content-card_*`, `campaign-card_*`, `navigation-thumbnail-image-*`, and `keep-shopping-the-shows` is tamed through the existing TWB overlay.
- Existing authored hero crop/geometry is retained; v7.590 does not redraw card geometry.

## v7.590 FULL probe renderer arbitration

The Shop the Show viewport probe proved `webviews=0` and a retained React/SNP page stack. The old generic native fallback could see multiple still-mounted `RCTScrollView` roots and spend the FULL traversal on a covered/retained page. Backgrounding while that FULL was active therefore emitted `armed-background-during-full` immediate evidence and a partial VIEWPORT export.

v7.590 changes normal FULL discovery to renderer-neutral dynamic ownership:
- WebKit documents remain discovered/scanned automatically.
- Native UIKit and React Native scroll views are discovered through the same generic native path.
- Native/RN candidates are foreground-qualified by 3x3 UIWindow hit-testing against their visible intersection.
- Covered/retained scroll roots are rejected and logged with ownership/hit ratios.
- Visible foreground native candidates are ranked and scanned cooperatively, with original offsets restored.
- Exact Menu and Person FULL walkers are retained only as fallback contracts if generic foreground discovery produces no candidate.
- PDP retains its existing duplicate-scroll protection: WebKit DOM owns product-page scrolling while native hierarchy evidence is still captured.
- No production observer, polling loop, recurring timer, RAF loop, or recurring hierarchy walker was added.

## Validation-related cleanup
- Shop the Show helper implementation was moved outside an isolated native compile-fixture slice; only forward declarations remain before the generic UIView hook.
- Current package/probe/launch identities are synchronized to v7.590.
