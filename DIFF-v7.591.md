# AmazonDark v7.591 diff

Base: v7.590 cumulative source, with probe transport behavior restored from the known-good v7.585 implementation.
Target: `7.591~regression-recovery-medical-search`

## Critical regression recovery

- Restored the entire v7.585 FULL dispatcher/scroll-discovery implementation, with only v7.591 identity changes.
  - exact Menu React walker is again first priority when its exact wrapper owns foreground;
  - exact Person `RCTScrollView#me` walker is again second priority;
  - WebKit documents are still scanned;
  - non-PDP generic UIKit / React `UIScrollView` candidates are still discovered and swept;
  - the v7.590 foreground-hit-test arbitration and `NATIVE_SCROLL_REJECT` gating are removed.
- Fixed the v7.588 PDP thumbnail TWB helper so it is additive-only.
  - It may add TWB to exact product-image thumbnails.
  - It can no longer remove the shared `kADTWBOverlay` from unrelated Person/Home/Menu images.
  - This restores the v7.585 Person media-taming contract.

## One Medical / medical sheets

- `pui-bottom-sheet#glowModal` and `pui-bottom-sheet#links-bottomsheet` are now themed inside their actual open Shadow DOM roots rather than relying only on document CSS.
- ZIP sheet white modal shell/floor -> OLED black; input stays dark gray; Apply stays OLED with gray border / white text.
- Links sheet white outer shell/gaps -> OLED black; row text white; existing dividers gray; One Medical logo shadow owner inverted.
- Account/contact-confirm page receives both light-DOM and bounded open-shadow-root ownership:
  - page/section floors OLED;
  - neutral light info surfaces dark gray;
  - dark neutral text white;
  - primary/Continue buttons OLED, standardized gray border, white text.
- Shadow refresh is event-driven only (initial/DOMContentLoaded/load/click/focus/transition/animation); no MutationObserver, polling timer, or recurring walker.

## Your Orders search-results page

- Added a pushed-route Person owner based on the screenshot-proven full-width React search shape (~404x44 with RNCEKV input + 20px RCT image).
- Search field shell -> medium gray with one standardized gray border.
- Nested light input/sliver owners -> same gray floor.
- Search glyph reuses the established Person magnifier whitening path.
- The pushed results root is promoted into the existing Person text palette so header/helper text uses the existing white/secondary-white rules.

## Retained cumulative fixes

All post-v7.585 UI work remains present: Health AI/Warbler/auth fixes, One Medical owners, PDP dual-state coupon, fullscreen product-image thumbnail rail/taming, sustainability/package-info text, compact Orders magnifier, Your Review theming, and exact Shop the Show media/crop/tame owners.
