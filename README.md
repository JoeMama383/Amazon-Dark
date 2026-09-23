# AmazonDark v7.462 — Search suggestion cards + ScanIt shell

v7.462 is a narrow probe-backed follow-up to v7.461. The supplied v7.461 FULL probe identifies the white description strips under the Search suggestion carousel as `cards_carousel_nview_widget-sug-text` / `cards_carousel_text_left_widget-sug-text`. The existing dark rule only matched `cards_carousel_widget-sug-text`, so v7.462 broadens that exact carousel owner to the shared `widget-sug-text` suffix: OLED black floor with light text.

The same probe identifies the square gray outline around both “Search with” controls as the 430x60 native `A9VSScanItSearchWidget` root (`layerBorder=1px`), while the two child `A9VSScanItIngressButtonRedesign` controls own their separate rounded borders. v7.462 removes only the root square border, keeps the child button borders, and darkens the root's captured 1px stock top hairline. A cheap exact-owner `layoutSubviews` seal only reasserts `borderWidth=0`; it does not walk the subtree.

v7.461 Home hero Sponsored-pill coverage and VIEWPORT reliability changes are retained. FULL, VIEWPORT, and TRANSITION identities are regenerated as v7.462.
