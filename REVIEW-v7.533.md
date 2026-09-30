# REVIEW v7.533

## Root cause
The catastrophic light-mode regression was not a selector miss. `ADNewMenus7482.js.inc` stopped parsing after v7.530 because the CSS replacement glyph was encoded as `content:\22EE` inside a JavaScript template literal. WebKit rejects that escape before any of the concatenated theme script executes.

## Repair
- Replace the malformed escape with literal `⋮`.
- Preserve the exact v7.529 contextual menu, plus raster, product title/metadata, price and Results owners.
- Preserve v7.530 filled-heart, rating, Update-your-Interest sheet and dark-keyboard changes.
- Add a real reconstructed-payload `node --check` regression.
- Preserve the existing-clone push and separate probe command contract.
