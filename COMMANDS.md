# AmazonDark v7.640 — production rendering scope and startup recovery

Download `AmazonDark-v7.640-render-scope-lifecycle-source.zip` to Files before pushing. Source wildcard: `AmazonDark-v7.640-render-scope-lifecycle-source*.zip`.

## PUSH — v7.640 existing clone

```sh
sh <<'SH'
set -eu
cd /var/mobile/Amazon-Dark-phone
ZIP=$(find /var/mobile -type d -name '.Trash*' -prune -o -type f -name 'AmazonDark-v7.640-render-scope-lifecycle-source.zip' -print 2>/dev/null | head -n 1)
[ -n "$ZIP" ] || { echo 'Save the v7.640 source ZIP to Files first.'; exit 1; }
unzip -tq "$ZIP"
TMP=$(mktemp -d /var/mobile/ad7640.XXXXXX)
unzip -q "$ZIP" -d "$TMP"
STAGE="$TMP/ad7640"
grep -qx 'Version: 7.640~render-scope-lifecycle' "$STAGE/layout/DEBIAN/control"
grep -Fqx '#define AD_VERSION "v7.640-render-scope-lifecycle"' "$STAGE/src/Tweak.xm"
rm -f src/ADMenuRepair7620.js src/ADMenuRepair7620.js.inc
cp -a "$STAGE/." .
chmod 755 layout/DEBIAN/postinst
AD_STRICT_VALIDATE=0 sh scripts/validate.sh
git add -A
if ! git diff --cached --quiet; then git commit -m 'v7.640: reduce off-route render work and recover detached theme sheets'; fi
git push origin main
SH
```

## BUILD — GitHub Actions

The push triggers `.github/workflows/build.yml`. Install the `.deb` from the passing Actions run. Then close Amazon completely once and reopen. Capture a normal 30–60 second Search → product → gallery route. Keep diagnostic sessions separate. This build intentionally changes the production CSS workload rather than adding a new probe.

The ZIP is source, not an installable binary. Local tests cannot establish that the phone's delay is cured. Use normal `arm` below, not `arm styles`: style-cost trials deliberately force expensive recalculation. Arm one probe at a time, return to Amazon to reproduce, then return to NewTerm to export. FULL must remain foreground until its sweep completes; backgrounding it can produce a legitimate partial capture.

## PERFORMANCE — v7.640 ARM

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/performance-probe.sh arm
```

## PERFORMANCE — v7.640 EXPORT

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/performance-probe.sh export
```

## FULL — v7.640 ARM

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh arm full
```

A screenshot inside Amazon also triggers FULL. Let the sweep finish before exporting.

## FULL — v7.640 EXPORT

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh export full
```

## VIEWPORT — v7.640 ARM

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh arm
```

## VIEWPORT — v7.640 EXPORT

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh export viewport
```

## TRANSITION — v7.640 ARM

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/skeleton-probe.sh arm transition
```

## TRANSITION — v7.640 EXPORT

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/skeleton-probe.sh export
```
