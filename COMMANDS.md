# AmazonDark v7.381 commands

## PUSH
cd /var/mobile/Amazon-Dark-phone && git checkout -q main && D=/private/var/mobile/Containers/Shared/AppGroup/D846D8DE-EE0F-4B82-9676-C68769E519CD/Documents && rm -rf /var/mobile/t7381 && mkdir -p /var/mobile/t7381 && unzip -q "$D/AmazonDark-v7.381-sponsored-slot-collapse-ad-floor-source.zip" -d /var/mobile/t7381 && find . -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} + && cp -a /var/mobile/t7381/AmazonDark-v7.381-sponsored-slot-collapse-ad-floor-source/. . && chmod 755 layout/DEBIAN/postinst && sh scripts/validate.sh && grep '^Version:' layout/DEBIAN/control && git add -A && git commit -q -m "v7.381: collapse blocked ad slots and darken Home ad loading floors" && git push origin main

## UNIVERSAL VIEWPORT
cd /var/mobile/Amazon-Dark-phone && sh scripts/ui-probe.sh arm
cd /var/mobile/Amazon-Dark-phone && sh scripts/ui-probe.sh export

## TEAL TRANSITION
cd /var/mobile/Amazon-Dark-phone && sh scripts/skeleton-probe.sh arm transition
cd /var/mobile/Amazon-Dark-phone && sh scripts/skeleton-probe.sh export
