# AmazonDark v7.591 commands

Save `AmazonDark-v7.591-regression-recovery-medical-search-source.zip` on the phone first.

## Push — v7.591
```sh
sh <<'SH'
set -eu
cd /var/mobile/Amazon-Dark-phone
ZIP=$(find /var/mobile -type d -name '.Trash*' -prune -o -type f -name 'AmazonDark-v7.591-regression-recovery-medical-search-source*.zip' -print 2>/dev/null |
while IFS= read -r candidate; do
  if unzip -tq "$candidate" >/dev/null 2>&1; then printf '%s\n' "$candidate"; break; fi
done)
[ -n "$ZIP" ] || { echo "Save the source ZIP to your phone first."; exit 1; }
STAGE=$(mktemp -d /var/mobile/ad7591.XXXXXX)
unzip -q "$ZIP" -d "$STAGE"
grep -qx 'Version: 7.591~regression-recovery-medical-search' "$STAGE/layout/DEBIAN/control"
cp -a "$STAGE/." .
chmod 755 layout/DEBIAN/postinst
AD_STRICT_VALIDATE=0 sh scripts/validate.sh
git add -A
if ! git diff --cached --quiet; then git commit -m "v7.591: recover probes, Person media, and medical/search owners"; fi
git push origin main
SH
```

## FULL — v7.591
Take the screenshot on the target screen, keep Amazon foregrounded until the finite walk completes, then export:
```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh export full
```

## VIEWPORT — v7.591 ARM
```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh arm
```

Show the target screen and background Amazon once.

## VIEWPORT — v7.591 EXPORT
```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh export viewport
```

## TRANSITION — v7.591 ARM
```sh
sh /var/mobile/Amazon-Dark-phone/scripts/skeleton-probe.sh arm transition
```

## TRANSITION — v7.591 EXPORT
```sh
sh /var/mobile/Amazon-Dark-phone/scripts/skeleton-probe.sh export
```
