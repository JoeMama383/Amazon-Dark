# AmazonDark v7.404 audit — Product Search video border + Alexa control polish

## Baseline

- Direct parent: `7.403~product-share-sheet-probe-control`.
- Evidence: `AmazonDark-v7.403-ui-full-probe-20260911-091818-596-r1.zip`.
- v7.403 Product/Cart Share theming and probe-testing toggle remain intact.

## 1. VIDEO_SINGLE_PRODUCT duplicate border

The FULL probe shows one outer `div.s-card-container.s-overflow-hidden.aok-relative.s-card-border` at 414×422.8 enclosing both the video and product-copy area. Inside it, Amazon mounts a second `div.puis-card-container...mobile-video-product-view...puis-card-border` at 414×189. Both computed to 1px `rgb(73,77,77)` edges, producing the duplicate/nested frame.

v7.404 keeps the outer card untouched and clears only the nested `mobile-video-product-view.puis-card-border` border/outline/shadow. Result: one continuous gray frame around video + copy.

## 2. Alexa prompt button

The same probe identifies the exact sponsored Alexa family:

- `button[class*=_c2Itd_buttonAlexaWithIcon_]`
- `[class*=_c2Itd_cueContainerAlexa_]`
- `img[class*=_c2Itd_alexaIcon_]`

The cue container computed as `rgb(194,220,255)` with a 16px radius. v7.404 changes only that cue pill to `#303335`, adds the standard `#747a7c` 1px edge, and forces neutral prompt copy white. Press/focus becomes `#202324`. The Alexa image is explicitly unfiltered/transparent so its authored blue glyph remains intact.

## Architecture/performance

- Implemented as one small declarative CSS delta concatenated into the existing immutable core document-start program.
- No new WKUserScript slot.
- No MutationObserver, interval, RAF loop, Web scroll listener, polling loop, or recurring hierarchy scan.
- Historical `ADFloorJS` and `ADTWBJS` payloads are not edited.

## Probe regeneration

FULL, VIEWPORT and transition/lifecycle identities are regenerated to v7.404, including app receipt/arm/status paths and SpringBoard launch log identity.
