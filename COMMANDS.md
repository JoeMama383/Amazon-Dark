# AmazonDark v7.611 — Your Saves / Lists and Registries OLED restoration

Save `AmazonDark-v7.611-your-saves-oled-followup-source.zip` to iPhone Files first. Accepted family: `AmazonDark-v7.611-your-saves-oled-followup-source*.zip`. Uses existing clone `/var/mobile/Amazon-Dark-phone`.

## PUSH — existing clone

```sh
sh <<'SH'
set -eu
cd /var/mobile/Amazon-Dark-phone
ZIP=$(find /var/mobile -type d -name '.Trash*' -prune -o -type f -name 'AmazonDark-v7.611-your-saves-oled-followup-source.zip' -print 2>/dev/null | head -n 1)
[ -n "$ZIP" ] || { echo 'Save the v7.611 source ZIP to Files on the phone first.'; exit 1; }
unzip -tq "$ZIP"
TMP=$(mktemp -d /var/mobile/ad7611.XXXXXX)
unzip -q "$ZIP" -d "$TMP"
STAGE="$TMP/ad7611"
grep -qx 'Version: 7.611~your-saves-oled-followup' "$STAGE/layout/DEBIAN/control"
grep -Fqx '#define AD_VERSION "v7.611-your-saves-oled-followup"' "$STAGE/src/Tweak.xm"
cp -a "$STAGE/." .
chmod 755 layout/DEBIAN/postinst
AD_STRICT_VALIDATE=0 sh scripts/validate.sh
git add -A
if ! git diff --cached --quiet; then git commit -m 'v7.611: restore Your Saves cards, filter controls, text and raster taming'; fi
git push origin main
SH
```

## FULL — v7.611

Take one screenshot in Your Saves and KEEP AMAZON FOREGROUNDED until FULL finishes. A background-triggered VIEWPORT while FULL runs cannot complete the foreground WebKit walk.


```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh export full
```

## VIEWPORT — v7.611 ARM

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh arm
```

## VIEWPORT — v7.611 EXPORT

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh export viewport
```

## TRANSITION — v7.611 ARM

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/skeleton-probe.sh arm transition
```

## TRANSITION — v7.611 EXPORT

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/skeleton-probe.sh export
```
