# AmazonDark v7.415 commands

## PUSH
```zsh
cd /var/mobile/Amazon-Dark-phone
D=/private/var/mobile/Containers/Shared/AppGroup/D846D8DE-EE0F-4B82-9676-C68769E519CD/Documents
rm -rf /var/mobile/t7415 && mkdir -p /var/mobile/t7415
unzip -q "$D/AmazonDark-v7.415-location-text-finalize-fix-source.zip" -d /var/mobile/t7415
find . -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +
cp -a /var/mobile/t7415/AmazonDark-v7.415-location-text-finalize-fix-source/. .
chmod 755 layout/DEBIAN/postinst
sh scripts/validate.sh
git add -A
git commit -m "v7.415: fix location text finalization race"
git push origin main
```

## FULL — TRIGGER
Leave the target UI visible and take an iOS screenshot.

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
