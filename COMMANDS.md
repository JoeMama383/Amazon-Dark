# AmazonDark v7.623 — Five Alexa, feedback, and share UI surfaces

Save `AmazonDark-v7.623-alexa-ci-compile-repair-source.zip` in iPhone Files.
Expected archive wildcard: `AmazonDark-v7.623-alexa-ci-compile-repair-source*.zip`.

## PUSH — existing clone

```sh
sh <<'SH'
set -eu
cd /var/mobile/Amazon-Dark-phone
ZIP=$(find /var/mobile -type d -name '.Trash*' -prune -o -type f -name 'AmazonDark-v7.623-alexa-ci-compile-repair-source.zip' -print 2>/dev/null | head -n 1)
[ -n "$ZIP" ] || { echo 'Save v7.623 ZIP to Files first.'; exit 1; }
unzip -tq "$ZIP"
TMP=$(mktemp -d /var/mobile/ad7623.XXXXXX)
unzip -q "$ZIP" -d "$TMP"
STAGE="$TMP/ad7623"
grep -qx 'Version: 7.623~alexa-ci-compile-repair' "$STAGE/layout/DEBIAN/control"
grep -Fqx '#define AD_VERSION "v7.623-alexa-ci-compile-repair"' "$STAGE/src/Tweak.xm"
cp -a "$STAGE/." .
chmod 755 layout/DEBIAN/postinst
AD_STRICT_VALIDATE=0 sh scripts/validate.sh
git add -A
if ! git diff --cached --quiet; then git commit -m 'v7.623: isolate UIKit share hook from native regression fixture'; fi
git push origin main
SH
```

## FULL — v7.623

Screenshot in Amazon, remain foregrounded until scan completes, then:

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh export full
```

## VIEWPORT — v7.623 ARM

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh arm
```

## VIEWPORT — v7.623 EXPORT

Background Amazon once and export:

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh export viewport
```

## TRANSITION — v7.623 ARM

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/skeleton-probe.sh arm transition
```

## TRANSITION — v7.623 EXPORT

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/skeleton-probe.sh export
```
