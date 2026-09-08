# AmazonDark v7.366 commands

## Stage + push

```zsh
D=/private/var/mobile/Containers/Shared/AppGroup/D846D8DE-EE0F-4B82-9676-C68769E519CD/Documents
T=/var/mobile/AmazonDark-v7.366
cd /var/mobile/Amazon-Dark-phone
rm -rf "$T" && mkdir -p "$T"
unzip -q "$D/AmazonDark-v7.366-cart-empty-caption-fix-source.zip" -d "$T"
find . -mindepth 1 -maxdepth 1 ! -name '.git' -exec rm -rf {} +
cp -a "$T/AmazonDark-v7.366-cart-empty-caption-fix-source/." .
git add -A
git commit -m "v7.366: fix visible empty Cart caption"
git push origin main
```

## FULL universal probe

Leave the target visible and take one screenshot. Keep Amazon foregrounded while the finite sweep finishes.

## VIEWPORT universal probe

```zsh
cd /var/mobile/Amazon-Dark-phone && sh scripts/ui-probe.sh arm
```

## Export newest completed FULL + VIEWPORT

```zsh
cd /var/mobile/Amazon-Dark-phone && sh scripts/ui-probe.sh export
```
