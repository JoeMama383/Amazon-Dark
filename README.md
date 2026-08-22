# AmazonDark v6.0.197~probe — preserve carousel speed + restore PDP dark surfaces

Base: v6.0.196~probe.

## Regression fixed

v6.0.196 made the PDP photo carousel substantially more responsive, but its media-carousel fast-lane predicate was too broad. It treated any PDP node that merely *contained* an `.a-carousel-card` as though the whole node belonged to the media carousel. The fallback dark-surface/contrast owner could therefore skip large product-page sections whose subtree happened to contain the photo carousel. That left explicit Amazon white section/card backgrounds visible even though the actual product media was correctly tamed.

## v6.0.197 correction

- Keeps the v6.0.196 fast path for the main product-photo media block and actual video-carousel/video-card families.
- Removes the descendant-based fast-lane match. A parent page section is no longer excluded just because a media carousel exists somewhere below it.
- Removes the global generic `.a-carousel-card/.a-carousel-container` match. Generic recommendation/option carousels remain eligible for normal dark-surface theming.
- The bounded fallback TreeWalker now rejects the *actual media-carousel subtree* with `FILTER_REJECT`, so the outer PDP section and neighboring backgrounds can darken without walking every photo/video descendant.
- Native/ad island discovery likewise filters exact media-carousel descendants rather than suppressing the enclosing PDP section.
- v6.0.196 photo/video carousel layout and native large-image fast paths are otherwise retained.

## Probe

When Amazon backgrounds, v6.0.197 appends `CAROUSELBG6197` JSON to the existing diagnostic file. It records visible light backgrounds and the computed background state of `html`, `body`, `#a-page`, `#ppd`, and the media block. The probe runs only on resign-active/background; it adds no carousel-time work.

## Device test

1. Force-close/reopen Amazon and open the same PDP.
2. Confirm the main photo carousel keeps the v6.0.196 first-swipe responsiveness.
3. Confirm the white PDP floors/cards in the screenshot return to the configured dark theme.
4. Check the lower video carousel for the same responsiveness.
5. If any light panel remains, leave that exact panel visible, background Amazon once, and send the `CAROUSELBG6197` lines from the probe file.
