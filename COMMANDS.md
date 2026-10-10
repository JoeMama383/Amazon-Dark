# AmazonDark v7.616 — universal FULL/VIEWPORT capture transport

Save `AmazonDark-v7.616-universal-probe-transport-source.zip` to iPhone Files before PUSH. Use the existing clone. The helper exports a capture from the *installed* AmazonDark version if compilation has not produced the new version; it never relabels old artifacts as v7.616.

## PUSH — existing clone

```sh
sh <<'SH'
set -eu
cd /var/mobile/Amazon-Dark-phone
ZIP=$(find /var/mobile -type d -name '.Trash*' -prune -o -type f -name 'AmazonDark-v7.616-universal-probe-transport-source.zip' -print 2>/dev/null | head -n 1)
[ -n "$ZIP" ] || { echo 'Save the v7.616 source ZIP to Files on the phone first.'; exit 1; }
unzip -tq "$ZIP"
TMP=$(mktemp -d /var/mobile/ad7616.XXXXXX)
unzip -q "$ZIP" -d "$TMP"
STAGE="$TMP/ad7616"
grep -qx 'Version: 7.616~universal-probe-transport' "$STAGE/layout/DEBIAN/control"
grep -Fqx '#define AD_VERSION "v7.616-universal-probe-transport"' "$STAGE/src/Tweak.xm"
cp -a "$STAGE/." .
chmod 755 layout/DEBIAN/postinst
AD_STRICT_VALIDATE=0 sh scripts/validate.sh
git add -A
if ! git diff --cached --quiet; then git commit -m 'v7.616: repair universal probe transport, installed-version discovery and capture diagnostics'; fi
git push origin main
SH
```

## FULL — screenshot-triggered universal capture

Take a screenshot while Amazon is showing ANY menu and keep Amazon foregrounded while the scan runs. Then:

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh export full
```

## FULL — optional foreground-arm fallback

If the screenshot event still does not start FULL, run this while NewTerm is foregrounded, **then return to the target Amazon menu** and leave it foregrounded. This uses the same universal FULL walker; it is not a viewport substitute.

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh arm full
```

After Amazon completes the scan, export with the FULL command above.

## VIEWPORT — arm

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh arm
```

Keep the desired Amazon screen visible, then background it once.

## VIEWPORT — export

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh export viewport
```

## TRANSITION — arm

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/skeleton-probe.sh arm transition
```

## TRANSITION — export

Perform the transition then:

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/skeleton-probe.sh export
```
