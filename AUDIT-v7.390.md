# AmazonDark v7.390 UI completion audit

## Base
- Direct parent: `7.389~checkout-sheet-switcher-fix`.
- Evidence: the eight v7.389 FULL captures supplied on Sep. 10, including the recovered 14:29
  `Select a Payment Method` capture.
- Existing v7.389 Subscribe-sheet and checkout-only teal switcher fixes are retained.

## Probe-backed changes
1. Help & Contact Us — exact `#csg-support-topics` AUI topic cards: OLED rows, `#747a7c` edge/
   separators, light neutral copy and chevrons. `.a-color-state` remains authored orange.
2. Subscribe loader — exact `#loading-spinner-blocker-doc`: dark translucent blocker, OLED
   spinner backing, exact 100x100 `#loading-spinner-img` complement filter.
3. Lower carbon delivery — exact portal sheet containing `#ad-sm-program-modal`: OLED sheet and
   white neutral copy; existing lightbox and close control retained.
4. Choose gift options — exact `#giftForm`: OLED AUI cards and inputs, single gray border
   ownership for message/sender controls, OLED Continue button, authored checkbox and media kept.
5. Checkout Prime Business Card — exact `#checkout-maple-upsell`: OLED Maple card, light neutral
   text and authored blue link; its image joins the existing checkout TWB strength lane.
6. Select a Payment Method — semantic `data-testid` card owners from the 14:29 FULL probe:
   OLED selected/unselected/card/footer floors, standard gray neutral card edges, selected Amazon
   blue border preserved, brand images and switch/outline painters untouched. The iframe `#cruise`
   Maple gift-card cross-sell is also themed at its own document root.
7. Select a delivery address — exact `#shipping-address-select-page-card-deck`: OLED card/deck/
   accordion floors, black primary with gray edge, `#303335` secondary controls, gray dividers,
   authored radio sprites and links preserved.
8. Subscribe recurrence dropdown — exact SNS AUI dropdown-popover family: OLED rows/header, light
   text/close glyph, gray dividers, selected blue border retained while pale-blue fill is removed.

## Runtime architecture
- Declarative document-start CSS appended to the already-existing checkout user script.
- One additional exact image selector in the existing strength-dependent checkout TWB stylesheet.
- No new WKUserScript.
- No MutationObserver, timer, interval, RAF loop, scroll listener, polling loop, or recurring scan.
- No changes to SpringBoard switcher behavior beyond the existing v7.389 exact checkout shield fix.

## Device status
- Device validation is required after installation; local validation proves source/selector/JS
  contracts, not Amazon's final live renderer composition.
