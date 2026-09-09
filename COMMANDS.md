# AmazonDark v7.382 commands

## PUSH
cd /var/mobile/Amazon-Dark-phone && git checkout -q main && D=/private/var/mobile/Containers/Shared/AppGroup/D846D8DE-EE0F-4B82-9676-C68769E519CD/Documents && rm -rf /var/mobile/t7382 && mkdir -p /var/mobile/t7382 && unzip -q "$D/AmazonDark-v7.382-sponsored-carousel-precision-source.zip" -d /var/mobile/t7382 && find . -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} + && cp -a /var/mobile/t7382/AmazonDark-v7.382-sponsored-carousel-precision-source/. . && chmod 755 layout/DEBIAN/postinst && sh scripts/validate.sh && grep '^Version:' layout/DEBIAN/control && git add -A && git commit -q -m "v7.382: narrow sponsored carousel ownership" && git push origin main

## VIEWPORT PROBE
cd /var/mobile/Amazon-Dark-phone && sh scripts/ui-probe.sh arm

## VIEWPORT/FULL EXPORT
cd /var/mobile/Amazon-Dark-phone && sh scripts/ui-probe.sh export

## TRANSITION PROBE
cd /var/mobile/Amazon-Dark-phone && sh scripts/skeleton-probe.sh arm transition
