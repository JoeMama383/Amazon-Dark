# AmazonDark v7.398 — legal/help completion audit

## Base
- Direct parent: `7.397~checkout-payment-aux-controls`.
- v7.397 payment auxiliary fixes are preserved.
- v7.396 checkout address native transition-floor fix is preserved.
- Universal two-category UI probe architecture and transition probe are preserved; identities are bumped to v7.398.

## Probe-backed corrections

### Privacy Notice / Conditions of Use
The recent FULL probes show these legal articles beneath `.oas-uuid-do-not-delete` / other wrapper nodes rather than as direct children of `.cs-help-content`. The old `>article.help-content` rules therefore missed the body.

v7.398:
- changes legal/help article ownership to descendant `article.help-content`;
- makes ordinary legal/article neutral text white, including the probe-captured `pre.msgblock` blocks on Conditions of Use;
- preserves authored links and explicit `.a-color-secondary` / `.a-color-tertiary` families;
- turns the stock `p.lead` / landing-section light separator into OLED black without geometry changes.

### Shared help-search magnifier
The probe identifies `input#helpsearch` under `form#search-help`; the dark magnifier comes from the input's stock background image.

v7.398 removes that image only on this help-search control and paints a static CSS magnifier in `#b1aaa0`, matching the placeholder. No JavaScript or image substitution is added.

### Help submenus
The FULL Help probe shows every `help-content-submenu*` family already mounted as white AUI vertical cards. v7.398 themes the stable shared family:
- OLED card/row floors;
- `#747a7c` card edge and row dividers;
- white neutral text and touch-link chevrons.

### Feedback No-state
The hidden `#hmd-ReasonBox` contains another white `fieldset.a-box-group > .a-box` not owned by the earlier outer HMD rules. v7.398 darkens that shell and keeps `.a-icon-radio` authored.

### Help instructional figure frame
A probed article contains a white `.cs-help-content-frame .a-box.a-first` around an authored instructional image. v7.398 darkens only the AUI frame and does not filter/tame the image.

### Additional probed Help shells
A later FULL Help capture also exposes two bright-neutral owners outside the earlier row/card families: `#llm-summary-box` inside the article and a related-help `.a-box.a-spacing-base.a-spacing-top-base.a-width-auto` mounted directly under `.cs-help-content`. v7.398 gives only those probe-proven shells OLED floors, standard gray edges and white neutral copy while preserving authored links and the summary feedback/thumb artwork.

### Latent payment/checkout states
The payment FULL probe also captures:
- a hidden `[id^='installments_bottomsheet_content_']` footer whose base button is white and primary button yellow;
- a generic `.loading-spinner-blocker` sibling in addition to the already-owned `#loading-spinner-blocker-doc`.

v7.398 gives the exact installments footer/buttons OLED floors, standard gray borders and white text while preserving checkbox/radio art and authored links. The checkout loader rule now owns the captured `.loading-spinner-blocker` family only when `#checkoutDisplayPage` exists.

## Preserved behavior
- Payment selected blue outlines and authored blue alert/banner edges.
- Financing chevron/white text and v7.397 payment controls.
- Dynamic blue/green/red/orange text.
- Explicit secondary/tertiary gray help text.
- Checkbox/radio/switch sprites.
- Product, card and instructional image artwork unless already covered by the user-controlled TWB lane.
- v7.396 native `AMIWebViewController` checkout address transition seal.

## Runtime shape
This release adds only static CSS to the existing checkout document-start stylesheet and version/probe identity updates.
- new MutationObserver: 0
- new interval: 0
- new RAF loop: 0
- new polling/timer loop: 0
- new Web scroll listener: 0
- new recurring hierarchy traversal: 0
- new WKUserScript family: 0

## Device validation targets
1. Privacy Notice: body/lead text white, links blue, article light separator gone, search magnifier gray.
2. Conditions of Use: same white legal text + gray search magnifier.
3. Help topic submenu: OLED rows, gray dividers, white text/chevrons.
4. Returns and Consumer Use Tax: OLED cards/table, authored gray/dynamic text preserved.
5. Feedback No-state: no nested white reason card.
6. Payment installments sheet if surfaced: OLED footer/buttons, preserved control art.
7. Existing v7.397/v7.396 payment and address-transition fixes remain unchanged.
