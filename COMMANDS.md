# AmazonDark v7.532 commands

Save `AmazonDark-v7.532-interests-historical-regression-restore-source.zip` on the phone first.

## Push

```sh
cd /var/mobile/Amazon-Dark-phone &&
ZIP=$(find /var/mobile -type f -name 'AmazonDark-v7.532-interests-historical-regression-restore-source*.zip' 2>/dev/null | head -n 1) &&
[ -n "$ZIP" ] &&
STAGE=$(mktemp -d /var/mobile/ad7532.XXXXXX) &&
unzip -q "$ZIP" -d "$STAGE" &&
grep -qx 'Version: 7.532~interests-historical-regression-restore' "$STAGE/layout/DEBIAN/control" &&
cp -a "$STAGE/." . &&
chmod 755 layout/DEBIAN/postinst &&
AD_STRICT_VALIDATE=0 sh scripts/validate.sh &&
git add -A &&
git commit -m "v7.532: restore Interests historical regression contract" &&
git push origin main
```

## FULL — v7.532

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh export full
```

## VIEWPORT — v7.532 ARM

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh arm
```

## VIEWPORT — v7.532 EXPORT

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh export viewport
```

## TRANSITION — v7.532 ARM

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/skeleton-probe.sh arm transition
```

## TRANSITION — v7.532 EXPORT

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/skeleton-probe.sh export
```
