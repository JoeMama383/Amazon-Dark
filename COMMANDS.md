# AmazonDark v7.628 — WebKit scroll-latency diagnostics

Save `AmazonDark-v7.628-web-scroll-latency-diagnostics-source.zip` to Files. Expected source wildcard: `AmazonDark-v7.628-web-scroll-latency-diagnostics-source*.zip`.

## PUSH — existing clone

```sh
sh <<'SH'
set -eu
cd /var/mobile/Amazon-Dark-phone
ZIP=$(find /var/mobile -type d -name '.Trash*' -prune -o -type f -name 'AmazonDark-v7.628-web-scroll-latency-diagnostics-source.zip' -print 2>/dev/null | head -n 1)
[ -n "$ZIP" ] || { echo 'Save the v7.628 source ZIP to Files first.'; exit 1; }
unzip -tq "$ZIP"
TMP=$(mktemp -d /var/mobile/ad7628.XXXXXX)
unzip -q "$ZIP" -d "$TMP"
STAGE="$TMP/ad7628"
grep -qx 'Version: 7.628~web-scroll-latency-diagnostics' "$STAGE/layout/DEBIAN/control"
grep -Fqx '#define AD_VERSION "v7.628-web-scroll-latency-diagnostics"' "$STAGE/src/Tweak.xm"
rm -f src/ADMenuRepair7620.js src/ADMenuRepair7620.js.inc
cp -a "$STAGE/." .
chmod 755 layout/DEBIAN/postinst
AD_STRICT_VALIDATE=0 sh scripts/validate.sh
git add -A
if ! git diff --cached --quiet; then git commit -m 'v7.628: instrument WebKit scroll latency and retain in-session performance samples'; fi
git push origin main
SH
```

## PERFORMANCE — v7.628 ARM

Run after installing the new package and opening Amazon once:

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/performance-probe.sh arm
```

Remain foreground for up to 90 seconds. Reproduce Search results and PDP scroll stalls. Do not arm FULL, VIEWPORT or TRANSITION simultaneously. To capture the full 90 seconds, **wait for the probe to end before backgrounding Amazon**.

## PERFORMANCE — v7.628 EXPORT

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/performance-probe.sh export
```

## PERFORMANCE — OFFLINE REPORT

```sh
python3 scripts/performance-report.py AmazonDark-v7.628-performance-SESSION.tar --output performance-report.md
```

## FULL — v7.628

Screenshot-trigger in Amazon, wait for scan completion:

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh export full
```

## VIEWPORT — v7.628 ARM

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh arm
```

## VIEWPORT — v7.628 EXPORT

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh export viewport
```

## TRANSITION — v7.628 ARM

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/skeleton-probe.sh arm transition
```

## TRANSITION — v7.628 EXPORT

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/skeleton-probe.sh export
```
