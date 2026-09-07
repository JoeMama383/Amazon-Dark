AmazonDark v7.354 — Search carousel + Store Spotlight TWB workflow
===============================================================

PUSH / APPLY
------------
D=/private/var/mobile/Containers/Shared/AppGroup/D846D8DE-EE0F-4B82-9676-C68769E519CD/Documents

cd /var/mobile/Amazon-Dark-phone && \
git checkout -q main && \
git fetch origin main && \
git merge --ff-only origin/main && \
grep -qx 'Version: 7.353~search-carousel-media-header-fix' layout/DEBIAN/control && \
T=/var/mobile/t7354 && rm -rf "$T" && mkdir -p "$T" && \
unzip -q "$D/AmazonDark-v7.354-search-carousel-store-spotlight-fix-source.zip" -d "$T" && \
find . -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} + && \
cp -a "$T/AmazonDark-v7.354-search-carousel-store-spotlight-fix-source/." . && \
grep -qx 'Version: 7.354~search-carousel-store-spotlight-fix' layout/DEBIAN/control && \
grep -q '#define AD_VERSION "v7.354-search-carousel-store-spotlight-fix"' src/Tweak.xm && \
grep -q 'store-spotlight-v2-creative-mobile-cards' src/Tweak.xm && \
grep -q 'cards_carousel_widget-sug-im' src/Tweak.xm && \
grep -q 'AmazonDarkSplashSeal7350' src/Tweak.xm && \
git diff --check && \
git add -A && git status --short && \
git commit -m 'v7.354: restore Search carousel media and tame Store Spotlight' && \
git push origin main

AFTER INSTALL
-------------
sbreload

PROBES
------
Screenshot/SIGUSR2 trigger:
  PID=$(pgrep -x Amazon | head -n 1)
  kill -USR2 "$PID"

Search/autocomplete export:
  D=/private/var/mobile/Containers/Shared/AppGroup/D846D8DE-EE0F-4B82-9676-C68769E519CD/Documents
  files=(/var/mobile/Containers/Data/Application/*/Documents/AmazonDark-v7.309-menu-ui-probe-*.txt(N.om[1]))
  if (( ${#files} )); then P=$files[1]; cp -f "$P" "$D/"; chmod 666 "$D/${P:t}"; ls -lh "$D/${P:t}"; else echo "No Search/Menu screenshot probe found."; fi

Product-scroll export:
  D=/private/var/mobile/Containers/Shared/AppGroup/D846D8DE-EE0F-4B82-9676-C68769E519CD/Documents
  files=(/var/mobile/Containers/Data/Application/*/Documents/AmazonDark-v7.309-product-scroll-probe-*.txt(N.om[1]))
  if (( ${#files} )); then P=$files[1]; cp -f "$P" "$D/"; chmod 666 "$D/${P:t}"; ls -lh "$D/${P:t}"; else echo "No product-scroll screenshot probe found."; fi

Transition / launch / skeleton capture:
  cd /var/mobile/Amazon-Dark-phone && sh scripts/skeleton-probe.sh arm transition

Export armed capture:
  cd /var/mobile/Amazon-Dark-phone && sh scripts/skeleton-probe.sh export
