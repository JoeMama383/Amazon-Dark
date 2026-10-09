# AmazonDark v7.605 — sustainability border corners

Download and save `AmazonDark-v7.605-sustainability-rounded-border-source.zip` in Files on the iPhone before running the PUSH block. Accepted source family: `AmazonDark-v7.605-sustainability-rounded-border-source*.zip`. Expects existing clone `/var/mobile/Amazon-Dark-phone`.

## PUSH — existing clone

```sh
sh <<'SH'
set -eu
cd /var/mobile/Amazon-Dark-phone
ZIP=$(find /var/mobile -type d -name '.Trash*' -prune -o -type f -name 'AmazonDark-v7.605-sustainability-rounded-border-source.zip' -print 2>/dev/null | head -n 1)
[ -n "$ZIP" ] || { echo 'Save v7.605 source ZIP to Files on the phone first.'; exit 1; }
unzip -tq "$ZIP"
TMP=$(mktemp -d /var/mobile/ad7605.XXXXXX)
unzip -q "$ZIP" -d "$TMP"
STAGE="$TMP/ad7605"
grep -qx 'Version: 7.605~sustainability-rounded-border' "$STAGE/layout/DEBIAN/control"
grep -Fqx '#define AD_VERSION "v7.605-sustainability-rounded-border"' "$STAGE/src/Tweak.xm"
cp -a "$STAGE/." .
chmod 755 layout/DEBIAN/postinst
AD_STRICT_VALIDATE=0 sh scripts/validate.sh
git add -A
if ! git diff --cached --quiet; then git commit -m 'v7.605: reveal authored rounded carbon-impact borders without redrawing geometry'; fi
git push origin main
SH
```

## FULL — v7.605

Trigger a new FULL scan by taking an Amazon screenshot, wait for completion, then export only the current FULL TAR.

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh export full
```

## VIEWPORT — v7.605 ARM

Arm while in the sustainability section, then background Amazon once.

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh arm
```

## VIEWPORT — v7.605 EXPORT

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh export viewport
```

## TRANSITION — v7.605 ARM

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/skeleton-probe.sh arm transition
```

## TRANSITION — v7.605 EXPORT

Perform one transition, then export only this session TAR.

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/skeleton-probe.sh export
```
