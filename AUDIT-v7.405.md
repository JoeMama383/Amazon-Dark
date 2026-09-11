# AmazonDark v7.405 audit — Product Detail Page completion

## Baseline
- Direct parent: `7.404~product-scroll-video-alexa-polish`.
- Evidence: v7.403 universal FULL r2 and r3 of the same mobile Product Detail Page; r3 captured the longer hydrated/VSE state, while r2 retained the alternate sticky-subnav state.
- v7.404 Product Search video/Alexa fixes and every earlier checkout/share/payment/menu fix remain intact.

## Probe-backed gaps closed
0. **Second Product Search video-ad border family:** v7.404 FULL r1 proves the outer `sb-video-creative` CardInstance spans through the Sponsored footer while `_c2Itd_singleAsin_*` adds a second border around only the product-copy half. v7.405 removes both of those frames and places one `#494d4d` border on `_c2Itd_shortProduct_*`, whose measured rectangle is exactly video + product copy and ends above Sponsored.
1. **Structural floors:** white/near-white `a-cardui`/`a-cardui-deck`, twister, House of Cards/A+, multi-bundle, image-gallery, validation, all-offers, hidden PQV ingress, unified trade-in side sheet, video loader, c3Atb sponsored bottom-sheet shells/header, recommendation image wells and r2 sticky subnav are OLED black.
2. **Neutral text:** PDP neutral copy is light; explicit secondary/tertiary copy is readable gray. Amazon links remain authored; success/error/state/price/deal/coupon/savings/promotion/badge families keep authored colors. Amazon's Choice orange, Prime and rating/star art are excluded from neutral whitening.
3. **Controls:** neutral pills/dropdowns/base controls—including the probe-captured Rufus search submit—use `#303335` + `#747a7c` + white. Full-width/large oval buybox, wishlist, multi-bundle and VSE actions use OLED + `#747a7c` + white. Press/focus states stay dark. Selected twister controls retain a blue-gray selection cue.
4. **Rufus/Alexa-style pills:** baby-blue PDP Rufus/search pills use the standard neutral AmazonDark control contract.
5. **Media carousel:** pagination rail is OLED; dots are white with selected dot fully opaque. Empty heart/share glyphs are light without recoloring the filled-heart authored state.
6. **Images/media:** main/alternate product media, A+ panels, sponsored-product media, image-gallery, VSE thumbnails, review/customer media, notable-quote thumbnails, inline twister images and the probe-captured product-card image family use the existing brightness taming factor. Star/Prime/brand/icon/sprite families are not in these selectors.
7. **Top PDP APE:** the parent APE shell is OLED, and a direct-PDP-referrer child-frame text rule makes neutral ad copy readable while preserving known blue links and semantic colored families. Existing child-frame TWB continues to tame eligible media.

## Architecture
- Three small document-start deltas are appended to the existing immutable core program: the second-video-border correction, `ADPDPCompletionJS7405`, and strength-dependent `ADPDPCompletionTWBJS7405`. Final validation also caught the format-string count after adding the new delta; v7.405 uses 11 `%@` slots for 11 appended programs so the PDP TWB payload is not silently dropped.
- No new WKUserScript slot, hook, MutationObserver, interval, RAF loop, Web scroll listener, polling loop or recurring hierarchy scan.
- Universal FULL, VIEWPORT and transition probe identities are regenerated to v7.405.
