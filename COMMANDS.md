# v7.341 source handoff

UI base: `1bd6d82` — `v7.309: exact dog, Cart, footer, and XL brand fixes`.
Parent: the delivered v7.340 source. SpringBoard remains the v7.338 artwork source.
This build repairs the missing capture/export path and adds startup/fade
observations. It does not claim a new white-flash, fade, or skeleton color fix.

Save `AmazonDark-v7.341-source.zip` in the usual shared Documents folder, then run:

```sh
cd /var/mobile/Amazon-Dark-phone && \
git checkout -q main && \
D=/private/var/mobile/Containers/Shared/AppGroup/D846D8DE-EE0F-4B82-9676-C68769E519CD/Documents && \
rm -rf /var/mobile/t7341 && mkdir -p /var/mobile/t7341 && \
unzip -q "$D/AmazonDark-v7.341-source.zip" -d /var/mobile/t7341 && \
find . -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} + && \
cp -a /var/mobile/t7341/AmazonDark-v7.341-source/. . && \
grep '^Version:' layout/DEBIAN/control && \
git add -A && \
git commit -q -m "v7.341: repair capture export and add startup fade diagnostics" && \
git push origin main
```

Install the package from the usual macOS Actions build and respring as usual.
Arming verifies the installed version before writing any request.

## Transition capture

Force-close Amazon, then run in NewTerm:

```sh
cd /var/mobile/Amazon-Dark-phone && sh scripts/skeleton-probe.sh arm launch
```

Open Amazon within five minutes. Let it reach Home, then force-close and relaunch
as needed until the brief white flash or abrupt handoff occurs. Multiple fresh
processes within the five-minute arm window produce separate logs. Re-arm if the
window expires. Each process records up to 20 seconds and stops on background;
the deadline only ends diagnostics and does not control the loading screen.
Warm resumes do not restart this capture.

After reproducing, export:

```sh
cd /var/mobile/Amazon-Dark-phone && sh scripts/skeleton-probe.sh export
```

Upload `AmazonDark-v7.341-probes-*.tar.gz` from the usual shared Documents folder.
It includes startup/fade observations and the last 4 MiB of the existing v7.338
SpringBoard artwork log. Tell us whether the last cold launch flashed, ended
abruptly, or faded normally. No precisely timed screenshot is required.

## Home/Cart skeleton capture

Run separately from launch capture. Force-close Amazon, then:

```sh
cd /var/mobile/Amazon-Dark-phone && sh scripts/skeleton-probe.sh arm both
```

Open within five minutes. Over the next two minutes, refresh Home and swipe the
hero carousel, then refresh Cart and let its ads load. Export with the same block
above. `arm home` or `arm cart` can label separate runs; both observe the same
renderers. Do not run the older scrolling probe during this capture.

## Capture status and recovery

After opening Amazon, this shows the loaded tweak's startup receipt and the first
record of each capture:

```sh
cd /var/mobile/Amazon-Dark-phone && sh scripts/skeleton-probe.sh status
```

Expect `capture-started`, version `v7.341-container-capture-startup-diagnostics`,
and `SESSION_START`. If no capture exists, **run export anyway and upload its
archive**. It now includes package identity, metadata discovery counts, receipt
errors and available SpringBoard evidence instead of stopping with no export.
A package version alone does not prove the running process loaded that version;
the receipt supplies the process version and PID.

Export disarms future launches and preserves log originals. To cancel arming:

```sh
cd /var/mobile/Amazon-Dark-phone && sh scripts/skeleton-probe.sh disarm
```

Unarmed processes write only a small startup receipt for troubleshooting; no new
observer, display link or WebKit capture is installed. Launch mode never changes
views, animation timing, snapshots, process lifetime or readiness behavior.
