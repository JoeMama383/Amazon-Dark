# AmazonDark v7.563~pharmacy-oled-media

Built from origin/main d021464c (v7.562), retaining its Seller Messaging, keyboard, Filters, Settings, Interests and probe changes.

The supplied v7.562 FULL Pharmacy capture identifies the native teal chrome controllers and the Pharmacy LEGO/PUI web families. This update makes structural floors OLED, neutral headings and copy white, secondary copy legible gray, benefit pills and search fields gray, and action buttons OLED with gray borders. The blue Prime promotion, semantic links, logos and authored layout remain intact.

Large Pharmacy artwork uses the existing configurable brightness-taming strength, with one image-level filter and no container dimming. Declarative styles cover late-loading images without timers, observers or repeated scans. Native chrome is restricted to the three captured controller owners and their exact teal color.

See COMMANDS.md for the existing-clone update and separate FULL, VIEWPORT and TRANSITION commands. Native build and device verification are still required.


## v7.562 Seller Messaging Assistant dark-mode completion

Builds on v7.561. The supplied v7.556 VIEWPORT archive is the earlier Refunds help-article capture rather than the Seller Messaging Assistant screen shown in the screenshot, so v7.562 does not pretend that archive exposed Seller Messaging DOM owners. Instead the new production owner is strictly route-gated to Amazon's Seller Messaging Assistant contact-seller family (`/gp/help/contact-seller/contact-seller.html`) and child frames whose referrer is that route.

Within that route only, structural page/card/container floors are OLED black, chat bubbles and controls use neutral dark gray, neutral dark copy is lightened, authored interactive/dynamic colors remain currentColor, borders are standardized gray, and product-sized non-logo images receive the existing configured TWB brightness. The image pass is finite and route-local: it inspects only `document.images` immediately/once at page load and adds no MutationObserver, timer, RAF, scroll listener, polling loop, or recurring hierarchy scan.

v7.561 Refunds help-note OLED, v7.560 Returns-success alert ownership, v7.559 order-item theming/count geometry, and v7.558 Filters/probe-routing work are retained.
