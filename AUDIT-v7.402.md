# AmazonDark v7.402 audit — payment first paint, switcher, and pickup transition

## Base
- Direct parent: `7.401~native-payment-sheets-completion`.
- All v7.401 payment-sheet and dark press/highlight behavior is preserved.
- Evidence: the supplied v7.401 transition exports at ~23:07 and ~23:17, plus the prior FULL Place Your Order capture for the exact pickup-expander owner.

## Probe-backed corrections

### 1. Select Payment Method white reserved card
The transition probe shows the bright card below the Gift Card block is not the settled payment content. It is a React-Web skeleton directly preceding `iframe#maple-advertisement`; its child owns the stock white shimmer/gradient.

v7.402 owns only:
- `#checkoutDisplayPage div:has(+ iframe#maple-advertisement)`
- its direct child

Both are OLED from document start with no animation/polling machinery.

### 2. Add-new payment header first paint + orange Amazon logo
The native Add-new sheet is `RCTView#bottom-sheet`. The centered 51×12 `RNSVGSvgView` is the authored Amazon smile and mounts while the sheet is still mostly offscreen.

v7.402 uses that exact geometry/hierarchy as an early payment-sheet marker so the already-established payment root/header theming runs before the sheet reaches the viewport. The same SVG is explicitly excluded from neutral-glyph inversion and its layer filters are cleared if it was previously claimed. The orange Amazon brand color therefore remains authored.

### 3. Gray/white payment app-switcher regression
The transition trace captured two neutral background visual-effect shields while Amazon is inactive:
- checkout Web controller (`AMIWebViewController`), approximately full content width and checkout-content height, with a near-white high-alpha tint;
- React payment controller (`SNPViewController`), approximately full-window, with a white lower-alpha tint.

The old v7.389 fix was intentionally tied to the older teal signature and cannot match these neutral shields. v7.402 adds a separate payment-only owner requiring all of:
- AmazonDark enabled;
- live checkout modal;
- `AppCXWindow`;
- a proven live `RCTView#bottom-sheet` payment sheet;
- app not active;
- exact responder family (`AMIWebViewController` or `SNPViewController`);
- full-width/full-height-family geometry;
- neutral near-white visual-effect tint.

Only those shields are hidden. There is no generic app-switcher cover or snapshot replacement.

### 4. Place Your Order pickup chevron
The FULL Place Your Order hierarchy identifies the dark 16×16 glyph as `i.a-icon.a-icon-collapse` under the exact `#ap-spc-dest-schs-upsell` AUI expander header. v7.402 lightens only the icon beneath that exact expander. The surrounding pickup link remains Amazon blue.

### 5. Place Your Order → Select a pickup location transition floor
At roughly one minute into the supplied transition session, the incoming pickup document mounts an experiment-specific root `bolt-widget-amazon_us_checkout_spc_mobile-*`. Beneath it, a direct `.a-section.a-spacing-none` wrapper creates a 430×800 absolute child with inline `background-color:white`, `opacity:.75`, and `z-index:100`.

The surrounding native `AMIWebViewController` root and `#a-page` are already black. v7.402 therefore owns only that exact inline white/z-index-100 transition painter and changes its background to OLED black. The spinner itself is not filtered or recolored.

### 6. Add-new payment left-side method artwork
The r6 FULL probe proves all five left-side payment-method visuals are raster `RCTUIImageViewAnimated` leaves under exact `creatable-sleeve-*-image-wrapper` owners. The first four families (Card, ElectronicBenefitTransfer, BankAccount, DirectedSpendBenefitsCard) use square monochrome transparent icon rasters and disappear against OLED when their stock dark ink is preserved. The HealthBenefitsCard asset is a wider authored raster and is already legible.

v7.402 therefore:
- keeps every `creatable-sleeve-*-image-wrapper` transparent;
- converts only the first four exact raster families to template rendering with AmazonDark light tint;
- leaves `creatable-sleeve-HealthBenefitsCard` in original rendering mode;
- excludes all five fixed control artworks from generic TWB/product-media handling.

No payment-card logos or unrelated React images are broadened into this rule.

## Preservation / architecture
- v7.401 native payment sheets and dark pressed/highlight states retained.
- Amazon blue/green/red/orange semantic states retained.
- Amazon payment/card/brand artwork retained.
- Existing v7.389 teal switcher owner retained independently.
- Existing v7.396 checkout AMI transition-root seal retained.
- New MutationObserver: 0.
- New interval: 0.
- New RAF loop: 0.
- New Web scroll listener: 0.
- New polling/recurring timer: 0.
- New recurring hierarchy traversal: 0.
- New WKUserScript family: 0.
- Generic app-switcher/snapshot cover: 0.

## Device verification targets
1. Change Payment Method: no white reserved card below Gift Card during first load.
2. Add New: header/root OLED from the first visible frame; Amazon smile stays orange.
3. Background Amazon from payment UI: switcher card remains dark, never gray/white.
4. Place Your Order: pickup expander chevron is clearly light while link stays blue.
5. Place Your Order → Select a pickup location: loading floor is OLED; spinner remains stock/authored.
6. Add New payment methods: Card/EBT/Bank/OTC icons are clearly light/visible with transparent wrappers; FSA/HSA remains authored and visible.
