# AmazonDark v7.413 commands

## PUSH
```zsh
cd /var/mobile/Amazon-Dark-phone
D=/private/var/mobile/Containers/Shared/AppGroup/D846D8DE-EE0F-4B82-9676-C68769E519CD/Documents
rm -rf /var/mobile/t7413 && mkdir -p /var/mobile/t7413
unzip -q "$D/AmazonDark-v7.413-address-location-compile-fix-source.zip" -d /var/mobile/t7413
find . -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +
cp -a /var/mobile/t7413/AmazonDark-v7.413-address-location-compile-fix-source/. .
chmod 755 layout/DEBIAN/postinst
git add -A
git commit -m "v7.413: fix address location compile error"
git push origin main
```

## FULL
```zsh
cd /var/mobile/Amazon-Dark-phone
sh scripts/ui-probe.sh export
```

## VIEWPORT
```zsh
cd /var/mobile/Amazon-Dark-phone
sh scripts/ui-probe.sh arm
# Return to Amazon with the target frame visible.
sh scripts/ui-probe.sh export
```

## TRANSITION
```zsh
cd /var/mobile/Amazon-Dark-phone
sh scripts/skeleton-probe.sh arm transition
# Reproduce the transition/loading issue.
sh scripts/skeleton-probe.sh export
```

## VALIDATE
```zsh
cd /var/mobile/Amazon-Dark-phone
sh scripts/validate.sh
```
