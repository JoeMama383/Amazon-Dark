# AmazonDark v7.602 — PDP visual repair

Save `AmazonDark-v7.602-pdp-visual-repair-source.zip` to Files / On My iPhone (accessible from `/var/mobile`) before using the push block. The source family is `AmazonDark-v7.602-pdp-visual-repair-source*.zip`.

## PUSH — existing clone (do not clone again)

```sh
sh <<'SH'
set -eu
cd /var/mobile/Amazon-Dark-phone
ZIP=$(find /var/mobile -type d -name '.Trash*' -prune -o -type f -name 'AmazonDark-v7.602-pdp-visual-repair-source.zip' -print 2>/dev/null | head -n 1)
[ -n "$ZIP" ] || { echo 'Save the v7.602 source ZIP on the phone first.'; exit 1; }
unzip -tq "$ZIP"
TMP=$(mktemp -d /var/mobile/ad7602.XXXXXX)
unzip -q "$ZIP" -d "$TMP"
STAGE="$TMP/ad7602"
grep -qx 'Version: 7.602~pdp-visual-repair' "$STAGE/layout/DEBIAN/control"
grep -Fqx '#define AD_VERSION "v7.602-pdp-visual-repair"' "$STAGE/src/Tweak.xm"
grep -Fqx 'VER=7.602' "$STAGE/scripts/ui-probe.sh"
grep -Fqx 'AD_PROBE_VERSION=7.602' "$STAGE/scripts/skeleton-probe.sh"
cp -a "$STAGE/." .
chmod 755 layout/DEBIAN/postinst
AD_STRICT_VALIDATE=0 sh scripts/validate.sh
git add -A
if ! git diff --cached --quiet; then git commit -m 'v7.602: restore similar-product images, tame all bundles, remove label and plus-wrapper boxes'; fi
git push origin main
SH
```

## FULL — v7.602

Screenshot-triggered; keep Amazon in the foreground until the scan finishes.

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh export full
```

## VIEWPORT — v7.602 ARM

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh arm
```

## VIEWPORT — v7.602 EXPORT

Background Amazon once after arming.

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh export viewport
```

## TRANSITION — v7.602 ARM

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/skeleton-probe.sh arm transition
```

## TRANSITION — v7.602 EXPORT

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/skeleton-probe.sh export
```
