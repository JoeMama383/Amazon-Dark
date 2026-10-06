# AmazonDark v7.567 commands

Save `AmazonDark-v7.567-health-raster-map-details-source.zip` on the phone first.

## Push — v7.567

```sh
sh <<'SH'
set -eu
cd /var/mobile/Amazon-Dark-phone
ZIP=$(find /var/mobile -type d -name '.Trash*' -prune -o -type f -name 'AmazonDark-v7.567-health-raster-map-details-source*.zip' -print 2>/dev/null |
while IFS= read -r candidate; do
  if unzip -tq "$candidate" >/dev/null 2>&1; then printf '%s\n' "$candidate"; break; fi
done)
[ -n "$ZIP" ] || { echo "Save the source ZIP to your phone first."; exit 1; }
STAGE=$(mktemp -d /var/mobile/ad7567.XXXXXX)
unzip -q "$ZIP" -d "$STAGE"
grep -qx 'Version: 7.567~health-raster-map-details' "$STAGE/layout/DEBIAN/control"
cp -a "$STAGE/." .
chmod 755 layout/DEBIAN/postinst
AD_STRICT_VALIDATE=0 sh scripts/validate.sh
git add -A
if ! git diff --cached --quiet; then git commit -m "v7.567: repair Health AI raster edges and map glyph details"; fi
git push origin main
SH
```

## FULL — v7.567

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh export full
```

## VIEWPORT — v7.567 ARM

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh arm
```

## VIEWPORT — v7.567 EXPORT

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh export viewport
```

## TRANSITION — v7.567 ARM

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/skeleton-probe.sh arm transition
```

## TRANSITION — v7.567 EXPORT

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/skeleton-probe.sh export
```
