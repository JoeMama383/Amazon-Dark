# AmazonDark v7.442 commands

## PUSH

```zsh
cd /var/mobile/Amazon-Dark-phone &&
D=/private/var/mobile/Containers/Shared/AppGroup/D846D8DE-EE0F-4B82-9676-C68769E519CD/Documents &&
rm -rf /var/mobile/t7442 &&
mkdir -p /var/mobile/t7442 &&
unzip -oq "$D/AmazonDark-v7.442-user-style-ad-ownership-source.zip" -d /var/mobile/t7442 &&
cp -a /var/mobile/t7442/AmazonDark-v7.442-user-style-ad-ownership-source/. . &&
chmod 755 layout/DEBIAN/postinst &&
sh scripts/validate.sh &&
git add -A &&
git commit -m "v7.442: use all-frame user stylesheet for PDP ads" &&
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
