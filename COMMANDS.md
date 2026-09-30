# AmazonDark v7.520 commands

## Push

```sh
cd /var/mobile/Amazon-Dark-phone &&
DOCS=/private/var/mobile/Containers/Shared/AppGroup/D846D8DE-EE0F-4B82-9676-C68769E519CD/Documents &&
STAGE=$(mktemp -d /var/mobile/ad7520.XXXXXX) &&
unzip -q "$DOCS/AmazonDark-v7.520-full-probe-route-contract-menu-deepscan-source.zip" -d "$STAGE" &&
grep -qx 'Version: 7.520~full-probe-route-contract-menu-deepscan' "$STAGE/layout/DEBIAN/control" &&
cp -a "$STAGE/." . &&
rm -f tests/test_v7518_foreground_probe.py &&
chmod 755 layout/DEBIAN/postinst &&
AD_STRICT_VALIDATE=1 sh scripts/validate.sh &&
git add -A &&
git commit -m "v7.520: restore FULL route contract and Hamburger deep scan" &&
git push origin main
```

## FULL — v7.520

Take one screenshot on the target Amazon screen, then export separately:

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh export full
```

## VIEWPORT — v7.520 ARM

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh arm
```

## VIEWPORT — v7.520 EXPORT

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh export viewport
```

## TRANSITION — v7.520 ARM

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/skeleton-probe.sh arm transition
```

## TRANSITION — v7.520 EXPORT

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/skeleton-probe.sh export
```
