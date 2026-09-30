# AmazonDark v7.535 commands

Save `AmazonDark-v7.535-interests-modal-oled-paint-source.zip` on the phone first.

## Push

```sh
cd /var/mobile/Amazon-Dark-phone &&
ZIP=$(find /var/mobile -type f -name 'AmazonDark-v7.535-interests-modal-oled-paint-source*.zip' 2>/dev/null | head -n 1) &&
[ -n "$ZIP" ] &&
STAGE=$(mktemp -d /var/mobile/ad7535.XXXXXX) &&
unzip -q "$ZIP" -d "$STAGE" &&
grep -qx 'Version: 7.535~interests-modal-oled-paint' "$STAGE/layout/DEBIAN/control" &&
cp -a "$STAGE/." . &&
chmod 755 layout/DEBIAN/postinst &&
AD_STRICT_VALIDATE=0 sh scripts/validate.sh &&
git add -A &&
git commit -m "v7.535: remove Interests modal fade, normalize focus border and dark input scheme" &&
git push origin main
```

## FULL — v7.535

Take a screenshot in Amazon and let the scan finish, then export from NewTerm.

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh export full
```

## VIEWPORT — v7.535 ARM

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh arm
```

## VIEWPORT — v7.535 EXPORT

After arming, open the target screen in Amazon, then return to NewTerm and export the captured foreground scene.

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh export viewport
```

## TRANSITION — v7.535 ARM

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/skeleton-probe.sh arm transition
```

## TRANSITION — v7.535 EXPORT

After arming, reproduce the transition in Amazon, then return to NewTerm and export.

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/skeleton-probe.sh export
```
