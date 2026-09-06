# AmazonDark v7.347 — Cart strip owner forensics

Exact production visual base: v7.346 (`4d207ed`). This build is diagnostic-only for the persistent Cart white strip.

## Push full source from current v7.346 main

Save `AmazonDark-v7.347-cart-strip-owner-forensics-source.zip` in the usual shared Documents folder, then run:

```sh
cd /var/mobile/Amazon-Dark-phone && \
git checkout -q main && \
git fetch origin main && \
git merge --ff-only origin/main && \
grep -qx 'Version: 7.346~v7344-cart-strip-button' layout/DEBIAN/control && \
D=/private/var/mobile/Containers/Shared/AppGroup/D846D8DE-EE0F-4B82-9676-C68769E519CD/Documents && \
T=/var/mobile/t7347 && rm -rf "$T" && mkdir -p "$T" && \
unzip -q "$D/AmazonDark-v7.347-cart-strip-owner-forensics-source.zip" -d "$T" && \
find . -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} + && \
cp -a "$T/AmazonDark-v7.347-cart-strip-owner-forensics-source/." . && \
grep -qx 'Version: 7.347~cart-strip-owner-forensics' layout/DEBIAN/control && \
grep -q '#define AD_VERSION "v7.347-cart-strip-owner-forensics"' src/Tweak.xm && \
grep -q 'CART_STRIP_OWNER' src/Tweak.xm && \
git diff --check && \
git add -A && git status --short && \
git commit -m 'v7.347: instrument persistent Cart strip owner and gate' && \
git push origin main
```

Install the resulting Actions package and run `sbreload`.

## Decisive Cart strip capture

1. Force-close Amazon.
2. Arm the transition recorder:

```sh
cd /var/mobile/Amazon-Dark-phone && sh scripts/skeleton-probe.sh arm transition
```

3. Launch Amazon within five minutes, open Cart, and reproduce the white strip several times inside the 45-second recording window. While the strip is visibly white, take **one iOS screenshot**; the armed recorder treats that as an exact-moment `USER_MARK` and suppresses the old scrolling screenshot probe.
4. Export:

```sh
cd /var/mobile/Amazon-Dark-phone && sh scripts/skeleton-probe.sh export
```

Upload the printed `AmazonDark-v7.347-probes-*.tar`.

## What this run resolves

- `globalMountSeen=1`, `exactHookSeen=0` -> exact Logos class hook did not run; use the global lifecycle path as the production late-load fallback.
- `exactHookSeen=1`, `liveCartSelected=1`, `latchedCartSelected=0` -> production's `setSelected:` latch is wrong; switch the cover gate to the live Cart control state.
- `coverExists=0` or `coverHidden=1` while live Cart is selected -> owner/gate timing failure; synchronize on mount/selection and pre-window superview state.
- `coverExists=1`, `coverHidden=0`, black cover frame matches the 430x5 bar, yet the screenshot is white -> the captured `AWLoadingIndicatorBarView` is not the topmost visible strip; inspect the same-frame parent/sibling/native compositor records and Web strip candidates instead of changing this gate again.

Status if needed:

```sh
cd /var/mobile/Amazon-Dark-phone && sh scripts/skeleton-probe.sh status
```
