# AmazonDark v7.600 commands

The canonical artifact name is `AmazonDark-v7.600-pdp-overlay-probe-followup-source.zip`; the `-CI-FIX.zip` suffix identifies the validated repair. The matching family is `AmazonDark-v7.600-pdp-overlay-probe-followup-source*.zip`.

Save the `AmazonDark-v7.600-pdp-overlay-probe-followup-source-CI-FIX.zip` file in `/var/mobile` on your iPhone before pushing.

## Push — v7.600 (existing clone)
```sh
sh <<'SH'
set -eu
cd /var/mobile/Amazon-Dark-phone
ZIP=$(find /var/mobile -type d -name '.Trash*' -prune -o -type f -name 'AmazonDark-v7.600-pdp-overlay-probe-followup-source-CI-FIX.zip' -print 2>/dev/null |
while IFS= read -r candidate; do
  if unzip -tq "$candidate" >/dev/null 2>&1; then printf '%s\n' "$candidate"; break; fi
done)
[ -n "$ZIP" ] || { echo "Save the source ZIP to the phone first."; exit 1; }
STAGE=$(mktemp -d /var/mobile/ad7600.XXXXXX)
unzip -q "$ZIP" -d "$STAGE"
grep -qx 'Version: 7.600~pdp-overlay-probe-followup' "$STAGE/layout/DEBIAN/control"
cp -a "$STAGE/." .
chmod 755 layout/DEBIAN/postinst
AD_STRICT_VALIDATE=0 sh scripts/validate.sh
git add -A
if ! git diff --cached --quiet; then git commit -m "v7.600: PDP overlay, IOU and probe follow-up"; fi
git push origin main
SH
```

## FULL — v7.600
Take a screenshot **inside Amazon**. Keep Amazon visible until the entire scrolling scan completes; leaving the app aborts FULL. Then export from NewTerm.
```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh export full
```

## VIEWPORT — v7.600 ARM
```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh arm
```
Show the exact target scene in Amazon, then background once. VIEWPORT does not scroll.

## VIEWPORT — v7.600 EXPORT
```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh export viewport
```

## TRANSITION — v7.600 ARM
```sh
sh /var/mobile/Amazon-Dark-phone/scripts/skeleton-probe.sh arm transition
```

## TRANSITION — v7.600 EXPORT
```sh
sh /var/mobile/Amazon-Dark-phone/scripts/skeleton-probe.sh export
```

## PERFORMANCE — ARM
```sh
sh /var/mobile/Amazon-Dark-phone/scripts/performance-probe.sh arm
```
Return to Amazon within 10 minutes. Reproduce slow typing, navigation and scrolling for up to 90 seconds, then return to NewTerm. Backgrounding ends the session early. Do not take screenshots or arm another diagnostic during the measurement.

## PERFORMANCE — EXPORT
```sh
sh /var/mobile/Amazon-Dark-phone/scripts/performance-probe.sh export
```
Wait a few seconds after returning to NewTerm. This exports exactly one JSON session in a TAR. Send that TAR with the approximate time and action that felt slow.
