# AmazonDark v7.402 commands

## PUSH

```sh
cd /var/mobile/Amazon-Dark-phone
D=/private/var/mobile/Containers/Shared/AppGroup/D846D8DE-EE0F-4B82-9676-C68769E519CD/Documents
rm -rf /var/mobile/t7402 && mkdir -p /var/mobile/t7402
unzip -q "$D/AmazonDark-v7.402-payment-first-paint-switcher-fix-source.zip" -d /var/mobile/t7402
find . -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +
cp -a /var/mobile/t7402/AmazonDark-v7.402-payment-first-paint-switcher-fix-source/. .
chmod 755 layout/DEBIAN/postinst
AD_STRICT_VALIDATE=1 sh scripts/validate.sh
git add -A
git commit -m "v7.402: fix payment first paint, switcher, and pickup transition"
git push origin main
```

## FULL UI PROBE

Leave the target Amazon screen visible and take one iOS screenshot, then:

```sh
cd /var/mobile/Amazon-Dark-phone
sh scripts/ui-probe.sh export
```

## VIEWPORT UI PROBE

```sh
cd /var/mobile/Amazon-Dark-phone
sh scripts/ui-probe.sh arm
```

Then export with `sh scripts/ui-probe.sh export`.

## TRANSITION PROBE

Force-close Amazon first, then:

```sh
cd /var/mobile/Amazon-Dark-phone
sh scripts/skeleton-probe.sh arm transition
```

Reproduce within about 120 seconds, return to Amazon, then:

```sh
cd /var/mobile/Amazon-Dark-phone
sh scripts/skeleton-probe.sh export
```
