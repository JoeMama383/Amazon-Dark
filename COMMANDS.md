# AmazonDark v7.618 — verified CI diagnostics repair

Save `AmazonDark-v7.618-native-compiler-error-repair-source.zip` to Files on your iPhone before running PUSH. Valid source wildcard: `AmazonDark-v7.618-native-compiler-error-repair-source*.zip`.

## PUSH — existing clone

```sh
sh <<'SH'
set -eu
cd /var/mobile/Amazon-Dark-phone
ZIP=$(find /var/mobile -type d -name '.Trash*' -prune -o -type f -name 'AmazonDark-v7.618-native-compiler-error-repair-source.zip' -print 2>/dev/null | head -n 1)
[ -n "$ZIP" ] || { echo 'Save the v7.618 ZIP to Files on the phone first.'; exit 1; }
unzip -tq "$ZIP"
TMP=$(mktemp -d /var/mobile/ad7618.XXXXXX)
unzip -q "$ZIP" -d "$TMP"
STAGE="$TMP/ad7618"
grep -qx 'Version: 7.618~native-compiler-error-repair' "$STAGE/layout/DEBIAN/control"
grep -Fqx '#define AD_VERSION "v7.618-native-compiler-error-repair"' "$STAGE/src/Tweak.xm"
cp -a "$STAGE/." .
chmod 755 layout/DEBIAN/postinst
AD_STRICT_VALIDATE=0 sh scripts/validate.sh
git add -A
if ! git diff --cached --quiet; then git commit -m 'v7.618: fix exact Objective-C++ compiler failures and format argument mismatch'; fi
git push origin main
SH
```

## FULL — v7.618

Screenshot-trigger while Amazon is foregrounded; let scan complete before export.

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh export full
```

Optional universal foreground arm for cases where screenshot notification is missed:

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh arm full
```

Return to Amazon, then export FULL normally when done.

## VIEWPORT — v7.618

Arm while on the intended menu, background Amazon once, then export.

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh arm
```

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh export viewport
```

## TRANSITION — v7.618

Arm, perform one transition, then export.

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/skeleton-probe.sh arm transition
```

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/skeleton-probe.sh export
```
