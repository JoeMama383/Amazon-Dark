# AmazonDark v7.368 commands

Source: `AmazonDark-v7.368-checkout-byg-order-theme-source.zip`

## Stage + push

```zsh
D=/private/var/mobile/Containers/Shared/AppGroup/D846D8DE-EE0F-4B82-9676-C68769E519CD/Documents
T=/var/mobile/AmazonDark-v7.368
cd /var/mobile/Amazon-Dark-phone
rm -rf "$T" && mkdir -p "$T"
unzip -q "$D/AmazonDark-v7.368-checkout-byg-order-theme-source.zip" -d "$T"
find . -mindepth 1 -maxdepth 1 ! -name '.git' -exec rm -rf {} +
cp -a "$T/AmazonDark-v7.368-checkout-byg-order-theme-source/." .
git add -A
git commit -m "v7.368: theme checkout recommendations and place order"
git push origin main
```

## Universal probes

VIEWPORT: `cd /var/mobile/Amazon-Dark-phone && sh scripts/ui-probe.sh arm`

Export newest completed FULL + VIEWPORT: `cd /var/mobile/Amazon-Dark-phone && sh scripts/ui-probe.sh export`

FULL: leave the target visible and take one screenshot.
