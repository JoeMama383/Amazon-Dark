# AmazonDark v7.627 — stale performance scanner cleanup

Save `AmazonDark-v7.627-stale-scanner-cleanup-source.zip` to Files first.
Expected source wildcard: `AmazonDark-v7.627-stale-scanner-cleanup-source*.zip`.

## PUSH — existing clone

The two obsolete `ADMenuRepair7620` files were abandoned after the 7.619 Home-raster regression. An overlay copy (`cp -a`) does not remove them from an existing clone, and they add two inactive-but-counted `querySelectorAll` calls that fail performance regression. Remove **only those exact obsolete files**, not any active UI/probe implementation. The clean v7.627 source already excludes them.

```sh
sh <<'SH'
set -eu
cd /var/mobile/Amazon-Dark-phone
ZIP=$(find /var/mobile -type d -name '.Trash*' -prune -o -type f -name 'AmazonDark-v7.627-stale-scanner-cleanup-source.zip' -print 2>/dev/null | head -n 1)
[ -n "$ZIP" ] || { echo 'Save the v7.627 source ZIP to Files first.'; exit 1; }
unzip -tq "$ZIP"
TMP=$(mktemp -d /var/mobile/ad7627.XXXXXX)
unzip -q "$ZIP" -d "$TMP"
STAGE="$TMP/ad7627"
grep -qx 'Version: 7.627~stale-scanner-cleanup' "$STAGE/layout/DEBIAN/control"
grep -Fqx '#define AD_VERSION "v7.627-stale-scanner-cleanup"' "$STAGE/src/Tweak.xm"
# Remove only the exact two abandoned v7.619 raster files left by prior overlays.
rm -f src/ADMenuRepair7620.js src/ADMenuRepair7620.js.inc
cp -a "$STAGE/." .
chmod 755 layout/DEBIAN/postinst
AD_STRICT_VALIDATE=0 sh scripts/validate.sh
git add -A
if ! git diff --cached --quiet; then
  git commit -m 'v7.627: remove orphan Home-raster scanner source; guard clean performance census'
fi
git push origin main
SH
```

## PERFORMANCE — v7.627 ARM

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/performance-probe.sh arm
```

## PERFORMANCE — v7.627 EXPORT

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/performance-probe.sh export
```

## PERFORMANCE — OFFLINE REPORT

```sh
python3 scripts/performance-report.py AmazonDark-v7.627-performance-SESSION.tar --output performance-report.md
```

## SCANNER CENSUS

```sh
python3 scripts/performance-source-audit.py . --output source-scanner-report.md
```

## FULL — v7.627

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh export full
```

## VIEWPORT — v7.627 ARM

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh arm
```

## VIEWPORT — v7.627 EXPORT

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh export viewport
```

## TRANSITION — v7.627 ARM

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/skeleton-probe.sh arm transition
```

## TRANSITION — v7.627 EXPORT

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/skeleton-probe.sh export
```
