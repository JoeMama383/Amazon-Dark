# AmazonDark v7.412 commands

## PUSH
```zsh
cd /var/mobile/Amazon-Dark-phone
D=/private/var/mobile/Containers/Shared/AppGroup/D846D8DE-EE0F-4B82-9676-C68769E519CD/Documents
rm -rf /var/mobile/t7412 && mkdir -p /var/mobile/t7412
unzip -q "$D/AmazonDark-v7.412-address-location-aux-theme-source.zip" -d /var/mobile/t7412
find . -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +
cp -a /var/mobile/t7412/AmazonDark-v7.412-address-location-aux-theme-source/. .
chmod 755 layout/DEBIAN/postinst
AD_STRICT_VALIDATE=1 sh scripts/validate.sh
git add -A
git commit -m "v7.412: theme address and location auxiliary menus"
git push origin main
```

## FULL
Leave Amazon on the target screen and take an iOS screenshot, then:
```zsh
cd /var/mobile/Amazon-Dark-phone
sh scripts/ui-probe.sh export
```

## VIEWPORT
```zsh
cd /var/mobile/Amazon-Dark-phone
sh scripts/ui-probe.sh arm
# Return to Amazon with the exact frame visible.
sh scripts/ui-probe.sh export
```

## TRANSITION
Force-close Amazon first if you are testing a presentation/transition:
```zsh
cd /var/mobile/Amazon-Dark-phone
sh scripts/skeleton-probe.sh arm transition
# Reproduce the transition.
sh scripts/skeleton-probe.sh export
```
