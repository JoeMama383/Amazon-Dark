# AmazonDark v7.416 commands

## PUSH
```zsh
cd /var/mobile/Amazon-Dark-phone
D=/private/var/mobile/Containers/Shared/AppGroup/D846D8DE-EE0F-4B82-9676-C68769E519CD/Documents
rm -rf /var/mobile/t7416 && mkdir -p /var/mobile/t7416
unzip -q "$D/AmazonDark-v7.416-location-canonical-owner-source.zip" -d /var/mobile/t7416
find . -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +
cp -a /var/mobile/t7416/AmazonDark-v7.416-location-canonical-owner-source/. .
chmod 755 layout/DEBIAN/postinst
sh scripts/validate.sh
git add -A
git commit -m "v7.416: canonicalize location menu ownership"
git push origin main
```

## FULL — TRIGGER
Leave the exact target menu visible and take an iOS screenshot.

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
