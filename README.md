# AmazonDark v7.416 — canonical location-menu owner

Direct parent: **v7.415~location-text-finalize-fix**.

v7.416 consolidates the location-menu work from the recent v7.408–v7.415 cycle. The supplied FULL, VIEWPORT and TRANSITION probes show two React trees can coexist, but the pixels for **Choose your location**, **Enter a US zip code**, **Ship outside the US**, and **Use my current location** live under the full-screen `SNPRootView` and a lower inset ~394 pt `RCTScrollView`. The later `AppCXBottomSheet/WrappedNileFeatureContainer` tree is a parallel sibling and is no longer used as the menu owner.

The location family now has one event-driven owner. Main address cards are intercepted at their own background setter so stock-white cannot win first paint; React's cached background raster is invalidated on ownership. Neutral location text is repaired at assignment, legacy three-argument text finalization, and final draw/layout, while authored saturated semantic colors remain unchanged. ZIP input uses the standard gray fill/gray border/light text; Apply is OLED with a gray React border and white text. Country rows and neutral list/header surfaces are OLED with light text and gray separators. Existing orange selected-address edges, Amazon-blue links, back chevrons, icons, SVGs and sprites remain authored.

The obsolete v7.412 `ADLocationAux*` and v7.414 `ADLocationNile*` systems are removed. No MutationObserver, timer, RAF loop, Web scroll listener, polling loop, delayed retry, recurring hierarchy scan, route-string classifier, or new WKUserScript family is added. `src/Tweak.xm` drops from 806,985 bytes in v7.415 to about 782 KB in v7.416 while retaining the universal FULL, VIEWPORT and TRANSITION probes.
