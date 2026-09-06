# AmazonDark v7.346 — full-source handoff

Exact source base: v7.344, commit `5bf6c356489bef37783fe25cee127799fa4f7578`.
Package: `7.346~v7344-cart-strip-button`.

Save `AmazonDark-v7.346-source.zip` in the usual shared Documents folder. This is
the complete source tree, including the existing Actions workflow and assets.
Run the established replacement-and-push command in NewTerm:

```sh
cd /var/mobile/Amazon-Dark-phone && \
git checkout -q main && \
D=/private/var/mobile/Containers/Shared/AppGroup/D846D8DE-EE0F-4B82-9676-C68769E519CD/Documents && \
rm -rf /var/mobile/t7346 && mkdir -p /var/mobile/t7346 && \
unzip -q "$D/AmazonDark-v7.346-source.zip" -d /var/mobile/t7346 && \
find . -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} + && \
cp -a /var/mobile/t7346/AmazonDark-v7.346-source/. . && \
grep '^Version:' layout/DEBIAN/control && \
git add -A && \
git commit -q -m "v7.346: restore v7.344 base and fix Cart strip and buying-options button" && \
git push origin main
```

Install the package from the usual macOS Actions build and respring as usual.
Check the installed package:

```sh
dpkg-query -W -f='${Package} ${Version}\n' com.joemama383.amazondark
```

## Record startup and the Cart strip/button

Force-close Amazon, then arm the combined capture:

```sh
cd /var/mobile/Amazon-Dark-phone && sh scripts/skeleton-probe.sh arm transition
```

Open Amazon within five minutes. Each fresh process records startup and Home/Cart
for up to 45 seconds, stopping on background. Go to Cart, reproduce the loading
strip, and bring the recommendation row with “See all buying options” into view.
The recorder watches native layers and WebKit paint; no timed screenshot is needed.
The recording deadline does not hold, dismiss or retime any UI. A warm resume does
not restart recording. To repeat, force-close and reopen within the arm window.

Export after the run:

```sh
cd /var/mobile/Amazon-Dark-phone && sh scripts/skeleton-probe.sh export
```

Upload the printed `AmazonDark-v7.346-probes-*.tar` from shared Documents.
Compression/Gzip is not required. If tar fails, the helper exports a `.txt` containing
the same logs and status. The original captures remain on the phone. Export disarms
future launches. Older captures may also be included; each identifies its version
and session, so report which run showed the issue.

## Longer Home/Cart skeleton capture

For two minutes of Home/Cart observation, force-close Amazon and use:

```sh
cd /var/mobile/Amazon-Dark-phone && sh scripts/skeleton-probe.sh arm both
```

Open within five minutes; refresh Home, swipe the hero cards, then visit and refresh
Cart. Export using the command above. `arm launch` remains available for native-only
startup capture lasting up to 20 seconds per fresh process.

## Check capture status

```sh
cd /var/mobile/Amazon-Dark-phone && sh scripts/skeleton-probe.sh status
```

The current receipt should report `v7.346-v7344-cart-strip-button` and
`capture-started`; the current JSONL begins with `SESSION_START`. A v7.344 receipt
can identify Amazon's container during upgrade, but it does not prove v7.346 is
loaded. Arming requires the installed v7.346 package. If no capture exists, run
`export` anyway: its diagnostic report explains package/container/receipt failures.
The SpringBoard source and its inherited v7.338 log identity remain unchanged.

To disarm future launches manually:

```sh
cd /var/mobile/Amazon-Dark-phone && sh scripts/skeleton-probe.sh disarm
```
