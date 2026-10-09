# AmazonDark v7.602 — PDP visual repair

- Frequently bought together: fixes the CSS specificity conflict with the legacy v7.439 `filter:none!important` rule. The exact bundle artwork rules now win on every bundle card, including `_feature_div_1` and subsequent cards. Image dimming still follows the existing preference strength/toggle.
- Buy all: makes the label and price descendants transparent, preserving the gray pill, border and geometry.
- Complementary circular plus buttons: clears the black `sp-mobile-dp-mosaic-atc-button-*` wrapper and its form/container backgrounds. Retains the gray circular button, dark ring and white plus.
- Similar products: resets `mix-blend-mode` on the captured `_cDEzb_imageDisplay_` parent. The product image was already loaded, visible and tamed; multiplying its parent against the OLED floor hid it. Preserves the original image size and loading behavior.
- Similar products Add to Cart: targets the actual span-based button and makes its outer surface OLED with one gray border, white text and transparent inner layers.
- Review menu product header: makes the captured `#mobile-product-reviews > .a-subheader > a > h4` white. It has none of the title classes guessed previously; the general heading rule excluded linked descendants.
- Synchronizes package, runtime, probe and helper identities to v7.602. FULL/VIEWPORT/TRANSITION behavior and TAR packaging remain as v7.601.

All repairs are declarative CSS. No new scan loop, observer, timer, network/image reload, or layout dimensions/radii were added.
