# AmazonDark v7.574 — complete captured PDP and Prime UI families

## Baseline and scope

Built on the available v7.572 source archive, retaining the v7.571 Search See-all and Interests welcome fixes, v7.572 white Prime filter label, and earlier keyboard/theme/probe behavior. The other transcript reports v7.573, but its source was not retrievable during this review; this release implements its reported PDP media, review-pill, and sponsored-pill fixes plus the additional captured gaps below. No claim is made that an unavailable source archive was merged.

Reviewed all six retrieved screenshots (IMG_7527.png, IMG_7529.png, IMG_7531.png, IMG_7533.jpeg, IMG_7535.png, IMG_7537.jpeg) and five unique v7.571 viewport captures, r1 through r5. The reuploaded r1 reference names the same capture. The bundle screenshot is above the r2 viewport and is covered using the existing source's exact multi-bundle/FBT renderer families, not invented DOM metadata.

| Capture | Finding | Treatment |
| --- | --- | --- |
| r1 / IMG_7527 | Gray Prime Big Deals label | Retain v7.572 exact white label and text-fill rule. |
| IMG_7529 | Customers Also Bought / Frequently Bought Together artwork untamed | Existing visibility reset overrides older dimming; new preference-controlled leaf rule wins independently of stylesheet order, preserving visible images and geometry. |
| r2 / IMG_7531 | White Sponsored pill | Set only its background to rgba(0,0,0,.9), preserving captured .9 alpha and existing text/info glyph. |
| r2 / IMG_7531 | Dark ad description and missing thumbnail | Whiten exact title/truncation text; remove multiply blending from product-image wrapper and image, and apply normal media dimming. Preserve red price/deal and Prime art. |
| r3 / IMG_7533 | Baby-blue review summary buttons | #303335 fill, #747a7c border, white text including press/focus. Preserve review sentiment icons and already-tamed customer media. |
| r4 / IMG_7535 | Bright Keepa/CamelCamelCamel charts | Tame only the two lazy chart images using the current strength setting. Labels, colored chart lines, links, and collapsible behavior retained. |
| r4 / IMG_7535 | Dark other-seller price and similar-item neutral copy | Exact price/text owners white; branded badge/Prime/success/link paint excluded. |
| r5 / IMG_7537 | Untamed Prime category/banner rasters and blue gradient floor | Tame exact HVE banner and PCPO category image families, OLED PCPO floor, white category labels. Existing product artwork, deal badges, ratings, controls and child ad preserved. |

## Video audit limits

The r1 video is visible at 420 x 236.2 CSS pixels with 640 x 360 media, readyState 4, paused and muted. The r2 video is visible at 393.3 x 221.3 with 1920 x 1080 media, readyState 1 (metadata only), paused and muted. Both have opacity 1, filter none, and visible captured ancestors with no filtering. The probes do not record poster presence, playback progress or decoded pixel content, so they do not conclusively prove a stock blank frame. There is no captured CSS evidence that AmazonDark hides either video. Video playback/poster logic is left unchanged; only the separate r2 product thumbnail and copy are repaired.

## Validation

AD_STRICT_VALIDATE=1 sh scripts/validate.sh: PASS, Logos lint and all 226 Python regressions. Objective-C++ syntax preflights use Clang 18.1.6 bundled with Zig 0.13; CSS cascade matching uses tinycss2/cssselect2/lxml. The new regression checks strength bounds, stylesheet order, semantic exclusions, Sponsored alpha and text readability. git diff --check: PASS. Local syntax/cascade checks do not replace a full Theos/iOS build or on-device visual verification. No production observers, polling, recurring scans, or new input/keyboard ownership were introduced.
