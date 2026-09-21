# AmazonDark v7.440 commands

## PUSH

```zsh
cd /var/mobile/Amazon-Dark-phone &&
D=/private/var/mobile/Containers/Shared/AppGroup/D846D8DE-EE0F-4B82-9676-C68769E519CD/Documents &&
rm -rf /var/mobile/t7440 &&
mkdir -p /var/mobile/t7440 &&
unzip -oq "$D/AmazonDark-v7.440-pdp-frame-ownership-source.zip" -d /var/mobile/t7440 &&
cp -a /var/mobile/t7440/AmazonDark-v7.440-pdp-frame-ownership-source/. . &&
chmod 755 layout/DEBIAN/postinst &&
sh scripts/validate.sh &&
git add -A &&
git commit -m "v7.440: fix PDP ad frame ownership" &&
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
