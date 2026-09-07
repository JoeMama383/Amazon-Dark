# AmazonDark v7.357~search-footer-shop-style-fix

Direct base: **v7.356~product-inline-ad-controls-fix**.

This is the correction build for the two surfaces that v7.356 still missed on-device. The v7.356 static test proved that guessed selectors were present in source, but that was not proof that those selectors matched Amazon's live renderer. v7.357 removes both failed assumptions instead of stacking more guesses on them.

## UI corrections

- **Search autocomplete delivery-day footer:** the surviving white full-width plane is no longer gated on a descendant whose class/id contains `delivery`. The `/autocomplete` lane owns only the first two structural layers under `#a-page` / `#attach-to-me` by `background-color`, leaving media/background-image ownership alone. DOM buttons in that pane use OLED black, `#747a7c` neutral borders and light text.
- **YOU MIGHT ALSO NEED media remains protected:** the working `cards_carousel_widget-sug-im*` transparency/visibility and brightness-TWB lane is unchanged. The rejected broad `cards_carousel_widget-sug-*` descendant-floor rule is still absent.
- **Shop by style:** v7.356's guessed `shop-by-style` / `shopByStyle` class/data selectors are removed because the live card did not match them. On `/s`, v7.357 performs a bounded load/pageshow text-node walk (maximum 7000 nodes) for the exact authored heading `Shop by style`, then marks the nearest compact image-bearing widget. Only that marked widget receives OLED structural floors, light neutral text, standard gray edges, and brightness TWB on its raster `IMG` leaves. There is no global product-image sweep.

## Preserved v7.356 work

- Theme-collection / ear-cleaning ad edge -> `#494d4d`.
- Product option/count pills -> OLED/light/gray with Amazon blue selected ring preserved.
- IES / Continue-shopping expansion -> OLED structural surfaces, dark category tabs, dark Add-to-cart, dynamic Prime/star/deal/coupon/savings colors preserved, and IES product rasters brightness-tamed.
- Product quantity stepper -> `#303335` / `#747a7c` / light value and +/- glyphs.
- v7.355 Cart Same-Day, v7.354 Store Spotlight/Search carousel media, v7.353 Top-reviewed, v7.352 product-control hands-off rules, v7.351 optimization/Save-for-later, v7.350 splash, v7.349 Cart strip and v7.348 Cart gradients remain.

## Runtime character

No production `MutationObserver`, interval, RAF loop, Web scroll listener, polling loop or recurring native/DOM scan is introduced. The Shop-by-style discovery is bounded and event-limited to document load/pageshow; once the marker exists later calls return immediately.

## Probe workflow

Screenshot-triggered UI probes remain enabled. Historical filenames remain `AmazonDark-v7.309-*`; the header inside reports the installed v7.357 runtime. The product-scroll probe remains current/near-viewport only, while the Search/Menu scanner remains the heavy full-document engine.
