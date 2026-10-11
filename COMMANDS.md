# AmazonDark v7.631 — Search/PDP startup fast path and scroll instrumentation

Download `AmazonDark-v7.631-search-pdp-startup-fastpath-source.zip` to Files before pushing. Source wildcard: `AmazonDark-v7.631-search-pdp-startup-fastpath-source*.zip`.

## PUSH — v7.631 existing clone

```sh
sh <<'SH'
set -eu
cd /var/mobile/Amazon-Dark-phone
ZIP=$(find /var/mobile -type d -name '.Trash*' -prune -o -type f -name 'AmazonDark-v7.631-search-pdp-startup-fastpath-source.zip' -print 2>/dev/null | head -n 1)
[ -n "$ZIP" ] || { echo 'Save the v7.631 source ZIP to Files first.'; exit 1; }
unzip -tq "$ZIP"
TMP=$(mktemp -d /var/mobile/ad7631.XXXXXX)
unzip -q "$ZIP" -d "$TMP"
STAGE="$TMP/ad7631"
grep -qx 'Version: 7.631~search-pdp-startup-fastpath' "$STAGE/layout/DEBIAN/control"
grep -Fqx '#define AD_VERSION "v7.631-search-pdp-startup-fastpath"' "$STAGE/src/Tweak.xm"
rm -f src/ADMenuRepair7620.js src/ADMenuRepair7620.js.inc
cp -a "$STAGE/." .
chmod 755 layout/DEBIAN/postinst
git add -A
if ! git diff --cached --quiet; then git commit -m 'v7.631: avoid checkout CSS in Search/PDP and sample WebKit responsiveness'; fi
git push origin main
SH
```

## BUILD — GitHub Actions

The `git push origin main` triggers `.github/workflows/build.yml`. Download the `.deb` from the passing Actions run; no local iOS SDK available here.

## PERFORMANCE — v7.631 ARM

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/performance-probe.sh arm
```

## PERFORMANCE — v7.631 EXPORT

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/performance-probe.sh export
```

## FULL — v7.631

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh export full
```

## VIEWPORT — v7.631 ARM

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh arm
```

## VIEWPORT — v7.631 EXPORT

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh export viewport
```

## TRANSITION — v7.631 ARM

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/skeleton-probe.sh arm transition
```

## TRANSITION — v7.631 EXPORT

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/skeleton-probe.sh export
```
