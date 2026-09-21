# AmazonDark v7.436 audit — Search sponsored rail owner fix

Exact parent: v7.435 `probe-backed-pdp-search-fixes`.

The v7.433 VIEWPORT probe identifies the surviving bright rails as the full-width `div.s-container-results.s-result-list.s-search-results.sg-row` under the sponsored search-results widget. Its computed background is `rgb(255, 255, 255)`.

v7.435 themed `.s-result-item.AdHolder` and its descendants, but this white `s-container-results` node is an **ancestor** of those AdHolder rows, so that rule could never reach it.

v7.436 adds one exact route-local owner for `.s-widget-container[class*="widgetId=container-search-results_sponsored"]` and its immediate/descendant `.s-container-results` wrapper. The wrapper background and left/right rails are forced OLED black; pseudo-elements are also neutralized. No other architecture changes.
