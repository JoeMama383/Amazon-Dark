# AmazonDark v7.403 audit — Product Share sheet + probe control

## Base
- Direct parent: `7.402~payment-first-paint-switcher-fix`.
- All v7.402 payment first-paint, app-switcher, pickup-transition, chevron and payment-art fixes are preserved.
- Evidence: `AmazonDark-v7.402-ui-full-probe-20260910-234738-250-r2.zip` plus the historical v7.254/v7.257 SSF Cart Share implementation.

## Probe-backed diagnosis
The Product-page “Share this product with friends” sheet is the same SSF AUI renderer already themed for Cart: `.a-sheet-web:has(.ssf-customize-container-one)`. The old production selector unnecessarily required `body:has(#sc-page-container)`, so Product Share escaped the existing theme even though its inner renderer family is identical. The current probe shows white sheet/channel floors, a white `.ssf-preview-box`, a gray `.ssf-product-title-text`, black channel labels, a CSS-background backend preview, and the `ssf-share-channel-*` image family.

## Fix
- Generalize the existing SSF contract from Cart-route-only to the exact SSF renderer family.
- OLED sheet/content/heading/channel/product-title floors.
- Standard `#747a7c` preview edge; light neutral heading/title/channel/review-count text.
- Preserve authored links and semantic colors.
- Keep neutral pressed/focus row states dark.
- TWB tames only the backend preview raster, HTML product image fallback, and exact share-channel images. No invert/grayscale is used, so app branding and orange rating stars keep their hue.
- Product preview remains visible; the historical v7.257 `#ssf-preview-container` exclusion is retained.

## Probe testing preference
Adds **Hide Share Sheet for Probes**, default OFF. When enabled (after respring), a document-start CSS rule hides only the SSF share sheet/lightbox so a screenshot-triggered universal FULL probe can inspect the UI underneath. Manual Share is also hidden while the testing preference is enabled. No observer/polling loop is introduced.

## Architecture
- New MutationObserver: 0
- New interval/poll loop: 0
- New RAF loop: 0
- New Web scroll listener: 0
- New recurring hierarchy scan: 0
- New WKUserScript family: 0 (the suppression program is concatenated into the existing immutable core document-start script)

## Device validation
1. Product Share: all sheet/channel floors OLED, neutral text light, preview border gray.
2. Preview product image is tamed while orange stars remain orange.
3. Messenger/Snapchat/Telegram/Reddit/X/Messages/Email/Copy/More art is tamed without hue inversion.
4. Press/hold share rows do not flash white.
5. Enable Hide Share Sheet for Probes, respring, take a screenshot on a target menu: FULL probe triggers but SSF does not cover the target. Disable afterward for normal sharing.
