# AmazonDark v7.625 — performance audit and metric reporting

Save `AmazonDark-v7.625-performance-audit-and-report-source.zip` to Files first.
Expected source wildcard: `AmazonDark-v7.625-performance-audit-and-report-source*.zip`.

## PUSH — existing clone

```sh
sh <<'SH'
set -eu
cd /var/mobile/Amazon-Dark-phone
ZIP=$(find /var/mobile -type d -name '.Trash*' -prune -o -type f -name 'AmazonDark-v7.625-performance-audit-and-report-source.zip' -print 2>/dev/null | head -n 1)
[ -n "$ZIP" ] || { echo 'Save v7.625 ZIP to Files first.'; exit 1; }
unzip -tq "$ZIP"
TMP=$(mktemp -d /var/mobile/ad7625.XXXXXX)
unzip -q "$ZIP" -d "$TMP"
STAGE="$TMP/ad7625"
grep -qx 'Version: 7.625~performance-audit-and-report' "$STAGE/layout/DEBIAN/control"
grep -Fqx '#define AD_VERSION "v7.625-performance-audit-and-report"' "$STAGE/src/Tweak.xm"
cp -a "$STAGE/." .
chmod 755 layout/DEBIAN/postinst
AD_STRICT_VALIDATE=0 sh scripts/validate.sh
git add -A
if ! git diff --cached --quiet; then git commit -m 'v7.625: performance transport repair, opt-in metrics and scanner budget'; fi
git push origin main
SH
```

## PERFORMANCE — v7.625 ARM

Open Amazon once before arming. Return to Amazon after the command and reproduce a consistent 90-second workflow (e.g. Home scroll, Orders, PDP). Keep FULL/VIEWPORT/TRANSITION unarmed during this measurement.

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/performance-probe.sh arm
```

## PERFORMANCE — v7.625 EXPORT

Wait 90 seconds or background Amazon to finish the single session; export a single TAR:

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/performance-probe.sh export
```

## PERFORMANCE — OFFLINE REPORT

Run with Python 3 on a PC/Mac, or upload the TAR here for analysis. This script reads the TAR only and never touches Amazon.

```sh
python3 scripts/performance-report.py AmazonDark-v7.625-performance-SESSION.tar --output performance-report.md
```

For future apples-to-apples measurements, use `--baseline path/to/older-performance.tar` with the same device and menu path. The original v7.400 does not have a paired current-session capture in this handoff.

## SOURCE SCANNER AUDIT

```sh
python3 scripts/performance-source-audit.py . --output source-scanner-report.md
```

If exact v7.400 source becomes available, append `--baseline path/to/v7.400-source.zip` for a source-to-source static comparison.

## FULL — v7.625

Take a screenshot inside Amazon, wait for scan completion, export current-session TAR:

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh export full
```

## VIEWPORT — v7.625 ARM

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh arm
```

## VIEWPORT — v7.625 EXPORT

After backgrounding Amazon once:

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh export viewport
```

## TRANSITION — v7.625 ARM

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/skeleton-probe.sh arm transition
```

## TRANSITION — v7.625 EXPORT

After performing a transition:

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/skeleton-probe.sh export
```
