# AmazonDark v7.562~seller-messaging-oled-twb

## v7.562 Seller Messaging Assistant dark-mode completion

Builds on v7.561. The supplied v7.556 VIEWPORT archive is the earlier Refunds help-article capture rather than the Seller Messaging Assistant screen shown in the screenshot, so v7.562 does not pretend that archive exposed Seller Messaging DOM owners. Instead the new production owner is strictly route-gated to Amazon's Seller Messaging Assistant contact-seller family (`/gp/help/contact-seller/contact-seller.html`) and child frames whose referrer is that route.

Within that route only, structural page/card/container floors are OLED black, chat bubbles and controls use neutral dark gray, neutral dark copy is lightened, authored interactive/dynamic colors remain currentColor, borders are standardized gray, and product-sized non-logo images receive the existing configured TWB brightness. The image pass is finite and route-local: it inspects only `document.images` immediately/once at page load and adds no MutationObserver, timer, RAF, scroll listener, polling loop, or recurring hierarchy scan.

v7.561 Refunds help-note OLED, v7.560 Returns-success alert ownership, v7.559 order-item theming/count geometry, and v7.558 Filters/probe-routing work are retained.
