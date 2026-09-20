# AmazonDark v7.431 commands

## PUSH

```zsh
cd /var/mobile/Amazon-Dark-phone &&
D=/private/var/mobile/Containers/Shared/AppGroup/D846D8DE-EE0F-4B82-9676-C68769E519CD/Documents &&
mkdir -p /var/mobile/t7431 &&
unzip -oq "$D/AmazonDark-v7.431-pdp-r2-r5-fix-source.zip" -d /var/mobile/t7431 &&
cp -a /var/mobile/t7431/AmazonDark-v7.431-pdp-r2-r5-fix-source/. . &&
chmod 755 layout/DEBIAN/postinst &&
sh scripts/validate.sh &&
git add -A &&
git commit -m "v7.431: finish PDP r2-r5 theming" &&
git push origin main
```

## FULL — TRIGGER

Leave the exact target visible and take an iOS screenshot.

## FULL — EXPORT

```zsh
cd /var/mobile/Amazon-Dark-phone
sh scripts/ui-probe.sh export
```

## VIEWPORT — ARM

```zsh
cd /var/mobile/Amazon-Dark-phone
sh scripts/ui-probe.sh arm
```

## VIEWPORT — EXPORT

```zsh
cd /var/mobile/Amazon-Dark-phone
sh scripts/ui-probe.sh export
```

## TRANSITION — ARM

```zsh
cd /var/mobile/Amazon-Dark-phone
sh scripts/skeleton-probe.sh arm transition
```

## TRANSITION — EXPORT

```zsh
cd /var/mobile/Amazon-Dark-phone
sh scripts/skeleton-probe.sh export
```
