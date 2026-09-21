# AmazonDark v7.436 audit — probe-backed PDP/Search fixes

## Exact parent

- Parent: `7.433~universal-crossframe-probe`
- Parent archive: `AmazonDark-v7.433-universal-crossframe-probe-source.zip`
- Parent SHA256: `ea950ad801e0ea68c91a68020e9c7f115f5cda55d6b65405084cdb3805968864`

## Probe findings used

- `Product image gallery`: the visible `.a-truncate-cut` leaf is `rgb(15,17,17)` on effective `rgb(0,0,0)` and is explicitly reported `dark-on-dark`; the h3 parent is already white.
- Multi-bundle product art: `img.a-dynamic-image.p13n-sc-dynamic-image.p13n-product-image` is loaded (`complete=true`, natural 210×210) but has computed `filter: brightness(0.42)`.
- APE feedback glyph: the main-frame `[id^=ad-feedback-sprite-]` node is 12×12 and currently uses the gray mask treatment.
- Search sponsored result: the viewport probe identifies `.s-result-item.AdHolder`, `.puis-card-container`, `.puisg-col*` as the live family.
- Shop-by-brand: the viewport probe identifies `data-component-type=s-tiles-carousel-component-brand_logo`.

## Runtime/performance

No new MutationObserver, interval, recurring timer, RAF loop, web scroll listener, polling loop, or recurring hierarchy scan. The v7.433 all-frame universal probe architecture is retained.
