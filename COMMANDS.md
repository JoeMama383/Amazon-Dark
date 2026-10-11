# AmazonDark v7.629 — capture WebKit during loading and establish an enabled/disabled comparison

Save `AmazonDark-v7.629-early-webkit-capture-and-ab-telemetry-source.zip` to Files on your iPhone. ZIP wildcard: `AmazonDark-v7.629-early-webkit-capture-and-ab-telemetry-source*.zip`.

## PUSH — existing clone

```sh
sh <<'SH'
set -eu
cd /var/mobile/Amazon-Dark-phone
ZIP=$(find /var/mobile -type d -name '.Trash*' -prune -o -type f -name 'AmazonDark-v7.629-early-webkit-capture-and-ab-telemetry-source.zip' -print 2>/dev/null | head -n 1)
[ -n "$ZIP" ] || { echo 'Save the v7.629 source ZIP to Files first.'; exit 1; }
unzip -tq "$ZIP"
TMP=$(mktemp -d /var/mobile/ad7629.XXXXXX)
unzip -q "$ZIP" -d "$TMP"
STAGE="$TMP/ad7629"
grep -qx 'Version: 7.629~early-webkit-capture-and-ab-telemetry' "$STAGE/layout/DEBIAN/control"
grep -Fqx '#define AD_VERSION "v7.629-early-webkit-capture-and-ab-telemetry"' "$STAGE/src/Tweak.xm"
rm -f src/ADMenuRepair7620.js src/ADMenuRepair7620.js.inc
cp -a "$STAGE/." .
chmod 755 layout/DEBIAN/postinst
AD_STRICT_VALIDATE=0 sh scripts/validate.sh
git add -A
if ! git diff --cached --quiet; then git commit -m 'v7.629: record during-load WebKit timings and enabled/disabled performance'; fi
git push origin main
SH
```

## PERFORMANCE — v7.629 ARM

Open Amazon once (after enabling or disabling AmazonDark in its settings and relaunching the app). Open NewTerm, then:

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/performance-probe.sh arm
```

Return to Amazon and reproduce Search Results and the Product Details scroll delay for up to 90 seconds. Do not run any other probe concurrently. Stay in foreground for the full 90 seconds if possible.

## PERFORMANCE — v7.629 EXPORT

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/performance-probe.sh export
```

Collect the fully instrumented TAR with the theme **enabled** first. For a comparison, disable the theme and relaunch Amazon, then repeat the same scrolling workflow and measure responsiveness visually (a brief screen recording is useful). WARNING: the currently implemented WebKit/native hooks install only when the theme is enabled at process initialization; a disabled-after-relaunch TAR may include basic frame clocks but lack WebKit hook data, so do not treat missing measurements as zero lag. Re-enable the theme afterwards. The accidental extra third menu does not invalidate the enabled capture.

## PERFORMANCE — v7.629 OFFLINE REPORT

```sh
python3 scripts/performance-report.py path/to/second-capture.tar --baseline path/to/first-capture.tar --output performance-compare.md
```

## FULL — v7.629

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh export full
```

## VIEWPORT — v7.629 ARM

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh arm
```

## VIEWPORT — v7.629 EXPORT

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/ui-probe.sh export viewport
```

## TRANSITION — v7.629 ARM

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/skeleton-probe.sh arm transition
```

## TRANSITION — v7.629 EXPORT

```sh
sh /var/mobile/Amazon-Dark-phone/scripts/skeleton-probe.sh export
```
