# AmazonDark v7.380 commands

## PUSH
cd /var/mobile/Amazon-Dark-phone && git checkout -q main && D=/private/var/mobile/Containers/Shared/AppGroup/D846D8DE-EE0F-4B82-9676-C68769E519CD/Documents && rm -rf /var/mobile/t7380 && mkdir -p /var/mobile/t7380 && unzip -q "$D/AmazonDark-v7.380-amznkiller-features-optimization-audit-source.zip" -d /var/mobile/t7380 && find . -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} + && cp -a /var/mobile/t7380/AmazonDark-v7.380-amznkiller-features-optimization-audit-source/. . && chmod 755 layout/DEBIAN/postinst && sh scripts/validate.sh && grep '^Version:' layout/DEBIAN/control && git add -A && git commit -q -m "v7.380: add shopping enhancements and optimization audit" && git push origin main

## TEAL TRANSITION
cd /var/mobile/Amazon-Dark-phone && sh scripts/skeleton-probe.sh arm transition
cd /var/mobile/Amazon-Dark-phone && sh scripts/skeleton-probe.sh export

## UNIVERSAL VIEWPORT / FULL EXPORT
cd /var/mobile/Amazon-Dark-phone && sh scripts/ui-probe.sh arm
cd /var/mobile/Amazon-Dark-phone && sh scripts/ui-probe.sh export
