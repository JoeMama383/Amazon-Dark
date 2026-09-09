# AmazonDark v7.375 commands

cd /var/mobile/Amazon-Dark-phone && git checkout -q main && D=/private/var/mobile/Containers/Shared/AppGroup/D846D8DE-EE0F-4B82-9676-C68769E519CD/Documents && rm -rf /var/mobile/t7375 && mkdir -p /var/mobile/t7375 && unzip -q "$D/AmazonDark-v7.375-checkout-prepaint-snapshot-hydration-source.zip" -d /var/mobile/t7375 && find . -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} + && cp -a /var/mobile/t7375/AmazonDark-v7.375-checkout-prepaint-snapshot-hydration-source/. . && sh scripts/validate.sh && grep '^Version:' layout/DEBIAN/control && git add -A && git commit -q -m "v7.375: fix checkout transition warm snapshot and BYG hydration" && git push origin main

# VIEWPORT
cd /var/mobile/Amazon-Dark-phone && sh scripts/ui-probe.sh arm

# FULL
# Take a screenshot with the target state open.

# Export
cd /var/mobile/Amazon-Dark-phone && sh scripts/ui-probe.sh export
