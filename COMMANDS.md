# AmazonDark v7.454 commands

## PUSH

```sh
cd /var/mobile/Amazon-Dark-phone &&
AD_DOCS=/private/var/mobile/Containers/Shared/AppGroup/D846D8DE-EE0F-4B82-9676-C68769E519CD/Documents &&
AD_STAGE=$(mktemp -d /var/mobile/ad7454.XXXXXX) &&
unzip -q "$AD_DOCS/AmazonDark-v7.454-carousel-probe-order-source.zip" -d "$AD_STAGE" &&
cp -a "$AD_STAGE/AmazonDark-v7.454-carousel-probe-order-source/." . &&
chmod 755 layout/DEBIAN/postinst scripts/ui-probe.sh scripts/skeleton-probe.sh &&
sh scripts/validate.sh &&
git add -A &&
git commit -m "v7.454: fix PDP carousel and start FULL walk first" &&
git push origin main
```

`sh scripts/validate.sh` is intentionally non-strict on the phone: Python tests run in CI when Python is unavailable on iOS.

## FULL

Take one screenshot with the target visible and leave Amazon foregrounded until automatic scrolling stops and returns to the starting position. Then:

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh status
```

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh export full
```

## VIEWPORT

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh arm
```

Return to Amazon with the target scene visible, then background once and export:

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh export viewport
```

## TRANSITION

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/skeleton-probe.sh arm transition
```

Reproduce the transition, then:

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/skeleton-probe.sh export
```
