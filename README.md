# AmazonDark v7.412 — address + location auxiliary UI theme

Direct parent: **v7.411~permission-firstpaint-owner-fix**.

This build keeps the v7.411 permission/location first-paint fixes intact and themes the three newly supplied address/location menus in their actual renderers.

- **Your Addresses (Web/AUI):** the exact `ya-myab` address-manager family gets dark-gray action rows, OLED address cards, gray card/divider edges, light neutral copy, and dark pressed states. Amazon-blue links, the default/Amazon artwork, SVGs, sprites, icons, and other authored media remain unfiltered.
- **Ship outside the US (native React):** the lower inset location-navigation family is identified structurally from its probe/screenshot geometry and back-chevron header. Neutral country-list floors become OLED, headers/list copy become light, and existing separators/borders become the standard AmazonDark gray. The authored chevron/images/vectors are not recolored.
- **Enter a US zip code (native React):** the v7.411 FULL probe proves a 394×44 `RCTSinglelineTextInputView`, a 394×45 yellow React Apply control, and a 394×35 header row. The input becomes `#303335` with a `#747a7c` edge and light text/placeholder; Apply becomes OLED with a `#747a7c` edge and light text; the header separator becomes gray and its copy becomes light.

The native auxiliary-location owner is event-driven and structurally bounded. No MutationObserver, timer/polling loop, RAF loop, Web scroll listener, recurring hierarchy scan, broad image filter, or new WKUserScript family is added. FULL, VIEWPORT, and TRANSITION/lifecycle probe identities are regenerated to v7.412.
