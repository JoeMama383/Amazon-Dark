# AmazonDark v7.519 commands

## PUSH

```sh
cd /var/mobile/Amazon-Dark-phone &&
DOCS=/private/var/mobile/Containers/Shared/AppGroup/D846D8DE-EE0F-4B82-9676-C68769E519CD/Documents &&
STAGE=$(mktemp -d /var/mobile/ad7519.XXXXXX) &&
unzip -q "$DOCS/AmazonDark-v7.519-person-deepscan-stock-returns-border-source.zip" -d "$STAGE" &&
grep -qx 'Version: 7.519~person-deepscan-stock-returns-border' "$STAGE/layout/DEBIAN/control" &&
cp -a "$STAGE/." . &&
rm -f tests/test_v7518_foreground_probe.py REVIEW-v7.518.md &&
chmod 755 layout/DEBIAN/postinst &&
AD_STRICT_VALIDATE=0 sh scripts/validate.sh &&
git add -A &&
git commit -m "v7.519: restore Person deep scan and stock Returns border geometry" &&
git push origin main
```

## FULL — v7.519

Open the Person menu, take one screenshot, and keep Amazon foregrounded until the menu finishes walking and returns to its starting position. Then switch to NewTerm and export.

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh export full
```

## VIEWPORT — v7.519 ARM

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh arm
```

Open Amazon to the target screen after arming, then switch back to NewTerm to create the foreground-boundary capture.

## VIEWPORT — v7.519 EXPORT

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh export viewport
```

## TRANSITION — v7.519 ARM

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/skeleton-probe.sh arm transition
```

## TRANSITION — v7.519 EXPORT

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/skeleton-probe.sh export
```
