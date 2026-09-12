# AmazonDark v7.411 commands

## PUSH
```zsh
cd /var/mobile/Amazon-Dark-phone
D=/private/var/mobile/Containers/Shared/AppGroup/D846D8DE-EE0F-4B82-9676-C68769E519CD/Documents
rm -rf /var/mobile/t7411 && mkdir -p /var/mobile/t7411
unzip -q "$D/AmazonDark-v7.411-permission-firstpaint-owner-fix-source.zip" -d /var/mobile/t7411
find . -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +
cp -a /var/mobile/t7411/AmazonDark-v7.411-permission-firstpaint-owner-fix-source/. .
chmod 755 layout/DEBIAN/postinst
AD_STRICT_VALIDATE=1 sh scripts/validate.sh
git add -A
git commit -m "v7.411: fix permission first-paint ownership"
git push origin main
```

## FULL probe
Leave Amazon on the target screen and take an iOS screenshot. Then export:
```zsh
cd /var/mobile/Amazon-Dark-phone
sh scripts/ui-probe.sh export
```

## VIEWPORT probe — arm
With Amazon already open on the target screen:
```zsh
cd /var/mobile/Amazon-Dark-phone
sh scripts/ui-probe.sh arm
```

## VIEWPORT probe — export
Return to Amazon and leave the exact target frame visible. Then:
```zsh
cd /var/mobile/Amazon-Dark-phone
sh scripts/ui-probe.sh export
```

## TRANSITION probe — arm
Force-close Amazon first:
```zsh
cd /var/mobile/Amazon-Dark-phone
sh scripts/skeleton-probe.sh arm transition
```

## TRANSITION probe — export
Reproduce the transition/backgrounding issue, then:
```zsh
cd /var/mobile/Amazon-Dark-phone
sh scripts/skeleton-probe.sh export
```
