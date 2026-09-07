AmazonDark v7.358 — Search rows + Shop-by-style floors + certification leaf

SOURCE ZIP
==========
AmazonDark-v7.358-search-row-shop-style-leaf-fix-source.zip

1) STAGE
========
D=/private/var/mobile/Containers/Shared/AppGroup/D846D8DE-EE0F-4B82-9676-C68769E519CD/Documents
T=/var/mobile/t7358

cd /var/mobile/Amazon-Dark-phone
git checkout -q main
git fetch origin main
git merge --ff-only origin/main
grep -qx 'Version: 7.357~search-footer-shop-style-fix' layout/DEBIAN/control

rm -rf "$T"
mkdir -p "$T"
unzip -q "$D/AmazonDark-v7.358-search-row-shop-style-leaf-fix-source.zip" -d "$T"
find . -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +
cp -a "$T/AmazonDark-v7.358-search-row-shop-style-leaf-fix-source/." .

2) VERIFY
=========
cd /var/mobile/Amazon-Dark-phone
grep -qx 'Version: 7.358~search-row-shop-style-leaf-fix' layout/DEBIAN/control
grep -q '#define AD_VERSION "v7.358-search-row-shop-style-leaf-fix"' src/Tweak.xm
grep -q 's-tiles-carousel-component-shoppable_image' src/Tweak.xm
grep -q 's-tiles-carousel::before' src/Tweak.xm
grep -q 's-pc-certification-faceout img.s-image' src/Tweak.xm
grep -q 'cards_carousel_widget-sug-im' src/Tweak.xm
grep -q 'ccs-ies-card-image-container' src/Tweak.xm
grep -q 'AmazonDarkSplashSeal7350' src/Tweak.xm
! grep -q 'data-ad7-shop-by-style' src/Tweak.xm
! grep -q 'function ad7357ShopByStyle' src/Tweak.xm
git diff --check
git status --short

3) COMMIT / PUSH
===============
cd /var/mobile/Amazon-Dark-phone
git add -A
git commit -m 'v7.358: fix Search rows, Shop by style floors and leaf icon'
git push origin main

AFTER INSTALL
=============
sbreload

SEARCH SCREENSHOT PROBE EXPORT
==============================
D=/private/var/mobile/Containers/Shared/AppGroup/D846D8DE-EE0F-4B82-9676-C68769E519CD/Documents
files=(/var/mobile/Containers/Data/Application/*/Documents/AmazonDark-v7.309-menu-ui-probe-*.txt(N.om[1]))
if (( ${#files} )); then P=$files[1]; cp -f "$P" "$D/"; chmod 666 "$D/${P:t}"; ls -lh "$D/${P:t}"; else echo "No Search/Menu screenshot probe found."; fi

PRODUCT / SHOP-BY-STYLE SCREENSHOT PROBE EXPORT
===============================================
D=/private/var/mobile/Containers/Shared/AppGroup/D846D8DE-EE0F-4B82-9676-C68769E519CD/Documents
files=(/var/mobile/Containers/Data/Application/*/Documents/AmazonDark-v7.309-product-scroll-probe-*.txt(N.om[1]))
if (( ${#files} )); then P=$files[1]; cp -f "$P" "$D/"; chmod 666 "$D/${P:t}"; ls -lh "$D/${P:t}"; else echo "No product-scroll screenshot probe found."; fi

SKELETON / TRANSITION PROBE
===========================
cd /var/mobile/Amazon-Dark-phone && sh scripts/skeleton-probe.sh arm transition
cd /var/mobile/Amazon-Dark-phone && sh scripts/skeleton-probe.sh export
