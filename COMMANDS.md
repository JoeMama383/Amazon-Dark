# AmazonDark v7.389 commands

## PUSH
cd /var/mobile/Amazon-Dark-phone && git checkout -q main && D=/private/var/mobile/Containers/Shared/AppGroup/D846D8DE-EE0F-4B82-9676-C68769E519CD/Documents && rm -rf /var/mobile/t7389 && mkdir -p /var/mobile/t7389 && unzip -q "$D/AmazonDark-v7.389-checkout-sheet-switcher-fix-source.zip" -d /var/mobile/t7389 && find . -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} + && cp -a /var/mobile/t7389/AmazonDark-v7.389-checkout-sheet-switcher-fix-source/. . && chmod 755 layout/DEBIAN/postinst && sh scripts/validate.sh && grep '^Version:' layout/DEBIAN/control && git add -A && git commit -q -m "v7.389: darken checkout Subscribe & Save sheet and remove teal switcher shield" && git push origin main

## FULL PROBE
Take a screenshot while the target Amazon screen is visible. Then export.

## VIEWPORT PROBE
cd /var/mobile/Amazon-Dark-phone && sh scripts/ui-probe.sh arm

## VIEWPORT/FULL EXPORT
cd /var/mobile/Amazon-Dark-phone && sh scripts/ui-probe.sh export

## TRANSITION PROBE
Force-close Amazon, arm first, launch fresh, reproduce within 120 seconds:
cd /var/mobile/Amazon-Dark-phone && sh scripts/skeleton-probe.sh arm transition

## TRANSITION EXPORT
cd /var/mobile/Amazon-Dark-phone && sh scripts/skeleton-probe.sh export
