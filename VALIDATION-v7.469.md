# AmazonDark v7.469 validation — user-origin PDP ownership

## Why v7.464-v7.468 did not fix the device UI

The three v7.463 VIEWPORT captures prove the selectors but also expose the delivery failure:

- Top standalone ad child frame: `brand-name` and `product-description` compute black while the renderer is on a dark floor. The child frame has only Amazon's anonymous style sheet; no `ad7458-pdp` or `ad7454-pdp-grid-carousel` DOM style exists there.
- Half-carousel child frame: `gridContainer` is 402x125, white, radius 0, with a 1px light edge; the white/zinc slide floors are also author-painted. The rounded `gridRegionCarousel` is the inner edge that should remain. Again, the AmazonDark child DOM style IDs are absent.
- BTF standalone ad: main `ape_detail_btf_mshop_placement` is the 402x125 radius-0 outer 1px edge while the child `modern-414x125-layout-container` is the desired radius-8 inner edge.

v7.464 added correct-looking selectors but delivered them as another all-frame `WKUserScript`. v7.465-v7.468 retained that same runtime lane while repairing CI contracts. The supplied child probes show that lane was not present in the failing renderer documents, so selector refinement alone could not solve the device UI.

## v7.469 mechanism change

v7.469 retires the v7.464 `AmazonDarkPDP7464` isolated content-world duplicate and installs one exact `_WKUserStyleSheet` through the existing `WKUserContentController`:

- `forMainFrameOnly = NO` — main document and child frames.
- `level = 0` — WebKit user-style origin, above ordinary page-author CSS in the cascade.
- no child-document JavaScript execution is required for these paint rules.
- no referrer check, hydration callback, DOM walker, MutationObserver, timer, RAF loop, polling loop, or scroll listener.
- no `:has()` in the new user stylesheet.

Exact ownership:

- top standalone header: light `brand-name`, `product-description`, and `combined-brand-and-description`; requested Sponsored/info-glyph colors preserved;
- half carousel: OLED `gridContainer`, zinc/white slide floors; square outer and slide duplicate edges removed; one gray inner `gridRegionCarousel` edge retained; only measured `price-text` and `currency` neutral leaves forced light;
- BTF/hero/BTF2 main placement outer edge removed without flattening the child renderer's rounded inner border;
- Book details: user-origin cleanup for `.a-expander-content-fade`, the historically proven expander/fade/fade-out families, and their scrim pseudo-elements; the header pseudo paint is cleared without deleting the header pseudo itself;
- Book-details/review neutral text and Books subnav divider are included in the same user-origin sheet.

## Regression and static validation

Final `src/Tweak.xm`: 853,598 bytes (`< 856,000` hard gate; 2,402 bytes spare).

Complete current regression corpus: 146/146 `tests/test_*.py` pass after applying the exact `scripts/validate.sh` v7.460 -> current identity normalization. The corpus was executed in five bounded parallel batches because the sandbox command window terminates the repository's sequential runner before completion; every batch exited 0.

Additional checks:

- `bash scripts/lint-logos.sh`: PASS
- `sh -n scripts/ui-probe.sh`: PASS
- `sh -n scripts/skeleton-probe.sh`: PASS
- `sh -n scripts/validate.sh`: PASS
- all v7.469 identity literals required by `validate.sh`: PASS
- new user stylesheet: 16/16 qualified selectors parse with `tinycss2` + `cssselect2`: PASS
- production `new MutationObserver(`: 0
- production `setInterval(`: 0
- production `requestAnimationFrame(`: 0
- production web `addEventListener('scroll'`: 0
- production `createTreeWalker(`: 0
- production `querySelectorAll(`: 1 (inherited)
- frozen v7.448 performance/consolidation regression: PASS
- frozen v7.454 carousel ownership regression: PASS
- current v7.464-v7.468 compatibility regressions: PASS
- new `test_v7469_pdp_user_style_delivery.py`: PASS

Theos/iOS SDK compile/link is not available in this container; GitHub Actions remains the package compile/link proof. The runtime `_WKUserStyleSheet` call shape is the same private WebKit API shape previously compiled in the v7.442/v7.443 source, but v7.469 is the first use of that mechanism with the current exact v7.463 cross-frame selectors and without the old broad `:has()` sheet.
