# AmazonDark v7.361 — probed renderer paint fixes

Built directly on **v7.360**, commit `aab59b0370eeec3ea4e4cff7741e200950f85db1`.
The recovered v7.360 source ZIP matches this commit byte for byte for every ZIP member.

- **Everything you need for everyday:** the captured Featured Brands mobile card family has OLED-black structural floors, white neutral title/price/review copy, and product images using the configured TWB strength. Semantic and inline colored copy, Prime artwork, and stars retain their colors.
- **Heart and More like this:** standalone and spotlight buttons paint matching gray shells from document start. The placeholder's duplicate background heart is removed only when its image child is present. Hydrated heart background artwork is preserved; a single inversion of the small monochrome control produces a white glyph and the same gray shell for both parent-art and legacy image renderers. Stock hit areas and state artwork remain owned by Amazon.
- **Select in the chevron menu:** restore opaque light ink to Amazon's existing mask. The former transparent background made the mask invisible.
- **Cart Coupon price:** target the captured Apex coupon tile, giving it the existing `#008000` product-coupon green and white copy/price. Checkbox behavior, geometry, and animation remain stock.
- **Researched by Alexa:** tame all five captured `nice-cat-card_image` leaves through the existing media-strength lane. The Alexa symbol and other glyphs are excluded.

The application change is confined to the existing `ADFloorJS` and `ADTWBJS` payloads plus the version string. SpringBoard, native splash/launch behavior, warm boots, app switcher, standalone ads, skeleton capture payload, Makefile and GitHub Actions workflow are unchanged. There are no new hooks, observers, timers, scans or readiness machinery.

Screenshot probes remain active. Historical filenames still start with `AmazonDark-v7.309`; their capture header reports the installed runtime. Skeleton/transition helper receipts and guards now consistently use v7.361 and accept v7.360 during upgrade.

See [COMMANDS.md](COMMANDS.md) for the short source handoff, push, and probe-export commands, and [AUDIT-v7.361.md](AUDIT-v7.361.md) for evidence and validation limits.
