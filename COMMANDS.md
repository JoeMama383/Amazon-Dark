# AmazonDark v7.441 commands

## PUSH

```zsh
cd /var/mobile/Amazon-Dark-phone &&
D=/private/var/mobile/Containers/Shared/AppGroup/D846D8DE-EE0F-4B82-9676-C68769E519CD/Documents &&
rm -rf /var/mobile/t7441 &&
mkdir -p /var/mobile/t7441 &&
unzip -oq "$D/AmazonDark-v7.441-pdp-site-isolated-frames-source.zip" -d /var/mobile/t7441 &&
cp -a /var/mobile/t7441/AmazonDark-v7.441-pdp-site-isolated-frames-source/. . &&
chmod 755 layout/DEBIAN/postinst &&
sh scripts/validate.sh &&
git add -A &&
git commit -m "v7.441: fix site-isolated PDP ad frames" &&
git push origin main
```

## FULL
Take the screenshot that triggers FULL, then:
```zsh
cd /var/mobile/Amazon-Dark-phone
sh scripts/ui-probe.sh export
```

## VIEWPORT
```zsh
cd /var/mobile/Amazon-Dark-phone
sh scripts/ui-probe.sh arm
```
With the target UI visible, then:
```zsh
cd /var/mobile/Amazon-Dark-phone
sh scripts/ui-probe.sh export
```

## TRANSITION
```zsh
cd /var/mobile/Amazon-Dark-phone
sh scripts/skeleton-probe.sh arm transition
```
Reproduce the transition, then:
```zsh
cd /var/mobile/Amazon-Dark-phone
sh scripts/skeleton-probe.sh export
```
