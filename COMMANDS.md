# AmazonDark v7.620 — Orders and Advertising Preferences OLED rebuild

Save `AmazonDark-v7.620-orders-adprivacy-oled-rebuild-source.zip` to iPhone Files before the PUSH command. Supported source filename pattern: `AmazonDark-v7.620-orders-adprivacy-oled-rebuild-source*.zip`.

## PUSH — existing clone

```sh
sh <<'SH'
set -eu
cd /var/mobile/Amazon-Dark-phone
ZIP=$(find /var/mobile -type d -name '.Trash*' -prune -o -type f -name 'AmazonDark-v7.620-orders-adprivacy-oled-rebuild-source.zip' -print 2>/dev/null | head -n 1)
[ -n "$ZIP" ] || { echo 'Save v7.620 source ZIP to Files first.'; exit 1; }
unzip -tq "$ZIP"
TMP=$(mktemp -d /var/mobile/ad7620.XXXXXX)
unzip -q "$ZIP" -d "$TMP"
STAGE="$TMP/ad7620"
grep -qx 'Version: 7.620~orders-adprivacy-oled-rebuild' "$STAGE/layout/DEBIAN/control"
grep -Fqx '#define AD_VERSION "v7.620-orders-adprivacy-oled-rebuild"' "$STAGE/src/Tweak.xm"
cp -a "$STAGE/." .
chmod 755 layout/DEBIAN/postinst
AD_STRICT_VALIDATE=0 sh scripts/validate.sh
git add -A
if ! git diff --cached --quiet; then git commit -m 'v7.620: exact OLED Order Details and Advertising Preferences; no Home raster changes'; fi
git push origin main
SH
```

## FULL — v7.620

Screenshot in Amazon to start a FULL scan, leave it foregrounded until complete, then export current capture TAR:

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh export full
```

Foreground fallback when screenshot notification fails:

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh arm full
```

## VIEWPORT — v7.620 ARM

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh arm
```

## VIEWPORT — v7.620 EXPORT

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh export viewport
```

## TRANSITION — v7.620 ARM

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/skeleton-probe.sh arm transition
```

## TRANSITION — v7.620 EXPORT

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/skeleton-probe.sh export
```
