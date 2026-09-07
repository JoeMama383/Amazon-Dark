AmazonDark v7.351 — optimized full-source workflow
===================================================

PUSH / APPLY
------------
D=/private/var/mobile/Containers/Shared/AppGroup/D846D8DE-EE0F-4B82-9676-C68769E519CD/Documents

cd /var/mobile/Amazon-Dark-phone && \
git checkout -q main && \
git fetch origin main && \
git merge --ff-only origin/main && \
grep -qx 'Version: 7.350~native-splash-image-seal' layout/DEBIAN/control && \
T=/var/mobile/t7351 && rm -rf "$T" && mkdir -p "$T" && \
unzip -q "$D/AmazonDark-v7.351-aggressive-theme-neutral-optimization-source.zip" -d "$T" && \
find . -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} + && \
cp -a "$T/AmazonDark-v7.351-aggressive-theme-neutral-optimization-source/." . && \
grep -qx 'Version: 7.351~aggressive-theme-neutral-optimization' layout/DEBIAN/control && \
grep -q '#define AD_VERSION "v7.351-aggressive-theme-neutral-optimization"' src/Tweak.xm && \
grep -q 'form#activeCartViewForm .sc-list-item .swipe-button.swipe-right-button' src/Tweak.xm && \
grep -q 'AmazonDarkSplashSeal7350' src/Tweak.xm && \
grep -q '#sc-recs-atf-shimmer-placeholder{border-top-color:#000!important' src/Tweak.xm && \
git diff --check && \
git add -A && git status --short && \
git commit -m 'v7.351: simplify hot paths and restore Cart Save for later text' && \
git push origin main

AFTER INSTALL
-------------
sbreload

PROBES
------
Transition / launch / skeleton capture:
  cd /var/mobile/Amazon-Dark-phone && sh scripts/skeleton-probe.sh arm transition

Export armed capture:
  cd /var/mobile/Amazon-Dark-phone && sh scripts/skeleton-probe.sh export

The existing screenshot/SIGUSR2 Home, Person, Cart, Menu, Alexa and product probes remain in the tweak.
