# AmazonDark v7.609 — Review photo recovery and sort popup

Based on the complete v7.608 source. Analyzes both supplied v7.605 UI probes.

## Actual cause of blank review photos

The v7.605 VIEWPORT shows real image elements in the top customer-photo carousel (`img._Y3Itb_media-thumbnail-image_3qPWk`) rendered with configured `brightness(0.42)`, but **no image elements inside** the in-review `button.review-image-thumbnail` items. Those buttons are 235×160, black, and have computed `background-image: none`. They are CSS-background-backed media, not conventional `<img>` tiles.

The existing v7.593 `ADReviewBusiness7593.js.inc` directly stripped their authored background imagery with `background-image:none!important` on `.review-image-thumbnail`. Its later broad v7.594 `[class*=review-image]` rule compounded this with `background:transparent!important` (the shorthand resets background-image). The effects remain even after simply forcing `display:block` and `visibility:visible`, explaining the persistent blank slots.

## Changes

1. Removed all photo/video tile families from the generic structural `background-image:none!important` rule. Kept generic black panel floors intact.
2. Replaced the later `background:transparent!important` shorthand with the non-destructive `background-color:transparent!important`, preserving Amazon's authored `background-image` while retaining the existing structural visibility contract.
3. Scoped a single CSS background-color/multiply treatment to the already-existing review-photo buttons, using the same configurable brightness factor as other review media. No pseudo-image, clone image, extra DOM work, double dimming, or geometry changes. The top customer photo carousel remains covered by its existing `img` brightness styling.
4. Added `ADReviewSortPopover7609.js` and a gnu++98-safe JS include. Scoped strictly to `#a-popover-2.a-popover.a-dropdown.a-dropdown-common:has(.sort-order-option)` captured by the VIEWPORT: OLED wrapper/header/list, white option text and white close sprite, gray dividers/border, selected row black-gray **with original blue `#2162a1` selected border preserved**. No border width/radius/shape edits.
5. Updated version/probe identifiers to `7.609` and updated historical review-filter and PDP last-mile tests to treat the current handoff's package version as canonical.

No new observers, scan routines, timers, geometry mutations, or probe changes. v7.608 review-filter menu styling and previous PDP improvements remain intact.
