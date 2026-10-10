# AmazonDark v7.622 — Probe-exact Alexa and advertising feedback follow-up

Base: full source from v7.621 (Orders recommendations / Change Shipping Address OLED).

- **Native Alexa camera/Image/Guide/Scheduled Actions (`r4`)**: added exact `plus-menu-modal-container` ancestor ownership, converts authored white modal/card/button/badge fills to OLED, replaces only the existing `plus-menu-modal-divider` with standard gray, recolors neutral native text white while preserving the blue *New* text, and inverts black SVG glyphs; the existing 60-point SVG circles are suppressed (without moving the icon paths).
- **Native voice microphone consent (`r3`)**: added guarded `sheet-view` recognition requiring both `allowTitle` and `actionButton`. Floors OLED, yellow Continue action becomes OLED with its existing gray border and white copy. Text gets the existing neutral-only converter, preserving teal privacy links. The exact 44×44 microphone image glyph is inverted via its leaf layer, without changing the image source.
- **iOS share sheet (`r2`)**: request `UIUserInterfaceStyleDark` on Amazon's own presented `UIActivityViewController`, without touching other apps or Apple remote system services. Remote ShareSheetUI may still control its own presentation.
- **Advertising feedback (`r1`)**: isolated WebKit form styling activates only when both **Leave feedback** and **This ad is** text are present. OLED sheet/form/inputs/buttons, white neutral labels, gray borders/dividers, authored checkbox states and links preserved. Trigger is the existing ad-feedback link, with two finite callback checks; no continuous observers.
- **Alexa explainer/editorial (`r5`)**: blackens the captured `.octopus-page-style` content-grid floors, not the hero artwork itself; applies existing preference-controlled TWB only to grid-image raster leaves (not the Home sponsored raster).
- All previously landed v7.605–v7.621 modules and three probes remain; only version identifiers updated to v7.622.

No broad Home-raster visibility fixes, no synthetic borders, no layout geometry changes, no continuous scanning machinery.
