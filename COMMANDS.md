# v7.339 source handoff

UI base: `1bd6d82` — `v7.309: exact dog, Cart, footer, and XL brand fixes`.
Transition: successful v7.338 source from this conversation, including its startup
crash fix. New skeleton work: prearmed diagnosis; target is OLED black, no guessed
paint rule is added.

Save `AmazonDark-v7.339-source.zip` in the same shared Documents folder used for
previous source pushes, then run this in NewTerm:

```sh
cd /var/mobile/Amazon-Dark-phone && \
git checkout -q main && \
D=/private/var/mobile/Containers/Shared/AppGroup/D846D8DE-EE0F-4B82-9676-C68769E519CD/Documents && \
rm -rf /var/mobile/t7339 && mkdir -p /var/mobile/t7339 && \
unzip -q "$D/AmazonDark-v7.339-source.zip" -d /var/mobile/t7339 && \
find . -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} + && \
cp -a /var/mobile/t7339/AmazonDark-v7.339-source/. . && \
grep '^Version:' layout/DEBIAN/control && \
git add -A && \
git commit -q -m "v7.339: v7.309 UI with v7.338 transition fix and skeleton probe" && \
git push origin main
```

Install the package produced by your usual GitHub Actions build and respring as
usual. Confirm the installed identity:

```sh
dpkg-query -W -f='${Package} ${Version}\n' com.joemama383.amazondark
```

Expected: `7.339~v7309-transition-skeleton-probe`. The unchanged SpringBoard log
still identifies its donor code as v7.338; that is intentional.

## Prearm the transient capture

First force-close Amazon using the app switcher. This is required once per capture
so the probe is present at the first document paint. Then run:

```sh
cd /var/mobile/Amazon-Dark-phone && sh scripts/skeleton-probe.sh arm both
```

Open Amazon within five minutes. The probe starts automatically and records for
up to two minutes. Refresh Home, swipe the hero carousel as you normally would,
then refresh Cart and let the ads load. No screenshot or precisely timed signal is
needed. Do not run the older scrolling probe during this capture.

If you prefer separate files, use `arm home` or `arm cart` instead of `arm both`,
with a force-close before each arm. Labels identify the run; both renderers are
still observed so an unexpected owner is not excluded by a guessed route.

## Export

After reproducing the white state, return to NewTerm and run:

```sh
cd /var/mobile/Amazon-Dark-phone && sh scripts/skeleton-probe.sh export
```

Upload the resulting `AmazonDark-v7.339-skeleton-probes-*.tar.gz` from the usual
shared Documents folder. It contains the saved runs. Export also disarms future
launches. A running session stops at its deadline or when Amazon is closed.

If no file appears:

```sh
cd /var/mobile/Amazon-Dark-phone && sh scripts/skeleton-probe.sh status
```

The first record must say `SESSION_START`, version `v7.339-v7309-transition-skeleton-probe`,
followed by `UCC_ATTACHED` and `WEB` / `FRAME_START` for WebKit coverage. An arm file
alone is not evidence that capture ran. No raw text, input values, URL values,
screenshots, network payloads or image pixels are recorded.

To cancel a pending arm without running it:

```sh
cd /var/mobile/Amazon-Dark-phone && sh scripts/skeleton-probe.sh disarm
```
