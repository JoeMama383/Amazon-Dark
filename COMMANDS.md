# AmazonDark v7.632 — CI handoff validation repair (retains Search/PDP fast path)

Download `AmazonDark-v7.632-ci-handoff-validation-restore-source.zip` to Files before pushing. Source wildcard: `AmazonDark-v7.632-ci-handoff-validation-restore-source*.zip`.

## PUSH — v7.632 existing clone

```sh
sh <<'SH'
set -eu
cd /var/mobile/Amazon-Dark-phone
ZIP=$(find /var/mobile -type d -name '.Trash*' -prune -o -type f -name 'AmazonDark-v7.632-ci-handoff-validation-restore-source.zip' -print 2>/dev/null | head -n 1)
[ -n "$ZIP" ] || { echo 'Save the v7.632 source ZIP to Files first.'; exit 1; }
unzip -tq "$ZIP"
TMP=$(mktemp -d /var/mobile/ad7632.XXXXXX)
unzip -q "$ZIP" -d "$TMP"
STAGE="$TMP/ad7632"
grep -qx 'Version: 7.632~ci-handoff-validation-restore' "$STAGE/layout/DEBIAN/control"
grep -Fqx '#define AD_VERSION "v7.632-ci-handoff-validation-restore"' "$STAGE/src/Tweak.xm"
rm -f src/ADMenuRepair7620.js src/ADMenuRepair7620.js.inc
cp -a "$STAGE/." .
chmod 755 layout/DEBIAN/postinst
AD_STRICT_VALIDATE=0 sh scripts/validate.sh
git add -A
if ! git diff --cached --quiet; then git commit -m 'v7.632: restore CI validation handoff while retaining Search/PDP performance fast path'; fi
git push origin main
SH
```

## BUILD — GitHub Actions

The `git push origin main` triggers `.github/workflows/build.yml`. Download the `.deb` from the passing Actions run; no local iOS SDK available here.

## PERFORMANCE — v7.632 ARM

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/performance-probe.sh arm
```

## PERFORMANCE — v7.632 EXPORT

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/performance-probe.sh export
```

## FULL — v7.632

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh export full
```

## VIEWPORT — v7.632 ARM

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh arm
```

## VIEWPORT — v7.632 EXPORT

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh export viewport
```

## TRANSITION — v7.632 ARM

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/skeleton-probe.sh arm transition
```

## TRANSITION — v7.632 EXPORT

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/skeleton-probe.sh export
```
