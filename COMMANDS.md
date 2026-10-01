# AmazonDark v7.546 commands

Save `AmazonDark-v7.546-full-menu-route-arbitration-repair-source.zip` on the phone first.

## Push — v7.546

```sh
cd /var/mobile/Amazon-Dark-phone &&
ZIP=$(find /var/mobile -type f -name 'AmazonDark-v7.546-full-menu-route-arbitration-repair-source*.zip' 2>/dev/null | head -n 1) &&
[ -n "$ZIP" ] &&
STAGE=$(mktemp -d /var/mobile/ad7546.XXXXXX) &&
unzip -q "$ZIP" -d "$STAGE" &&
grep -qx 'Version: 7.546~full-menu-route-arbitration-repair' "$STAGE/layout/DEBIAN/control" &&
cp -a "$STAGE/." . &&
chmod 755 layout/DEBIAN/postinst &&
AD_STRICT_VALIDATE=0 sh scripts/validate.sh &&
git add -A &&
git commit -m "v7.546: repair FULL menu route arbitration" &&
git push origin main
```

## FULL — v7.546

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh export full
```

## VIEWPORT — v7.546 ARM

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh arm
```

## VIEWPORT — v7.546 EXPORT

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh export viewport
```

## TRANSITION — v7.546 ARM

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/skeleton-probe.sh arm transition
```

## TRANSITION — v7.546 EXPORT

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/skeleton-probe.sh export
```
