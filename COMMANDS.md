AmazonDark v7.352 — Search/product-scroll UI repair workflow
============================================================

PUSH / APPLY
------------
D=/private/var/mobile/Containers/Shared/AppGroup/D846D8DE-EE0F-4B82-9676-C68769E519CD/Documents

cd /var/mobile/Amazon-Dark-phone && \
git checkout -q main && \
git fetch origin main && \
git merge --ff-only origin/main && \
grep -qx 'Version: 7.351~aggressive-theme-neutral-optimization' layout/DEBIAN/control && \
T=/var/mobile/t7352 && rm -rf "$T" && mkdir -p "$T" && \
unzip -q "$D/AmazonDark-v7.352-search-product-ui-repair-source.zip" -d "$T" && \
find . -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} + && \
cp -a "$T/AmazonDark-v7.352-search-product-ui-repair-source/." . && \
grep -qx 'Version: 7.352~search-product-ui-repair' layout/DEBIAN/control && \
grep -q '#define AD_VERSION "v7.352-search-product-ui-repair"' src/Tweak.xm && \
grep -q 'cards_carousel_widget-sug-container-top' src/Tweak.xm && \
grep -q 'feature-asins-video-list-loader' src/Tweak.xm && \
grep -q 's-pc-certification-faceout img.s-image' src/Tweak.xm && \
grep -q 's-trft .s-trft-tile' src/Tweak.xm && \
grep -q 'AmazonDarkSplashSeal7350' src/Tweak.xm && \
git diff --check && \
git add -A && git status --short && \
git commit -m 'v7.352: repair Search and product-scroll UI ownership' && \
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

Screenshot/SIGUSR2 UI probes remain enabled. v7.352 dispatches a visible /s WKWebView to the product-scroll probe before stale native-tab state, so a Search-results screenshot should now create the product-scroll output instead of the Menu output.
