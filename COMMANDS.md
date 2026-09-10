# AmazonDark v7.388 commands

## PUSH
cd /var/mobile/Amazon-Dark-phone && git checkout -q main && D=/private/var/mobile/Containers/Shared/AppGroup/D846D8DE-EE0F-4B82-9676-C68769E519CD/Documents && rm -rf /var/mobile/t7388 && mkdir -p /var/mobile/t7388 && unzip -q "$D/AmazonDark-v7.388-native-work-optimization-source.zip" -d /var/mobile/t7388 && find . -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} + && cp -a /var/mobile/t7388/AmazonDark-v7.388-native-work-optimization-source/. . && chmod 755 layout/DEBIAN/postinst && sh scripts/validate.sh && grep '^Version:' layout/DEBIAN/control && git add -A && git commit -q -m "v7.388: reduce native work and fix probe version gating" && git push origin main

## FULL PROBE
Take a screenshot while the target Amazon screen is visible. Then use VIEWPORT/FULL EXPORT.

## VIEWPORT PROBE
cd /var/mobile/Amazon-Dark-phone && sh scripts/ui-probe.sh arm

## VIEWPORT/FULL EXPORT
cd /var/mobile/Amazon-Dark-phone && sh scripts/ui-probe.sh export

## TRANSITION PROBE
cd /var/mobile/Amazon-Dark-phone && sh scripts/skeleton-probe.sh arm transition

## TRANSITION EXPORT
cd /var/mobile/Amazon-Dark-phone && sh scripts/skeleton-probe.sh export
