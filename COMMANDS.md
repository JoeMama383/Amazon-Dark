# AmazonDark v7.595 commands

Save the `AmazonDark-v7.595-buyagain-discover-comparison-probe-source.zip` file in `/var/mobile` on your iPhone before pushing.

## Push — v7.595 (existing clone)
```sh
sh <<'SH'
set -eu
cd /var/mobile/Amazon-Dark-phone
ZIP=$(find /var/mobile -type d -name '.Trash*' -prune -o -type f -name 'AmazonDark-v7.595-buyagain-discover-comparison-probe-source*.zip' -print 2>/dev/null |
while IFS= read -r candidate; do
  if unzip -tq "$candidate" >/dev/null 2>&1; then printf '%s\n' "$candidate"; break; fi
done)
[ -n "$ZIP" ] || { echo "Save the source ZIP to the phone first."; exit 1; }
STAGE=$(mktemp -d /var/mobile/ad7595.XXXXXX)
unzip -q "$ZIP" -d "$STAGE"
grep -qx 'Version: 7.595~buyagain-discover-comparison-probe' "$STAGE/layout/DEBIAN/control"
cp -a "$STAGE/." .
chmod 755 layout/DEBIAN/postinst
AD_STRICT_VALIDATE=0 sh scripts/validate.sh
git add -A
if ! git diff --cached --quiet; then git commit -m "v7.595: theme Buy Again, Discover, A+ comparison; recover Web-first FULL and independent VIEWPORT"; fi
git push origin main
SH
```

## FULL — v7.595
Take a screenshot **inside Amazon**. Keep Amazon visible until the entire scrolling scan completes; leaving the app aborts FULL. Then export from NewTerm.
```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh export full
```

## VIEWPORT — v7.595 ARM
```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh arm
```
Show the exact target scene in Amazon, then background once. VIEWPORT does not scroll.

## VIEWPORT — v7.595 EXPORT
```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh export viewport
```

## TRANSITION — v7.595 ARM
```sh
sh /var/mobile/Amazon-Dark-phone/scripts/skeleton-probe.sh arm transition
```

## TRANSITION — v7.595 EXPORT
```sh
sh /var/mobile/Amazon-Dark-phone/scripts/skeleton-probe.sh export
```
