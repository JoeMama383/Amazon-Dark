# AmazonDark v7.365 — probe-backed Cart same-day + Sustainability sheet

Direct base: **v7.364~universal-full-sweep-probes**.

This release uses the new universal FULL probes to fix only the exact owners captured in the supplied Cart and Product Search runs. The v7.364 universal FULL/VIEWPORT architecture, launch behavior, TWB policy, and all earlier theming remain intact.

## Cart

- **Same-day progress track:** the FULL probe captured `div.a-meter.p13n-same-day-bar-v2` with a stock-white `rgb(255,255,255)` background even though its current `.a-meter-bar` child filled the entire width green. v7.365 paints only that underlying track OLED black. Amazon's authored green fill is not recolored.
- **Same-day sentence:** exact `p13n-same-day-info-text-before-price`, `p13n-same-day-info-text-after-price`, `p13n-same-day-amount-left-v2`, and `p13n-same-day-threshold-price-v2` neutral lanes become light.
- **Saved-item history metadata:** the probe-captured bare `.a-size-small` product-history lane (hash `078d1d2f`) becomes light without touching success/link/price semantic lanes.
- **Empty/removed state:** the stock-dark Cart header and removed-message neutral copy become light. The embedded `.sc-removed-msg-title` stays Amazon blue, and the existing Undo button treatment is unchanged.

## Product Search Sustainability bottom sheet

The FULL probe captured the actual visible AUI sheet, including:

- stock-white `.a-sheet-web` and `.a-sheet-content-container`
- stock-white sticky footer
- stock-white `s-pc-bottom-sheet-carousel-inner` cards with 1px `rgb(213,217,217)` borders and 15px radius
- the visible `Sustainability features` heading and neutral certification copy

v7.365 changes those exact sheet planes to OLED black, gives the certification cards the standard **1px `#494d4d`** AmazonDark border, and makes neutral copy light. The Sustainability program artwork/glyph lane is not filtered, the program parent retains Amazon's green `rgb(4,112,91)`, and the explicit `a-color-link` lane remains Amazon blue.

## Probes

Exactly two universal UI probe categories remain:

- **FULL:** take one screenshot. The finite Web/native full sweep runs and restores every original scroll position.
- **VIEWPORT:** `sh scripts/ui-probe.sh arm`, then one-shot SIGUSR2 captures only the current screen frame with no scrolling.
- **Export both:** `sh scripts/ui-probe.sh export`.

No route-specific probe engines were reintroduced.
