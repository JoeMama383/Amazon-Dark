# DIFF v7.598

- Review page: restore/tame review-image tiles, keep the product header above Customer reviews visible, and normalize dividers to gray.
- PDP: tame/show Frequently Bought Together images.
- PDP sponsored/top ad follow-up: switch bright white borders to gray, force the white date/price plate to OLED, restore lower ad images, tame them, and normalize Add to cart buttons to OLED black with gray borders and white text.

## Packaging repair (same version)
- Repair v7.598 helper and capture identities: `scripts/ui-probe.sh`, `scripts/skeleton-probe.sh`, `scripts/performance-probe.sh`, their corresponding native probe/state/file naming, and the FULL/VIEWPORT/frame/transition/performance JavaScript version fields. The original v7.598 archive inherited the v7.597 probe versions and stopped during `scripts/validate.sh` before Git commit/push.
