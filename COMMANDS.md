# AmazonDark v7.638 — render work and child-frame queue repair

Download `AmazonDark-v7.638-render-work-queue-repair-source.zip` to Files before pushing. Source wildcard: `AmazonDark-v7.638-render-work-queue-repair-source*.zip`.

## PUSH — v7.638 existing clone

```sh
sh <<'SH'
set -eu
cd /var/mobile/Amazon-Dark-phone
ZIP=$(find /var/mobile -type d -name '.Trash*' -prune -o -type f -name 'AmazonDark-v7.638-render-work-queue-repair-source.zip' -print 2>/dev/null | head -n 1)
[ -n "$ZIP" ] || { echo 'Save the v7.638 source ZIP to Files first.'; exit 1; }
unzip -tq "$ZIP"
TMP=$(mktemp -d /var/mobile/ad7638.XXXXXX)
unzip -q "$ZIP" -d "$TMP"
STAGE="$TMP/ad7638"
grep -qx 'Version: 7.638~render-work-queue-repair' "$STAGE/layout/DEBIAN/control"
grep -Fqx '#define AD_VERSION "v7.638-render-work-queue-repair"' "$STAGE/src/Tweak.xm"
rm -f src/ADMenuRepair7620.js src/ADMenuRepair7620.js.inc
cp -a "$STAGE/." .
chmod 755 layout/DEBIAN/postinst
AD_STRICT_VALIDATE=0 sh scripts/validate.sh
git add -A
if ! git diff --cached --quiet; then git commit -m 'v7.638: fix feedback layout guard, deduplicate frame CSS, serialize frame repairs'; fi
git push origin main
SH
```

## BUILD — GitHub Actions

The `git push origin main` triggers `.github/workflows/build.yml`. Download the `.deb` from the passing Actions run; source syntax checked locally; linked package built by Actions.

After installing the `.deb`, fully close Amazon once and reopen it. This gives the new build a fresh process and clears the prior document scripts and stylesheet ownership.

For a normal capture, arm below, return to Amazon, run a new search, immediately try opening a product, then swipe its images. Keep Amazon foreground for 30–60 seconds before returning to NewTerm to export. No disabled-tweak comparison is needed.

## PERFORMANCE — v7.638 ARM

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/performance-probe.sh arm
```

## PERFORMANCE — v7.638 EXPORT

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/performance-probe.sh export
```

## OPTIONAL STYLESHEET COST — v7.638 ARM

Use this as a **separate** recording if the initial delay remains. Open one fresh slow menu and leave it still for 45–60 seconds, then background and use the same performance export command above. This deliberately forces bounded recalculations to rank individual theme sheets; its input timings are not normal-use latency. Each sheet is restored before the next task/paint. At most 24 owned theme sheets are tested, with a 15-second soft work budget. Known adopted sheets now participate, including the Interests sheet; app-owned sheets and shadow roots are excluded. This is an intentional rendering experiment, so input can pause during its individual tests.

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/performance-probe.sh arm styles
```

## FULL — v7.638 ARM

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh arm full
```

A screenshot inside Amazon also triggers FULL. Let the walk finish while Amazon remains visible, then export.

## FULL — v7.638 EXPORT

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh export full
```

## VIEWPORT — v7.638 ARM

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh arm
```

## VIEWPORT — v7.638 EXPORT

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh export viewport
```

## TRANSITION — v7.638 ARM

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/skeleton-probe.sh arm transition
```

## TRANSITION — v7.638 EXPORT

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/skeleton-probe.sh export
```
