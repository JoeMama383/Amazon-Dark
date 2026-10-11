# AmazonDark v7.633 — C++98 web-cache CI compatibility (retains Search/PDP fast path)

Download `AmazonDark-v7.633-web-cache-cpp98-compatibility-source.zip` to Files before pushing. Source wildcard: `AmazonDark-v7.633-web-cache-cpp98-compatibility-source*.zip`.

## PUSH — v7.633 existing clone

```sh
sh <<'SH'
set -eu
cd /var/mobile/Amazon-Dark-phone
ZIP=$(find /var/mobile -type d -name '.Trash*' -prune -o -type f -name 'AmazonDark-v7.633-web-cache-cpp98-compatibility-source.zip' -print 2>/dev/null | head -n 1)
[ -n "$ZIP" ] || { echo 'Save the v7.633 source ZIP to Files first.'; exit 1; }
unzip -tq "$ZIP"
TMP=$(mktemp -d /var/mobile/ad7633.XXXXXX)
unzip -q "$ZIP" -d "$TMP"
STAGE="$TMP/ad7633"
grep -qx 'Version: 7.633~web-cache-cpp98-compatibility' "$STAGE/layout/DEBIAN/control"
grep -Fqx '#define AD_VERSION "v7.633-web-cache-cpp98-compatibility"' "$STAGE/src/Tweak.xm"
rm -f src/ADMenuRepair7620.js src/ADMenuRepair7620.js.inc
cp -a "$STAGE/." .
chmod 755 layout/DEBIAN/postinst
AD_STRICT_VALIDATE=0 sh scripts/validate.sh
git add -A
if ! git diff --cached --quiet; then git commit -m 'v7.633: retain Search/PDP fast path and fix cache C++98 fixture'; fi
git push origin main
SH
```

## BUILD — GitHub Actions

The `git push origin main` triggers `.github/workflows/build.yml`. Download the `.deb` from the passing Actions run; no local iOS SDK available here.

## PERFORMANCE — v7.633 ARM

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/performance-probe.sh arm
```

## PERFORMANCE — v7.633 EXPORT

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/performance-probe.sh export
```

## FULL — v7.633

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh export full
```

## VIEWPORT — v7.633 ARM

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh arm
```

## VIEWPORT — v7.633 EXPORT

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh export viewport
```

## TRANSITION — v7.633 ARM

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/skeleton-probe.sh arm transition
```

## TRANSITION — v7.633 EXPORT

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/skeleton-probe.sh export
```
