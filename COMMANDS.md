# AmazonDark v7.369 commands

D=/private/var/mobile/Containers/Shared/AppGroup/D846D8DE-EE0F-4B82-9676-C68769E519CD/Documents
T=/var/mobile/AmazonDark-v7.369
cd /var/mobile/Amazon-Dark-phone
rm -rf "$T" && mkdir -p "$T"
unzip -q "$D/AmazonDark-v7.369-checkout-isolated-theme-source.zip" -d "$T"
find . -mindepth 1 -maxdepth 1 ! -name '.git' -exec rm -rf {} +
cp -a "$T/AmazonDark-v7.369-checkout-isolated-theme-source/." .
git add -A
git commit -m "v7.369: isolate checkout theming and restore WebUI baseline"
git push origin main

Viewport: cd /var/mobile/Amazon-Dark-phone && sh scripts/ui-probe.sh arm
Export:   cd /var/mobile/Amazon-Dark-phone && sh scripts/ui-probe.sh export
FULL: leave target visible and take one screenshot.
