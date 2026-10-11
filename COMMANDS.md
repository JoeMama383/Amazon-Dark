# AmazonDark v7.630 — reliable WebKit telemetry handoff

Download `AmazonDark-v7.630-webkit-telemetry-ack-fallback-source.zip` on your iPhone. ZIP wildcard: `AmazonDark-v7.630-webkit-telemetry-ack-fallback-source*.zip`.

## PUSH — existing clone

```sh
sh <<'SH'
set -eu
cd /var/mobile/Amazon-Dark-phone
ZIP=$(find /var/mobile -type d -name '.Trash*' -prune -o -type f -name 'AmazonDark-v7.630-webkit-telemetry-ack-fallback-source.zip' -print 2>/dev/null | head -n 1)
[ -n "$ZIP" ] || { echo 'Save v7.630 source ZIP to Files first.'; exit 1; }
unzip -tq "$ZIP"
TMP=$(mktemp -d /var/mobile/ad7630.XXXXXX)
unzip -q "$ZIP" -d "$TMP"
STAGE="$TMP/ad7630"
grep -qx 'Version: 7.630~webkit-telemetry-ack-fallback' "$STAGE/layout/DEBIAN/control"
grep -Fqx '#define AD_VERSION "v7.630-webkit-telemetry-ack-fallback"' "$STAGE/src/Tweak.xm"
rm -f src/ADMenuRepair7620.js src/ADMenuRepair7620.js.inc
cp -a "$STAGE/." .
chmod 755 layout/DEBIAN/postinst
AD_STRICT_VALIDATE=0 sh scripts/validate.sh
git add -A
if ! git diff --cached --quiet; then
  git commit -m 'v7.630: retain WebKit metric snapshots through eval callback bridge fallback'
fi
git push origin main
SH
```

### BUILD — GitHub Actions

After push, GitHub Actions runs the Theos rootless package build. Wait for its checks to complete; install the freshly produced `.deb` by your existing install workflow. The commands above push source, not a compiled binary.

## PERFORMANCE — v7.630 ARM

After installing v7.630, open Amazon at least once, then run:

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/performance-probe.sh arm
```

Return to Amazon, reproduce the slow Search Results and Product Detail scroll response for up to 90 seconds without the other UI/transition probes running. Remain foregrounded through the capture if possible.

## PERFORMANCE — v7.630 EXPORT

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/performance-probe.sh export
```

Upload the exported TAR. The report now tracks WebKit eval snapshot acknowledgments separately from WKScriptMessageHandler delivery; a bridge outage can no longer silently erase the initial document measurements.

## PERFORMANCE — v7.630 OFFLINE REPORT (desktop optional)

```sh
python3 scripts/performance-report.py /path/to/performance.tar --output perf-result.md
```

## FULL — v7.630

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh export full
```

## VIEWPORT — v7.630 ARM

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh arm
```

## VIEWPORT — v7.630 EXPORT

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh export viewport
```

## TRANSITION — v7.630 ARM

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/skeleton-probe.sh arm transition
```

## TRANSITION — v7.630 EXPORT

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/skeleton-probe.sh export
```
