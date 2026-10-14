# v7.640 validation

## Passed

- Strict repository validation: all 303 Python regression scripts, JavaScript/source checks and Logos lint passed. Local dependencies were supplied through the existing audit toolchain. The changed lifecycle/selector tests were rerun after final hardening.
- Logos generation and Clang ARM64/iOS 17 syntax checking of Tweak.xm, AmazonDarkSB.xm, ADPrefsController.xm and ADSponsored.m using the iPhoneOS 16.5 SDK. WebKit headers are in that SDK's Cryptex framework directory. Existing UI-probe retain-cycle warnings remain; no new compiler errors. This is syntax checking, not linking or packaging.
- Executed the 50 extracted production JavaScript programs in local Playwright WebKit against an 11,509-node synthetic fixture on Search, product, Home and Interests routes. Compared v7.639 composition with v7.640 composition. Sampled product text colors, backgrounds, borders, image filters, widths, heights, font sizes and display modes were equal. Home/Interests stylesheet contents were byte-for-byte equal.
- Main Search stylesheet source reduced from 306,584 to 262,563 bytes; product from 342,485 to 316,287 bytes. Both omit one unused adopted Interests stylesheet. Home and Interests source amounts remain unchanged.
- Source filtering tests cover mixed selectors, child frames, unknown routes, malformed CSS, nested at-rules, comments, data URLs and universal specificity selectors. Recovery tests cover disconnected heads, repeated lifecycle events, same-ID replacement and bounded retention. No recurring scanner or observer is introduced.

## Timing limits

An initial synthetic run measured product initial style installation/layout at 1,154 ms before and 827 ms after; Search at 561 ms before and 526 ms after. A later final-source compatibility run measured product at 1,673/1,177 ms and Search at 721/726 ms. Search has therefore not demonstrated a consistent timing improvement. These are desktop WebKit fixture observations under variable host load, not iPhone results, statistical benchmarks or a claim that a 5–20 second stall is solved. The release reduces unrelated CSS source and shows lower product-fixture work; normal on-device capture is still required.

## Build and device limits

Source ZIP only. GitHub Actions must compile, link and package the DEB after manual push. First cold boot, all real menu paint states, touch latency and carousel responsiveness have not been verified on the phone. The original screenshots and probe archives are not bundled. `COMMANDS.md` includes the exact push, normal performance and FULL/VIEWPORT/TRANSITION commands.
