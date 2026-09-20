# AmazonDark v7.431 — PDP r2-r5 completion

Exact parent: v7.430 `native-review-menu`. All earlier fixes are retained.

This build addresses the four outstanding v7.429 FULL r2-r5 screenshot/probe misses without adding a new runtime engine:

- **Sponsored hero video ad:** themes the exact `universal-hero-quick-promo` / APE shell and lets neutral structural wrappers inside PDP ad frames inherit the OLED body, while leaving video/photo media under existing TWB handling.
- **Product image gallery:** catches the actual AUI expander heading/prompt family so the header renders light instead of dark-on-black.
- **Yellow / Blue inline swatches:** forces the live `image-swatch-button sml-image-swatch-button` floors to OLED black while leaving selected-outline ownership intact.
- **$59.97 ad / related product family:** themes the exact lower `btf2` APE placement and keeps neutral sponsored-carousel prices light without overriding authored `.a-color-price` colors.
- **Similar brands on Amazon:** changes the exact multi-brand video card/container edges to AmazonDark's standard `#494d4d` gray without changing the video/image treatment.

The fix remains event/document-injection based. No new MutationObserver, timer, RAF loop, web scroll listener, or recurring hierarchy sweep is added. FULL, VIEWPORT, and TRANSITION probe identities advance to v7.431.

See `AUDIT-v7.431.md`, `VALIDATION-v7.431.md`, and `COMMANDS.md`.
