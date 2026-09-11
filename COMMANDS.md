# AmazonDark v7.405 commands

## PUSH
```zsh
cd /var/mobile/Amazon-Dark-phone
D=/private/var/mobile/Containers/Shared/AppGroup/D846D8DE-EE0F-4B82-9676-C68769E519CD/Documents
rm -rf /var/mobile/t7405 && mkdir -p /var/mobile/t7405
unzip -q "$D/AmazonDark-v7.405-pdp-completion-source.zip" -d /var/mobile/t7405
find . -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +
cp -a /var/mobile/t7405/AmazonDark-v7.405-pdp-completion-source/. .
chmod 755 layout/DEBIAN/postinst
AD_STRICT_VALIDATE=1 sh scripts/validate.sh
git add -A
git commit -m "v7.405: complete Product Detail Page dark mode"
git push origin main
```

## FULL — screenshot trigger
Leave the target UI visible and take one iOS screenshot, then export:
```zsh
cd /var/mobile/Amazon-Dark-phone
sh scripts/ui-probe.sh export
```

## VIEWPORT — armed current-screen capture
```zsh
cd /var/mobile/Amazon-Dark-phone
sh scripts/ui-probe.sh arm
```
Show the target UI, then:
```zsh
sh scripts/ui-probe.sh export
```

## TRANSITION / lifecycle
Force-close Amazon first, then:
```zsh
cd /var/mobile/Amazon-Dark-phone
sh scripts/skeleton-probe.sh arm transition
```
Reproduce the transition and export:
```zsh
sh scripts/skeleton-probe.sh export
```
