# AmazonDark v7.374 commands

cd /var/mobile/Amazon-Dark-phone && git checkout -q main && D=/private/var/mobile/Containers/Shared/AppGroup/D846D8DE-EE0F-4B82-9676-C68769E519CD/Documents && rm -rf /var/mobile/t7374 && mkdir -p /var/mobile/t7374 && unzip -q "$D/AmazonDark-v7.374-byg-price-checkout-first-paint-source.zip" -d /var/mobile/t7374 && find . -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} + && cp -a /var/mobile/t7374/AmazonDark-v7.374-byg-price-checkout-first-paint-source/. . && grep '^Version:' layout/DEBIAN/control && git add -A && git commit -q -m "v7.374: fix BYG price and checkout first paint" && git push origin main

# VIEWPORT
cd /var/mobile/Amazon-Dark-phone && sh scripts/ui-probe.sh arm

# FULL: take a screenshot with the target screen open.

# Export
cd /var/mobile/Amazon-Dark-phone && sh scripts/ui-probe.sh export
