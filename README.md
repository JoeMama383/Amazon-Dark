# AmazonDark v7.427 — native Alexa AI results

Exact parent: the delivered v7.426 source archive. Previous PDP, Cart, Medical Care and video fixes are retained.

The supplied v7.426 FULL r1 contains a native React Native results screen and zero on-screen webviews. This release owns only a root-container with its shallow cardboard-background header marker. It does not add web CSS.

Changes:
- Flat OLED header; suppress only its three decorative stripe/gradient stacks.
- Search bar uses the existing gray control fill, gray border, light neutral text and neutral-light SVG search/back icons.
- White card floors and neutral floors become OLED. Product image wash overlays remain transparent so artwork stays visible.
- Yellow Add to cart controls become OLED with light text and standard gray borders. Ask anything gets OLED fill and a gray border; its decorative blue-white footer fade is suppressed.
- Existing neutral text conversion runs at React text commit and final draw, preserving saturated semantic runs.
- Solid neutral SVG brushes become light. Gradient brushes and saturated fills/strokes remain authored, including Alexa, Prime, stars and blue chevrons.

Validation: 105 available regression checks passed (104 existing/handoff scripts plus the new native fixture test), Logos lint passed, probe shell syntax passed. A topology fixture verifies all 429 initial AI results nodes are owned and unrelated roots are rejected; compiled neutral-palette checks preserve representative semantic colors. No iOS SDK/Theos build or on-device rendering was available here.

Probes are versioned to v7.427. Capture behavior is unchanged. The supplied v7.426 probe reached the native scroll edge in 10 steps and restored the original offset. See COMMANDS.md for separate workflows.
