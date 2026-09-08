# AmazonDark v7.365 commands

## Stage + push

```zsh
D=/private/var/mobile/Containers/Shared/AppGroup/D846D8DE-EE0F-4B82-9676-C68769E519CD/Documents
T=/var/mobile/AmazonDark-v7.365
cd /var/mobile/Amazon-Dark-phone
rm -rf "$T" && mkdir -p "$T"
unzip -q "$D/AmazonDark-v7.365-probe-backed-cart-sameday-sustainability-source.zip" -d "$T"
find . -mindepth 1 -maxdepth 1 ! -name '.git' -exec rm -rf {} +
cp -a "$T/AmazonDark-v7.365-probe-backed-cart-sameday-sustainability-source/." .
git add -A
git commit -m "v7.365: fix Cart same-day text and Sustainability sheet"
git push origin main
```

## FULL universal probe

Leave the target screen/menu visible and take **one screenshot**. Keep Amazon foregrounded while the finite sweep finishes.

Output: `AmazonDark-v7.365-ui-full-probe-...txt`

## VIEWPORT universal probe

```zsh
cd /var/mobile/Amazon-Dark-phone && sh scripts/ui-probe.sh arm
```

Output: `AmazonDark-v7.365-ui-viewport-probe-...txt`

## Export newest completed FULL + VIEWPORT captures

```zsh
cd /var/mobile/Amazon-Dark-phone && sh scripts/ui-probe.sh export
```
