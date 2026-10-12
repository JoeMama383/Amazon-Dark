# AmazonDark v7.634

- Adds probe-backed OLED paint for the 22 captured documents and their Content & Devices, Books, Alexa privacy/data, Help, Orders and Buy Again submenu states. See COVERAGE-v7.634.md for the full inventory.
- Fixes dark text, light cards/dialogs/buttons, neutral borders/dividers and monochrome glyphs. Preserves dynamic accents and existing geometry.
- Applies preference-controlled photo taming to captured book/device/payment/product/help artwork without hiding images or filtering parent containers.
- Handles nested Your Books Shadow DOM at component creation, using a shared stylesheet and a bounded late-injection catch-up. No recurring scanning.
- Adds lifecycle, selector/cascade and negative-control regressions. Updates the static scanner census from 8 to 9 for the one bounded catch-up; the stale-module failure remains enforced at 11.
- Repairs the prior Lists regression's version marker so future release normalization follows the actual AD_VERSION declaration.
- Retains v7.633 performance and probe behavior; updates runtime/package/handoff identities to v7.634.

This is a source release for the existing-clone GitHub Actions workflow. It is not a claim of device-verified rendering or a measured performance improvement.
