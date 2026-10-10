# AmazonDark v7.619 — handoff regression and CI validation repair

Save `AmazonDark-v7.619-handoff-regression-repair-source.zip` to Files on your iPhone before PUSH. Expected archive wildcard: `AmazonDark-v7.619-handoff-regression-repair-source*.zip`.

## PUSH — existing clone

```sh
sh <<'SH'
set -eu
cd /var/mobile/Amazon-Dark-phone
ZIP=$(find /var/mobile -type d -name '.Trash*' -prune -o -type f -name 'AmazonDark-v7.619-handoff-regression-repair-source.zip' -print 2>/dev/null | head -n 1)
[ -n "$ZIP" ] || { echo 'Save the v7.619 source ZIP to Files on the phone first.'; exit 1; }
unzip -tq "$ZIP"
TMP=$(mktemp -d /var/mobile/ad7619.XXXXXX)
unzip -q "$ZIP" -d "$TMP"
STAGE="$TMP/ad7619"
grep -qx 'Version: 7.619~handoff-regression-repair' "$STAGE/layout/DEBIAN/control"
grep -Fqx '#define AD_VERSION "v7.619-handoff-regression-repair"' "$STAGE/src/Tweak.xm"
cp -a "$STAGE/." .
chmod 755 layout/DEBIAN/postinst
AD_STRICT_VALIDATE=0 sh scripts/validate.sh
git add -A
if ! git diff --cached --quiet; then git commit -m 'v7.619: repair legacy probe handoff headings and strict regressions'; fi
git push origin main
SH
```

## FULL — v7.619

Screenshot inside Amazon to trigger FULL, remain in the foreground until complete, then export current-session TAR:

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh export full
```

Optional FULL screenshot-notification fallback (return to Amazon to start scanning):

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh arm full
```

## VIEWPORT — v7.619 ARM

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh arm
```

## VIEWPORT — v7.619 EXPORT

After backgrounding Amazon once:

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh export viewport
```

## TRANSITION — v7.619 ARM

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/skeleton-probe.sh arm transition
```

## TRANSITION — v7.619 EXPORT

After performing a transition:

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/skeleton-probe.sh export
```
