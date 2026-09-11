# AmazonDark v7.402 — payment first-paint, switcher, and pickup-transition fixes

v7.402 is built directly on `7.401~native-payment-sheets-completion`. It preserves the completed native payment sheets, permanent dark press/highlight policy, Delivery Instructions, Add-address, checkout/help/pickup theming, transition ownership, universal probes, and the existing low-overhead architecture.

This release is driven by the supplied v7.401 transition traces plus the previously captured FULL Place Your Order hierarchy. It closes six transient/residual paint gaps without introducing a broad overlay or generic image inversion:

1. **Select Payment Method first paint:** the React-Web skeleton immediately before `iframe#maple-advertisement`, including its white shimmer child, is OLED at document start.
2. **Add-new payment sheet first paint:** the native `RCTView#bottom-sheet` can be recognized while still mostly offscreen from its exact centered 51×12 Amazon-smile SVG, allowing the root/header to be claimed before the slide-up becomes visible. That SVG is explicitly treated as authored brand art and is never inverted, so the Amazon smile remains orange.
3. **Payment-section app switcher:** the transition probe captured two neutral inactive `UIVisualEffectView` shields (checkout Web and React payment controller) that replaced the older teal signature. v7.402 hides only those exact payment-owned neutral shields while the proven payment sheet is live; normal snapshots remain untouched.
4. **Place Your Order pickup chevron:** the exact AUI expander icon under `#ap-spc-dest-schs-upsell` is made light while the surrounding Amazon-blue pickup link remains authored.
5. **Place Your Order → Select a pickup location transition:** the experiment-specific `bolt-widget-amazon_us_checkout_spc_mobile-*` renderer mounts a 430×800 inline white/75%-opacity z-index-100 loading plane over an already-black page. Only that exact transition plane is forced OLED; the spinner remains authored.
6. **Add-new payment method icons:** the r6 FULL probe identifies five exact raster leaves. Card/EBT/Bank/OTC are transparent monochrome icons and are rendered as light templates on transparent wrappers; the already-legible FSA/HSA authored raster remains original.

No MutationObserver, interval, RAF loop, Web scroll listener, polling loop, recurring hierarchy scan, generic app-switcher cover, generic transition overlay, or extra WKUserScript is added. All Web fixes are static rules in the existing checkout document-start program; native fixes reuse existing event-driven hooks.

See `AUDIT-v7.402.md` and `COMMANDS.md`.
