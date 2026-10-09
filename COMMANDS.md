# AmazonDark v7.615 — native Live compile repair

Save `AmazonDark-v7.615-native-live-compile-repair-source.zip` to iPhone Files before the PUSH block. Accepted source family: `AmazonDark-v7.615-native-live-compile-repair-source*.zip`. Uses your existing clone at `/var/mobile/Amazon-Dark-phone`.

## PUSH — Existing clone

```sh
sh <<'SH'
set -eu
cd /var/mobile/Amazon-Dark-phone
ZIP=$(find /var/mobile -type d -name '.Trash*' -prune -o -type f -name 'AmazonDark-v7.615-native-live-compile-repair-source.zip' -print 2>/dev/null | head -n 1)
[ -n "$ZIP" ] || { echo 'Save the v7.615 source ZIP on the phone first.'; exit 1; }
unzip -tq "$ZIP"
TMP=$(mktemp -d /var/mobile/ad7615.XXXXXX)
unzip -q "$ZIP" -d "$TMP"
STAGE="$TMP/ad7615"
grep -qx 'Version: 7.615~native-live-compile-repair' "$STAGE/layout/DEBIAN/control"
grep -Fqx '#define AD_VERSION "v7.615-native-live-compile-repair"' "$STAGE/src/Tweak.xm"
cp -a "$STAGE/." .
chmod 755 layout/DEBIAN/postinst
AD_STRICT_VALIDATE=0 sh scripts/validate.sh
git add -A
if ! git diff --cached --quiet; then git commit -m 'v7.615: repair Live owner ObjC++ compilation, retain all probes and regression contracts'; fi
git push origin main
SH
```

## FULL — v7.615

Open Amazon on the target screen and take a screenshot. **Keep Amazon in the foreground** until FULL completes, then export its TAR:

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh export full
```

## VIEWPORT — v7.615 ARM

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh arm
```

## VIEWPORT — v7.615 EXPORT

Background Amazon once after arming the VIEWPORT capture, then:

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh export viewport
```

## TRANSITION — v7.615 ARM

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/skeleton-probe.sh arm transition
```

## TRANSITION — v7.615 EXPORT

Perform the transition and export the current capture TAR:

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/skeleton-probe.sh export
```
