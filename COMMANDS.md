# AmazonDark v7.383 commands

## PUSH
cd /var/mobile/Amazon-Dark-phone && git checkout -q main && D=/private/var/mobile/Containers/Shared/AppGroup/D846D8DE-EE0F-4B82-9676-C68769E519CD/Documents && rm -rf /var/mobile/t7383 && mkdir -p /var/mobile/t7383 && unzip -q "$D/AmazonDark-v7.383-sponsored-selector-rules-source.zip" -d /var/mobile/t7383 && find . -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} + && cp -a /var/mobile/t7383/AmazonDark-v7.383-sponsored-selector-rules-source/. . && chmod 755 layout/DEBIAN/postinst && sh scripts/validate.sh && grep '^Version:' layout/DEBIAN/control && git add -A && git commit -q -m "v7.383: fix sponsored selector execution and coverage" && git push origin main

## VIEWPORT PROBE
cd /var/mobile/Amazon-Dark-phone && sh scripts/ui-probe.sh arm

## VIEWPORT/FULL EXPORT
cd /var/mobile/Amazon-Dark-phone && sh scripts/ui-probe.sh export

## TRANSITION PROBE
cd /var/mobile/Amazon-Dark-phone && sh scripts/skeleton-probe.sh arm transition
